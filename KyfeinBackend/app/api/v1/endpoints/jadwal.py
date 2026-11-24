from datetime import date, datetime, timedelta, time
from typing import List, Optional, Literal
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_, or_, func
from sqlalchemy.orm import selectinload

from app.core.deps import get_db, get_current_user, require_roles
from app.core.utils import now_local
from app.core.firebase_config import send_push_notification
from app.models.jadwal import JadwalShift, ShiftTemplate, TukarShift, RequestOff
from app.models.absensi import Absensi, IzinTelat, IzinTidakMasuk
from app.models.karyawan import Karyawan
from app.models.stok import StokOpname
from app.schemas.jadwal import (
    JadwalShiftCreate, JadwalShiftOut,
    ShiftTemplateCreate, ShiftTemplateOut, ShiftTemplateUpdate,
    TukarShiftCreate, TukarShiftApproval, TukarShiftTargetKonfirmasi, TukarShiftOut,
    RequestOffCreate, RequestOffOut
)
from app.services.jadwal_service import (
    ensure_shift_templates,
    get_shift_berjalan,
    slugify_shift_key,
)

router = APIRouter()


def _find_template_in_map(
    templates: dict[str, ShiftTemplate],
    identifier: str,
) -> Optional[ShiftTemplate]:
    ident = identifier.strip()
    if ident in templates:
        return templates[ident]
    for tpl in templates.values():
        if tpl.id == ident or tpl.shift.lower() == ident.lower():
            return tpl
    return None


@router.get("/shift-template", response_model=List[ShiftTemplateOut])
@router.get("/shift-template/", response_model=List[ShiftTemplateOut])
async def list_shift_templates(
    db: AsyncSession = Depends(get_db),
    current_user: Karyawan = Depends(get_current_user)
):
    """Mengambil seluruh template jam kerja shift dari database."""
    templates = await ensure_shift_templates(db)
    return sorted(templates.values(), key=lambda t: (t.jam_mulai, t.shift))


@router.post("/shift-template", response_model=ShiftTemplateOut, status_code=status.HTTP_201_CREATED)
@router.post("/shift-template/", response_model=ShiftTemplateOut, status_code=status.HTTP_201_CREATED)
async def create_shift_template(
    data: ShiftTemplateCreate,
    db: AsyncSession = Depends(get_db),
    current_user: Karyawan = Depends(require_roles(["admin"]))
):
    """Admin menambahkan template shift baru ke database."""
    nama_clean = data.nama.strip()
    if not nama_clean:
        raise HTTPException(status_code=400, detail="Nama template shift tidak boleh kosong")

    if data.jam_selesai <= data.jam_mulai:
        raise HTTPException(
            status_code=400,
            detail="Jam selesai harus setelah jam mulai (shift melewati tengah malam belum didukung)"
        )

    templates = await ensure_shift_templates(db)
    if any(t.nama.strip().lower() == nama_clean.lower() for t in templates.values()):
        raise HTTPException(
            status_code=409,
            detail=f"Nama template shift '{nama_clean}' sudah digunakan"
        )

    if data.shift is not None and data.shift.strip():
        shift_key = slugify_shift_key(data.shift)
        if shift_key in templates:
            raise HTTPException(
                status_code=409,
                detail=f"Kode template shift '{shift_key}' sudah digunakan"
            )
    else:
        base_key = slugify_shift_key(nama_clean)
        shift_key = base_key
        counter = 2
        while shift_key in templates:
            suffix = f"_{counter}"
            shift_key = f"{base_key[:50 - len(suffix)]}{suffix}"
            counter += 1

    tpl = ShiftTemplate(
        shift=shift_key,
        nama=nama_clean,
        jam_mulai=data.jam_mulai,
        jam_selesai=data.jam_selesai,
    )
    db.add(tpl)
    await db.commit()
    await db.refresh(tpl)
    return tpl


@router.put("/shift-template/{shift}", response_model=ShiftTemplateOut)
async def update_shift_template(
    shift: str,
    data: ShiftTemplateUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: Karyawan = Depends(require_roles(["admin"]))
):
    """Admin memperbarui nama & jam mulai/selesai template shift di database."""
    if data.jam_selesai <= data.jam_mulai:
        raise HTTPException(
            status_code=400,
            detail="Jam selesai harus setelah jam mulai (shift melewati tengah malam belum didukung)"
        )

    templates = await ensure_shift_templates(db)
    tpl = _find_template_in_map(templates, shift)
    if not tpl:
        raise HTTPException(status_code=404, detail="Template shift tidak ditemukan")

    if data.nama is not None:
        nama_clean = data.nama.strip()
        if not nama_clean:
            raise HTTPException(status_code=400, detail="Nama template shift tidak boleh kosong")
        if any(
            t.id != tpl.id and t.nama.strip().lower() == nama_clean.lower()
            for t in templates.values()
        ):
            raise HTTPException(
                status_code=409,
                detail=f"Nama template shift '{nama_clean}' sudah digunakan"
            )
        tpl.nama = nama_clean

    tpl.jam_mulai = data.jam_mulai
    tpl.jam_selesai = data.jam_selesai
    tpl.updated_at = now_local()

    await db.commit()
    await db.refresh(tpl)
    return tpl


@router.delete("/shift-template/{shift}")
async def delete_shift_template(
    shift: str,
    db: AsyncSession = Depends(get_db),
    current_user: Karyawan = Depends(require_roles(["admin"]))
):
    """Admin menghapus template shift yang belum dipakai pada jadwal_shift (minimal 1 tersisa)."""
    templates = await ensure_shift_templates(db)
    tpl = _find_template_in_map(templates, shift)
    if not tpl:
        raise HTTPException(status_code=404, detail="Template shift tidak ditemukan")

    if len(templates) <= 1:
        raise HTTPException(
            status_code=400,
            detail="Minimal 1 template shift harus tetap tersedia"
        )

    used_res = await db.execute(
        select(func.count()).select_from(JadwalShift).where(
            or_(
                JadwalShift.shift == tpl.shift,
                JadwalShift.shift_template_id == tpl.id,
            )
        )
    )
    used_count = used_res.scalar() or 0
    if used_count > 0:
        raise HTTPException(
            status_code=409,
            detail=f"Template '{tpl.nama}' masih digunakan oleh {used_count} jadwal shift"
        )

    deleted_id = tpl.id
    deleted_shift = tpl.shift
    deleted_nama = tpl.nama
    await db.delete(tpl)
    await db.commit()
    return {
        "status": "deleted",
        "id": deleted_id,
        "shift": deleted_shift,
        "nama": deleted_nama,
    }

@router.get("", response_model=List[JadwalShiftOut])
@router.get("/", response_model=List[JadwalShiftOut])
async def list_jadwal(
    tanggal: Optional[date] = None,
    db: AsyncSession = Depends(get_db),
    current_user: Karyawan = Depends(get_current_user)
):
    """
    A11: karyawan hanya melihat jadwalnya sendiri, admin melihat semua.
    """
    query = select(JadwalShift)
    if current_user.role not in ["admin"]:
        query = query.where(JadwalShift.karyawan_id == current_user.id)
    if tanggal:
        query = query.where(JadwalShift.tanggal == tanggal)
    result = await db.execute(query.order_by(JadwalShift.tanggal, JadwalShift.jam_mulai))
    return result.scalars().all()

@router.post("", response_model=JadwalShiftOut)
@router.post("/", response_model=JadwalShiftOut)
async def create_jadwal(
    data: JadwalShiftCreate,
    db: AsyncSession = Depends(get_db),
    current_user: Karyawan = Depends(require_roles(["admin"]))
):
    """
    Buat jadwal shift baru dengan penugasan area_kerja ('kasir', 'bar', 'kitchen')
    - Tolak jika karyawan_id tidak ditemukan atau status_aktif = False (400)
    - Tolak jika karyawan sedang mengajukan Request Off pada tanggal tersebut (400)
    """
    templates = await ensure_shift_templates(db)
    template = _find_template_in_map(templates, data.shift)
    if not template:
        raise HTTPException(
            status_code=400,
            detail=f"Template shift '{data.shift}' tidak ditemukan",
        )
    shift_key = template.shift
    jam_mulai = data.jam_mulai if data.jam_mulai is not None else template.jam_mulai
    jam_selesai = data.jam_selesai if data.jam_selesai is not None else template.jam_selesai

    if jam_selesai <= jam_mulai:
        raise HTTPException(
            status_code=400,
            detail="Jam selesai harus setelah jam mulai (shift melewati tengah malam belum didukung)"
        )

    karyawan = await db.get(Karyawan, data.karyawan_id)
    if not karyawan or not karyawan.status_aktif:
        raise HTTPException(
            status_code=400,
            detail="Karyawan tidak ditemukan atau status tidak aktif"
        )

    # Cek apakah karyawan mengajukan Request Off pada tanggal tersebut
    existing_off = await db.execute(
        select(RequestOff).where(
            and_(
                RequestOff.karyawan_id == data.karyawan_id,
                RequestOff.tanggal == data.tanggal
            )
        )
    )
    if existing_off.scalars().first():
        raise HTTPException(
            status_code=400,
            detail="Karyawan ini sedang mengajukan Request Off (libur) pada tanggal tersebut dan tidak dapat dimasukkan ke jadwal"
        )

    # Cek constraint 1 karyawan tidak boleh 2 shift di tanggal sama
    existing = await db.execute(
        select(JadwalShift).where(
            and_(
                JadwalShift.karyawan_id == data.karyawan_id,
                JadwalShift.tanggal == data.tanggal
            )
        )
    )
    if existing.scalars().first():
        raise HTTPException(status_code=400, detail="Karyawan ini sudah memiliki jadwal shift pada tanggal tersebut")

    item = JadwalShift(
        karyawan_id=data.karyawan_id,
        tanggal=data.tanggal,
        shift=shift_key,
        area_kerja=data.area_kerja,
        shift_template_id=template.id,
        jam_mulai=jam_mulai,
        jam_selesai=jam_selesai,
        dibuat_oleh=current_user.id,
    )
    db.add(item)
    await db.commit()
    await db.refresh(item)
    return item

@router.get("/tukar-shift/jadwal-tersedia", response_model=List[JadwalShiftOut])
async def list_jadwal_untuk_tukar(
    tanggal: date,
    db: AsyncSession = Depends(get_db),
    current_user: Karyawan = Depends(get_current_user)
):
    """
    VISIBILITAS EKSEPSI JADWAL:
    Karyawan dapat melihat jadwal milik karyawan LAIN pada tanggal yang sama
    untuk memilih target tukar shift.
    """
    result = await db.execute(
        select(JadwalShift).where(
            and_(
                JadwalShift.tanggal == tanggal,
                JadwalShift.karyawan_id != current_user.id
            )
        )
    )
    return result.scalars().all()

def _format_shift_ringkas(shift: Optional[JadwalShift]) -> Optional[str]:
    if not shift:
        return None
    sh_label = (shift.shift or "").replace("_", " ").upper()
    area = (shift.area_kerja or "").upper()
    jm = _format_time_str(shift.jam_mulai)
    js = _format_time_str(shift.jam_selesai)
    return f"{shift.tanggal} · {sh_label} ({area}) · {jm}–{js}"


async def _enrich_tukar_shifts(db: AsyncSession, items: List[TukarShift]) -> List[TukarShift]:
    if not items:
        return items
    ids = [t.id for t in items]
    res = await db.execute(
        select(TukarShift)
        .options(
            selectinload(TukarShift.pengaju),
            selectinload(TukarShift.target),
            selectinload(TukarShift.shift_a),
            selectinload(TukarShift.shift_b),
        )
        .where(TukarShift.id.in_(ids))
    )
    loaded_map = {t.id: t for t in res.scalars().all()}
    enriched: List[TukarShift] = []
    for orig in items:
        t = loaded_map.get(orig.id, orig)
        setattr(t, "nama_pengaju", t.pengaju.nama if getattr(t, "pengaju", None) else None)
        setattr(t, "nama_target", t.target.nama if getattr(t, "target", None) else None)
        setattr(t, "tanggal_shift", t.shift_a.tanggal if getattr(t, "shift_a", None) else None)
        setattr(t, "info_shift_a", _format_shift_ringkas(getattr(t, "shift_a", None)))
        setattr(t, "info_shift_b", _format_shift_ringkas(getattr(t, "shift_b", None)))
        enriched.append(t)
    return enriched


@router.get("/tukar-shift", response_model=List[TukarShiftOut])
@router.get("/tukar-shift/", response_model=List[TukarShiftOut])
async def list_tukar_shift(
    status: Optional[Literal['pending', 'disetujui', 'ditolak']] = None,
    status_target: Optional[Literal['pending', 'disetujui', 'ditolak']] = None,
    db: AsyncSession = Depends(get_db),
    current_user: Karyawan = Depends(get_current_user)
):
    query = select(TukarShift)
    if current_user.role not in ["admin"]:
        query = query.where(
            or_(
                TukarShift.karyawan_pengaju_id == current_user.id,
                TukarShift.karyawan_target_id == current_user.id
            )
        )
    if status:
        query = query.where(TukarShift.status == status)
    if status_target:
        query = query.where(TukarShift.status_target == status_target)
    result = await db.execute(query.order_by(TukarShift.diajukan_at.desc()))
    items = list(result.scalars().all())
    return await _enrich_tukar_shifts(db, items)

@router.post("/tukar-shift", response_model=TukarShiftOut)
async def request_tukar_shift(
    data: TukarShiftCreate,
    db: AsyncSession = Depends(get_db),
    current_user: Karyawan = Depends(get_current_user)
):
    """
    Issue 7 + Konfirmasi 2-Tahap: Pengajuan tukar shift oleh karyawan.
    Setelah diajukan, status_target='pending' menunggu konfirmasi karyawan target,
    baru setelah disetujui target dapat di-approve oleh Admin.
    """
    shift_a = await db.get(JadwalShift, data.shift_a_id)
    shift_b = await db.get(JadwalShift, data.shift_b_id)

    if not shift_a or not shift_b:
        raise HTTPException(status_code=404, detail="Jadwal shift A atau B tidak ditemukan")

    if shift_a.karyawan_id != current_user.id:
        raise HTTPException(status_code=400, detail="Shift A bukan milik pengaju")

    if shift_b.karyawan_id != data.karyawan_target_id:
        raise HTTPException(status_code=400, detail="Shift B bukan milik karyawan target")

    if current_user.id == data.karyawan_target_id or shift_a.karyawan_id == shift_b.karyawan_id:
        raise HTTPException(status_code=400, detail="Pengaju tidak boleh tukar shift dengan diri sendiri")

    if shift_a.tanggal != shift_b.tanggal:
        raise HTTPException(
            status_code=400,
            detail="Tukar shift hanya diizinkan untuk jadwal pada tanggal yang sama!"
        )

    today = now_local().date()
    if shift_a.tanggal < today:
        raise HTTPException(
            status_code=400,
            detail="Jadwal shift sudah berlalu (tidak boleh diajukan tukar)"
        )

    # Cek jika shift_a ATAU shift_b sudah ada di pengajuan pending lain
    pending_stmt = select(TukarShift).where(
        and_(
            TukarShift.status == "pending",
            or_(
                TukarShift.shift_a_id.in_([data.shift_a_id, data.shift_b_id]),
                TukarShift.shift_b_id.in_([data.shift_a_id, data.shift_b_id])
            )
        )
    )
    res_pending = await db.execute(pending_stmt)
    if res_pending.scalars().first():
        raise HTTPException(
            status_code=409,
            detail="Salah satu jadwal shift sudah ada di pengajuan tukar shift lain yang berstatus pending"
        )

    tukar = TukarShift(
        shift_a_id=data.shift_a_id,
        shift_b_id=data.shift_b_id,
        karyawan_pengaju_id=current_user.id,
        karyawan_target_id=data.karyawan_target_id,
        alasan=data.alasan,
        status="pending",
        status_target="pending",
    )
    db.add(tukar)
    await db.commit()
    await db.refresh(tukar)

    # Kirim notifikasi ke karyawan target agar mengonfirmasi pengajuan tukar shift
    target_user = await db.get(Karyawan, data.karyawan_target_id)
    if target_user and target_user.fcm_token:
        import asyncio
        asyncio.create_task(
            asyncio.to_thread(
                send_push_notification,
                fcm_token=target_user.fcm_token,
                title="Permintaan Tukar Shift 🔄",
                body=f"{current_user.nama} mengajukan tukar shift pada {shift_a.tanggal}. Mohon konfirmasi setuju/tolak.",
                data={"tukar_shift_id": str(tukar.id), "type": "tukar_shift_target"},
            )
        )

    return (await _enrich_tukar_shifts(db, [tukar]))[0]


@router.put("/tukar-shift/{id}/konfirmasi-target", response_model=TukarShiftOut)
async def konfirmasi_target_tukar_shift(
    id: str,
    data: TukarShiftTargetKonfirmasi,
    db: AsyncSession = Depends(get_db),
    current_user: Karyawan = Depends(get_current_user),
):
    """
    Tahap 1 Persetujuan Tukar Shift: Konfirmasi oleh karyawan target.
    - Hanya karyawan_target_id yang dapat mengonfirmasi (403 jika bukan).
    - Status pengajuan dan status_target wajib masih 'pending' (409 jika sudah diproses).
    - Jika target menolak ('ditolak'), pengajuan otomatis berstatus 'ditolak'.
    - Jika target menyetujui ('disetujui'), pengajuan lanjut menunggu approval akhir dari Admin.
    """
    stmt_tukar = select(TukarShift).where(TukarShift.id == id).with_for_update()
    tukar = (await db.execute(stmt_tukar)).scalars().first()
    if not tukar:
        raise HTTPException(status_code=404, detail="Data pengajuan tukar shift tidak ditemukan")

    if tukar.karyawan_target_id != current_user.id:
        raise HTTPException(
            status_code=403,
            detail="Hanya karyawan target yang dapat mengonfirmasi pengajuan tukar shift ini",
        )

    if tukar.status != "pending" or tukar.status_target != "pending":
        raise HTTPException(
            status_code=409,
            detail="Pengajuan tukar shift ini sudah dikonfirmasi atau diproses sebelumnya",
        )

    now = now_local()
    tukar.status_target = data.status
    tukar.dikonfirmasi_target_at = now
    if data.status == "ditolak":
        tukar.status = "ditolak"
        tukar.diproses_oleh = current_user.id
        tukar.diproses_at = now

    await db.commit()
    await db.refresh(tukar)
    return (await _enrich_tukar_shifts(db, [tukar]))[0]


@router.put("/tukar-shift/{id}/approval", response_model=TukarShiftOut)
async def approval_tukar_shift(
    id: str,
    data: TukarShiftApproval,
    db: AsyncSession = Depends(get_db),
    current_user: Karyawan = Depends(require_roles(["admin"]))
):
    """
    Issue 7 + 2-Tahap Approval tukar shift dengan locking & re-validation menyeluruh:
    - Status wajib 'pending' (selain itu 409)
    - jika disetujui:
      - Wajib sudah disetujui oleh karyawan target (`status_target == 'disetujui'`, selain itu 409)
      - Validasi shift_a & shift_b kepemilikan
      - Validasi tanggal shift >= hari ini (409)
      - Validasi belum ada absensi di kedua shift (409)
      - Validasi tidak ada izin_telat atau izin_tidak_masuk (pending/disetujui) (409)
      - Menggunakan with_for_update() pada tukar_shift & jadwal_shift
      - Transaksi atomic lengkap
    """
    stmt_tukar = select(TukarShift).where(TukarShift.id == id).with_for_update()
    res_tukar = await db.execute(stmt_tukar)
    tukar = res_tukar.scalars().first()

    if not tukar:
        raise HTTPException(status_code=404, detail="Data pengajuan tukar shift tidak ditemukan")

    if tukar.status != "pending":
        raise HTTPException(status_code=409, detail="Pengajuan tukar shift ini sudah diproses (bukan pending)")

    if data.status == "disetujui":
        if tukar.status_target != "disetujui":
            raise HTTPException(
                status_code=409,
                detail="Pengajuan tukar shift belum dikonfirmasi/disetujui oleh karyawan target",
            )

        stmt_a = select(JadwalShift).where(JadwalShift.id == tukar.shift_a_id).with_for_update()
        shift_a = (await db.execute(stmt_a)).scalars().first()

        stmt_b = select(JadwalShift).where(JadwalShift.id == tukar.shift_b_id).with_for_update()
        shift_b = (await db.execute(stmt_b)).scalars().first()

        if not shift_a or not shift_b:
            raise HTTPException(status_code=404, detail="Salah satu jadwal shift terkait tidak ditemukan")

        # 1. Validasi kepemilikan shift belum berubah
        if shift_a.karyawan_id != tukar.karyawan_pengaju_id or shift_b.karyawan_id != tukar.karyawan_target_id:
            raise HTTPException(
                status_code=409,
                detail="Tukar shift gagal karena kepemilikan shift telah berubah"
            )

        # 2. Validasi tanggal shift >= hari ini
        today = now_local().date()
        if shift_a.tanggal < today or shift_b.tanggal < today:
            raise HTTPException(
                status_code=409,
                detail="Tukar shift ditolak karena jadwal shift sudah berlalu"
            )

        # 3. Validasi belum ada absensi di kedua shift
        abs_stmt = select(Absensi.id).where(Absensi.jadwal_shift_id.in_([shift_a.id, shift_b.id]))
        if (await db.execute(abs_stmt)).scalars().first():
            raise HTTPException(
                status_code=409,
                detail="Tukar shift ditolak karena salah satu shift sudah memiliki catatan absensi"
            )

        # 4. Validasi tidak ada izin_telat atau izin_tidak_masuk (pending/disetujui)
        iz_telat_stmt = select(IzinTelat.id).where(
            and_(
                IzinTelat.jadwal_shift_id.in_([shift_a.id, shift_b.id]),
                IzinTelat.status.in_(["pending", "disetujui"])
            )
        )
        if (await db.execute(iz_telat_stmt)).scalars().first():
            raise HTTPException(
                status_code=409,
                detail="Tukar shift ditolak karena salah satu shift memiliki pengajuan/izin telat"
            )

        iz_tm_stmt = select(IzinTidakMasuk.id).where(
            and_(
                IzinTidakMasuk.jadwal_shift_id.in_([shift_a.id, shift_b.id]),
                IzinTidakMasuk.status.in_(["pending", "disetujui"])
            )
        )
        if (await db.execute(iz_tm_stmt)).scalars().first():
            raise HTTPException(
                status_code=409,
                detail="Tukar shift ditolak karena salah satu shift memiliki pengajuan/izin tidak masuk"
            )

        # Swapping process
        try:
            original_tanggal = shift_a.tanggal
            temp_tanggal = original_tanggal + timedelta(days=10000)

            temp_karyawan_id = shift_a.karyawan_id
            target_karyawan_id = shift_b.karyawan_id

            shift_a.tanggal = temp_tanggal
            await db.flush()

            shift_b.karyawan_id = temp_karyawan_id
            await db.flush()

            shift_a.karyawan_id = target_karyawan_id
            shift_a.tanggal = original_tanggal
            await db.flush()

            tukar.status = data.status
            tukar.diproses_oleh = current_user.id
            tukar.diproses_at = now_local()

            await db.commit()
        except Exception:
            await db.rollback()
            raise HTTPException(
                status_code=409,
                detail="Gagal memproses persetujuan tukar shift akibat konflik data"
            )
    else:
        tukar.status = data.status
        tukar.diproses_oleh = current_user.id
        tukar.diproses_at = now_local()
        await db.commit()

    await db.refresh(tukar)
    return (await _enrich_tukar_shifts(db, [tukar]))[0]

@router.get("/request-off", response_model=List[RequestOffOut])
@router.get("/request-off/", response_model=List[RequestOffOut])
async def list_request_off(
    db: AsyncSession = Depends(get_db),
    current_user: Karyawan = Depends(get_current_user)
):
    """
    VISIBILITAS EKSEPSI REQUEST OFF:
    Semua karyawan bisa melihat SEMUA pengajuan request off karyawan lain
    agar tidak bentrok mengajukan libur di tanggal yang sama.
    """
    result = await db.execute(select(RequestOff).order_by(RequestOff.tanggal.desc()))
    return result.scalars().all()

@router.post("/request-off", response_model=RequestOffOut)
@router.post("/request-off/", response_model=RequestOffOut)
async def create_request_off(
    data: RequestOffCreate,
    db: AsyncSession = Depends(get_db),
    current_user: Karyawan = Depends(get_current_user)
):
    """
    Issue 7: Request Off validation:
    - Tolak tanggal di masa lalu (400)
    - Tolak duplikat (karyawan_id, tanggal) (409)
    - Tolak jika sudah memiliki jadwal shift pada tanggal tersebut (400)
    """
    today = now_local().date()
    if data.tanggal < today:
        raise HTTPException(
            status_code=400,
            detail="Tanggal request off tidak boleh di masa lalu"
        )

    existing = await db.execute(
        select(RequestOff).where(
            and_(
                RequestOff.karyawan_id == current_user.id,
                RequestOff.tanggal == data.tanggal
            )
        )
    )
    if existing.scalars().first():
        raise HTTPException(
            status_code=409,
            detail="Anda sudah mengajukan request off pada tanggal tersebut"
        )

    existing_shift = await db.execute(
        select(JadwalShift).where(
            and_(
                JadwalShift.karyawan_id == current_user.id,
                JadwalShift.tanggal == data.tanggal
            )
        )
    )
    if existing_shift.scalars().first():
        raise HTTPException(
            status_code=400,
            detail="Anda sudah memiliki jadwal shift pada tanggal tersebut. Silakan ajukan Tukar Shift atau Izin Tidak Masuk"
        )

    item = RequestOff(
        karyawan_id=current_user.id,
        tanggal=data.tanggal,
        alasan=data.alasan
    )
    db.add(item)
    await db.commit()
    await db.refresh(item)
    return item

@router.delete("/request-off/{id}")
async def delete_request_off(
    id: str,
    db: AsyncSession = Depends(get_db),
    current_user: Karyawan = Depends(get_current_user)
):
    item = await db.get(RequestOff, id)
    if not item:
        raise HTTPException(status_code=404, detail="Data request off tidak ditemukan")
    if current_user.role not in ["admin"] and item.karyawan_id != current_user.id:
        raise HTTPException(status_code=403, detail="Akses ditolak")
    await db.delete(item)
    await db.commit()
    return {"message": "Request off berhasil dihapus"}

def _format_time_str(val) -> str:
    if val is None:
        return ""
    if isinstance(val, (time, datetime)):
        return val.strftime("%H:%M")
    if isinstance(val, timedelta):
        total_seconds = int(val.total_seconds())
        hours = (total_seconds // 3600) % 24
        minutes = (total_seconds % 3600) // 60
        return f"{hours:02d}:{minutes:02d}"
    s = str(val).strip()
    parts = s.split(":")
    if len(parts) >= 2:
        return f"{parts[0].zfill(2)}:{parts[1].zfill(2)}"
    return s


@router.get("/shift-aktif")
@router.get("/shift-aktif/")
async def get_shift_aktif(
    titik: Optional[str] = None,
    db: AsyncSession = Depends(get_db),
    current_user: Karyawan = Depends(get_current_user)
):
    """
    Mengembalikan shift berjalan untuk user saat ini.
    - Untuk role 'karyawan': hanya mengembalikan jadwal shift milik dirinya sendiri yang sedang aktif.
      Jika tidak memiliki jadwal shift berjalan (off-shift/libur), mengembalikan 404.
    - Untuk role 'admin': tetap mendukung pencarian shift hari ini per titik operasional.
    """
    now = now_local()
    today = now.date()
    templates = await ensure_shift_templates(db)
    fallback_tpl = templates.get("shift_1") or (next(iter(templates.values())) if templates else None)

    active_shift = await get_shift_berjalan(db, current_user.id, now)
    if active_shift:
        tpl_match = templates.get(active_shift.shift) or fallback_tpl
        jam_mulai_str = _format_time_str(active_shift.jam_mulai) or (_format_time_str(tpl_match.jam_mulai) if tpl_match else "08:00")
        jam_selesai_str = _format_time_str(active_shift.jam_selesai) or (_format_time_str(tpl_match.jam_selesai) if tpl_match else "16:00")

        abs_stmt = select(Absensi).where(
            and_(
                Absensi.jadwal_shift_id == active_shift.id,
                Absensi.karyawan_id == current_user.id
            )
        )
        abs_res = await db.execute(abs_stmt)
        abs_obj = abs_res.scalars().first()

        if active_shift.area_kerja == "kasir":
            opname_awal_submit = True
        else:
            op_awal_res = await db.execute(
                select(StokOpname.id).where(
                    and_(
                        StokOpname.jadwal_shift_id == active_shift.id,
                        StokOpname.tipe == "awal_shift",
                    )
                ).limit(1)
            )
            opname_awal_submit = op_awal_res.scalars().first() is not None

        return {
            "id": active_shift.id,
            "tanggal": str(active_shift.tanggal),
            "area_kerja": active_shift.area_kerja,
            "shift": active_shift.shift,
            "shift_nama": tpl_match.nama if tpl_match and tpl_match.shift == active_shift.shift else active_shift.shift.replace("_", " ").title(),
            "jam_mulai": jam_mulai_str,
            "jam_selesai": jam_selesai_str,
            "karyawan_id": active_shift.karyawan_id,
            "opname_awal_submit": opname_awal_submit,
            "sudah_absen_masuk": abs_obj is not None,
            "sudah_absen_pulang": abs_obj is not None and abs_obj.jam_pulang is not None,
            "absensi": {
                "id": abs_obj.id,
                "jam_masuk": abs_obj.jam_masuk.isoformat() if abs_obj.jam_masuk else None,
                "jam_pulang": abs_obj.jam_pulang.isoformat() if abs_obj.jam_pulang else None,
                "menit_telat": abs_obj.menit_telat,
                "status_pulang": abs_obj.status_pulang,
            } if abs_obj else None
        }

    # Karyawan tanpa shift aktif tidak boleh meminjam atau membuat shift fiktif
    if current_user.role not in ["admin", "owner"]:
        raise HTTPException(
            status_code=404,
            detail="Anda sedang off-shift / libur (tidak memiliki jadwal shift aktif hari ini)."
        )

    # Khusus Admin: cari shift hari ini berdasarkan titik
    area = titik if titik in ['bar', 'kitchen', 'kasir'] else 'bar'
    query = select(JadwalShift).where(
        and_(
            JadwalShift.tanggal == today,
            JadwalShift.area_kerja == area
        )
    )
    shift_res = await db.execute(query)
    shift = shift_res.scalars().first()

    if not shift:
        any_shift_q = select(JadwalShift).where(JadwalShift.tanggal == today)
        any_res = await db.execute(any_shift_q)
        shift = any_res.scalars().first()

    if not shift:
        tpl_default = fallback_tpl
        shift = JadwalShift(
            id=f"shift-{area}-{today.strftime('%Y%m%d')}",
            karyawan_id=current_user.id,
            tanggal=today,
            shift=tpl_default.shift if tpl_default else 'shift_1',
            area_kerja=area,
            shift_template_id=tpl_default.id if tpl_default else None,
            jam_mulai=tpl_default.jam_mulai if tpl_default else time(8, 0),
            jam_selesai=tpl_default.jam_selesai if tpl_default else time(16, 0),
            dibuat_oleh=current_user.id,
            created_at=now,
            updated_at=now
        )
        db.add(shift)
        await db.commit()
        await db.refresh(shift)

    tpl_shift = templates.get(shift.shift) or fallback_tpl
    jam_mulai_str = _format_time_str(shift.jam_mulai) or (_format_time_str(tpl_shift.jam_mulai) if tpl_shift else "08:00")
    jam_selesai_str = _format_time_str(shift.jam_selesai) or (_format_time_str(tpl_shift.jam_selesai) if tpl_shift else "16:00")

    abs_stmt = select(Absensi).where(
        and_(
            Absensi.jadwal_shift_id == shift.id,
            Absensi.karyawan_id == current_user.id
        )
    )
    abs_res = await db.execute(abs_stmt)
    abs_obj = abs_res.scalars().first()

    if shift.area_kerja == "kasir":
        opname_awal_submit = True
    else:
        op_awal_res = await db.execute(
            select(StokOpname.id).where(
                and_(
                    StokOpname.jadwal_shift_id == shift.id,
                    StokOpname.tipe == "awal_shift",
                )
            ).limit(1)
        )
        opname_awal_submit = op_awal_res.scalars().first() is not None

    return {
        "id": shift.id,
        "tanggal": str(shift.tanggal),
        "area_kerja": shift.area_kerja,
        "shift": shift.shift,
        "shift_nama": tpl_shift.nama if tpl_shift and tpl_shift.shift == shift.shift else shift.shift.replace("_", " ").title(),
        "jam_mulai": jam_mulai_str,
        "jam_selesai": jam_selesai_str,
        "karyawan_id": shift.karyawan_id,
        "opname_awal_submit": opname_awal_submit,
        "sudah_absen_masuk": abs_obj is not None,
        "sudah_absen_pulang": abs_obj is not None and abs_obj.jam_pulang is not None,
        "absensi": {
            "id": abs_obj.id,
            "jam_masuk": abs_obj.jam_masuk.isoformat() if abs_obj.jam_masuk else None,
            "jam_pulang": abs_obj.jam_pulang.isoformat() if abs_obj.jam_pulang else None,
            "menit_telat": abs_obj.menit_telat,
            "status_pulang": abs_obj.status_pulang,
        } if abs_obj else None
    }

