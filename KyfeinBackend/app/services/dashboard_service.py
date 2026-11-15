import calendar
from datetime import date, datetime, timedelta
from decimal import Decimal
from typing import Dict, List, Optional, Tuple

from fastapi import HTTPException
from sqlalchemy import and_, extract, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.absensi import Absensi, IzinTelat, IzinTidakMasuk
from app.models.jadwal import JadwalShift, TukarShift
from app.models.karyawan import Karyawan
from app.models.pengeluaran import Pengeluaran
from app.models.transaksi import Transaksi, TransaksiDetail
from app.schemas.reporting import EmployeeBehaviorItem, SalesChartPoint

_BULAN_SHORT = [
    "Jan", "Feb", "Mar", "Apr", "Mei", "Jun",
    "Jul", "Agu", "Sep", "Okt", "Nov", "Des",
]


def resolve_dashboard_dates(
    preset: str,
    today: date,
    tanggal_mulai: Optional[date] = None,
    tanggal_selesai: Optional[date] = None,
) -> Tuple[date, date]:
    """Resolve preset or custom date bounds for dashboard overview."""
    if preset == "hari_ini":
        return today, today
    if preset == "7_hari":
        return today - timedelta(days=6), today
    if preset == "30_hari":
        return today - timedelta(days=29), today
    if preset == "bulan_ini":
        return today.replace(day=1), today
    if preset == "custom":
        if not tanggal_mulai or not tanggal_selesai:
            raise HTTPException(
                status_code=400,
                detail="tanggal_mulai dan tanggal_selesai wajib diisi untuk preset custom",
            )
        if tanggal_mulai > tanggal_selesai:
            raise HTTPException(
                status_code=400,
                detail="tanggal_mulai tidak boleh setelah tanggal_selesai",
            )
        return tanggal_mulai, tanggal_selesai
    raise HTTPException(status_code=400, detail="Preset dashboard tidak valid")


async def _fetch_bulanan_rates(
    db: AsyncSession,
    chart_start: date,
    chart_end: date,
) -> Dict[Tuple[int, int], Tuple[Decimal, Decimal]]:
    """Return {(year, month): (total_bulanan_month, daily_prorata_rate)} for months overlapping window."""
    rates: Dict[Tuple[int, int], Tuple[Decimal, Decimal]] = {}
    cur = chart_start.replace(day=1)
    end_m = chart_end.replace(day=1)
    while cur <= end_m:
        y, m = cur.year, cur.month
        m_days = Decimal(str(calendar.monthrange(y, m)[1]))
        res = await db.execute(
            select(func.sum(Pengeluaran.nominal)).where(
                and_(
                    Pengeluaran.tipe == "bulanan",
                    extract("year", Pengeluaran.bulan) == y,
                    extract("month", Pengeluaran.bulan) == m,
                )
            )
        )
        tot = Decimal(str(res.scalar() or 0))
        rates[(y, m)] = (tot, tot / m_days)
        cur = date(y + 1, 1, 1) if m == 12 else date(y, m + 1, 1)
    return rates


async def build_sales_chart(
    db: AsyncSession,
    start_date: date,
    end_date: date,
    chart_mode: str = "auto",
) -> Tuple[str, date, date, List[SalesChartPoint]]:
    """Build hourly, daily, or monthly sales & profit series for the dashboard chart."""
    span_days = (end_date - start_date).days
    if span_days == 0:
        if chart_mode == "jam":
            granularity = "jam"
            chart_start, chart_end = start_date, end_date
        else:
            granularity = "hari"
            chart_start = end_date - timedelta(days=6)
            chart_end = end_date
    elif span_days <= 45:
        granularity = "hari"
        chart_start, chart_end = start_date, end_date
    else:
        granularity = "bulan"
        chart_start, chart_end = start_date, end_date

    start_dt = datetime.combine(chart_start, datetime.min.time())
    end_dt = datetime.combine(chart_end, datetime.max.time())

    trx_rows = (
        await db.execute(
            select(Transaksi.id, Transaksi.waktu_transaksi, Transaksi.total_harga).where(
                and_(
                    Transaksi.waktu_transaksi >= start_dt,
                    Transaksi.waktu_transaksi <= end_dt,
                    Transaksi.status == "selesai",
                )
            )
        )
    ).all()

    detail_rows = (
        await db.execute(
            select(
                TransaksiDetail.transaksi_id,
                func.sum(TransaksiDetail.hpp_satuan * TransaksiDetail.qty),
            )
            .join(Transaksi, TransaksiDetail.transaksi_id == Transaksi.id)
            .where(
                and_(
                    Transaksi.waktu_transaksi >= start_dt,
                    Transaksi.waktu_transaksi <= end_dt,
                    Transaksi.status == "selesai",
                )
            )
            .group_by(TransaksiDetail.transaksi_id)
        )
    ).all()
    hpp_by_tx: Dict[str, Decimal] = {
        row[0]: Decimal(str(row[1] or 0)) for row in detail_rows
    }

    mendadak_rows = (
        await db.execute(
            select(Pengeluaran.tanggal, func.sum(Pengeluaran.nominal))
            .where(
                and_(
                    Pengeluaran.tipe == "mendadak",
                    Pengeluaran.tanggal >= chart_start,
                    Pengeluaran.tanggal <= chart_end,
                )
            )
            .group_by(Pengeluaran.tanggal)
        )
    ).all()
    mendadak_by_date: Dict[date, Decimal] = {
        row[0]: Decimal(str(row[1] or 0)) for row in mendadak_rows if row[0] is not None
    }

    bulanan_rates = await _fetch_bulanan_rates(db, chart_start, chart_end)
    points: List[SalesChartPoint] = []

    if granularity == "jam":
        buckets: Dict[int, Dict[str, object]] = {}
        tx_hours = [r[1].hour for r in trx_rows if r[1] is not None]
        min_h = min([8, *tx_hours]) if tx_hours else 8
        max_h = max([22, *tx_hours]) if tx_hours else 22
        for h in range(min_h, max_h + 1):
            buckets[h] = {"sales": Decimal("0"), "hpp": Decimal("0"), "count": 0}
        for tx_id, waktu, total in trx_rows:
            if not waktu:
                continue
            b = buckets[waktu.hour]
            b["sales"] = Decimal(str(b["sales"])) + Decimal(str(total or 0))
            b["hpp"] = Decimal(str(b["hpp"])) + hpp_by_tx.get(tx_id, Decimal("0"))
            b["count"] = int(b["count"]) + 1
        for h in range(min_h, max_h + 1):
            b = buckets[h]
            sales = round(Decimal(str(b["sales"])), 2)
            hpp = round(Decimal(str(b["hpp"])), 2)
            points.append(
                SalesChartPoint(
                    label=f"{h:02d}:00",
                    tanggal=f"{chart_start.isoformat()}T{h:02d}:00",
                    total_penjualan=sales,
                    total_hpp=hpp,
                    total_pengeluaran=Decimal("0.00"),
                    net_profit=round(sales - hpp, 2),
                    jumlah_transaksi=int(b["count"]),
                )
            )
    elif granularity == "hari":
        day_agg: Dict[date, Dict[str, object]] = {}
        cur = chart_start
        while cur <= chart_end:
            day_agg[cur] = {"sales": Decimal("0"), "hpp": Decimal("0"), "count": 0}
            cur += timedelta(days=1)
        for tx_id, waktu, total in trx_rows:
            if not waktu:
                continue
            d = waktu.date()
            if d in day_agg:
                b = day_agg[d]
                b["sales"] = Decimal(str(b["sales"])) + Decimal(str(total or 0))
                b["hpp"] = Decimal(str(b["hpp"])) + hpp_by_tx.get(tx_id, Decimal("0"))
                b["count"] = int(b["count"]) + 1
        cur = chart_start
        while cur <= chart_end:
            b = day_agg[cur]
            sales = round(Decimal(str(b["sales"])), 2)
            hpp = round(Decimal(str(b["hpp"])), 2)
            daily_bulanan = bulanan_rates.get((cur.year, cur.month), (Decimal("0"), Decimal("0")))[1]
            daily_mendadak = mendadak_by_date.get(cur, Decimal("0"))
            exp = round(daily_bulanan + daily_mendadak, 2)
            net = round(sales - hpp - exp, 2)
            points.append(
                SalesChartPoint(
                    label=f"{cur.day} {_BULAN_SHORT[cur.month - 1]}",
                    tanggal=cur.isoformat(),
                    total_penjualan=sales,
                    total_hpp=hpp,
                    total_pengeluaran=exp,
                    net_profit=net,
                    jumlah_transaksi=int(b["count"]),
                )
            )
            cur += timedelta(days=1)
    else:
        month_agg: Dict[Tuple[int, int], Dict[str, object]] = {}
        cur = chart_start.replace(day=1)
        end_m = chart_end.replace(day=1)
        while cur <= end_m:
            month_agg[(cur.year, cur.month)] = {"sales": Decimal("0"), "hpp": Decimal("0"), "count": 0}
            cur = date(cur.year + 1, 1, 1) if cur.month == 12 else date(cur.year, cur.month + 1, 1)
        for tx_id, waktu, total in trx_rows:
            if not waktu:
                continue
            key = (waktu.year, waktu.month)
            if key in month_agg:
                b = month_agg[key]
                b["sales"] = Decimal(str(b["sales"])) + Decimal(str(total or 0))
                b["hpp"] = Decimal(str(b["hpp"])) + hpp_by_tx.get(tx_id, Decimal("0"))
                b["count"] = int(b["count"]) + 1

        cur = chart_start.replace(day=1)
        while cur <= end_m:
            y, m = cur.year, cur.month
            m_last = calendar.monthrange(y, m)[1]
            o_start = max(chart_start, date(y, m, 1))
            o_end = min(chart_end, date(y, m, m_last))
            active_days = Decimal(str((o_end - o_start).days + 1)) if o_start <= o_end else Decimal("0")
            daily_rate = bulanan_rates.get((y, m), (Decimal("0"), Decimal("0")))[1]
            mendadak_sum = sum(
                (amt for dt, amt in mendadak_by_date.items() if o_start <= dt <= o_end),
                Decimal("0"),
            )
            exp = round(daily_rate * active_days + mendadak_sum, 2)
            b = month_agg[(y, m)]
            sales = round(Decimal(str(b["sales"])), 2)
            hpp = round(Decimal(str(b["hpp"])), 2)
            points.append(
                SalesChartPoint(
                    label=f"{_BULAN_SHORT[m - 1]} '{str(y)[2:]}",
                    tanggal=f"{y}-{m:02d}",
                    total_penjualan=sales,
                    total_hpp=hpp,
                    total_pengeluaran=exp,
                    net_profit=round(sales - hpp - exp, 2),
                    jumlah_transaksi=int(b["count"]),
                )
            )
            cur = date(y + 1, 1, 1) if m == 12 else date(y, m + 1, 1)

    return granularity, chart_start, chart_end, points


def _classify_behavior(
    total_hadir: int,
    total_shift_terjadwal: int,
    telat_count: int,
    total_menit_telat: int,
    lupa_absen_pulang_count: int,
    tanpa_keterangan_count: int,
    izin_tidak_masuk_count: int,
) -> Tuple[str, str]:
    """Determine employee behavioral status and human-readable Indonesian summary."""
    late_ratio = (telat_count / total_hadir) if total_hadir > 0 else 0.0
    is_serious = (
        telat_count >= 3
        or tanpa_keterangan_count >= 2
        or lupa_absen_pulang_count >= 2
        or (total_hadir >= 2 and late_ratio >= 0.4)
        or total_menit_telat >= 60
    )
    if is_serious:
        reasons: List[str] = []
        if telat_count >= 2 or total_menit_telat >= 60:
            reasons.append(f"Sering telat ({telat_count}x · {total_menit_telat} mnt)")
        elif telat_count == 1:
            reasons.append(f"Telat {total_menit_telat} mnt")
        if tanpa_keterangan_count >= 1:
            reasons.append(f"Tanpa keterangan {tanpa_keterangan_count}x")
        if lupa_absen_pulang_count >= 1:
            reasons.append(f"Lupa absen pulang {lupa_absen_pulang_count}x")
        return "perlu_perhatian", " · ".join(reasons) if reasons else "Perlu pembinaan"

    is_warning = (
        telat_count >= 1
        or tanpa_keterangan_count >= 1
        or lupa_absen_pulang_count >= 1
        or izin_tidak_masuk_count >= 2
    )
    if is_warning:
        notes: List[str] = []
        if telat_count >= 1:
            notes.append(f"Telat {telat_count}x ({total_menit_telat} mnt)")
        if lupa_absen_pulang_count >= 1:
            notes.append(f"Lupa pulang {lupa_absen_pulang_count}x")
        if tanpa_keterangan_count >= 1:
            notes.append(f"Tidak absen {tanpa_keterangan_count}x")
        if izin_tidak_masuk_count >= 2:
            notes.append(f"Izin tidak masuk {izin_tidak_masuk_count}x")
        return "waspada", " · ".join(notes)

    if total_hadir > 0:
        denom = max(total_shift_terjadwal, total_hadir)
        return "disiplin", f"Disiplin ({total_hadir}/{denom} shift tepat waktu)"

    if total_shift_terjadwal > 0:
        return "belum_ada_data", "Belum ada catatan hadir (izin/jadwal berjalan)"
    return "belum_ada_data", "Belum ada shift pada periode ini"


async def build_employee_behavior(
    db: AsyncSession,
    start_date: date,
    end_date: date,
    now: datetime,
) -> Tuple[date, date, Dict[str, object]]:
    """Aggregate attendance discipline & employee behavior across active staff."""
    if (end_date - start_date).days >= 6:
        beh_start, beh_end = start_date, end_date
    else:
        beh_end = end_date
        beh_start = end_date - timedelta(days=29)

    staff_list = (
        await db.execute(
            select(Karyawan)
            .where(and_(Karyawan.role == "karyawan", Karyawan.status_aktif.is_(True)))
            .order_by(Karyawan.nama.asc())
        )
    ).scalars().all()

    shifts = (
        await db.execute(
            select(JadwalShift).where(
                and_(JadwalShift.tanggal >= beh_start, JadwalShift.tanggal <= beh_end)
            )
        )
    ).scalars().all()
    shift_ids = [s.id for s in shifts]

    abs_by_shift: Dict[str, Absensi] = {}
    izin_telat_by_emp: Dict[str, int] = {}
    izin_tm_approved_shifts = set()
    izin_tm_by_emp: Dict[str, int] = {}

    if shift_ids:
        for a in (
            await db.execute(select(Absensi).where(Absensi.jadwal_shift_id.in_(shift_ids)))
        ).scalars().all():
            abs_by_shift[a.jadwal_shift_id] = a

        for it in (
            await db.execute(select(IzinTelat).where(IzinTelat.jadwal_shift_id.in_(shift_ids)))
        ).scalars().all():
            izin_telat_by_emp[it.karyawan_id] = izin_telat_by_emp.get(it.karyawan_id, 0) + 1

        for itm in (
            await db.execute(select(IzinTidakMasuk).where(IzinTidakMasuk.jadwal_shift_id.in_(shift_ids)))
        ).scalars().all():
            izin_tm_by_emp[itm.karyawan_id] = izin_tm_by_emp.get(itm.karyawan_id, 0) + 1
            if itm.status == "disetujui":
                izin_tm_approved_shifts.add(itm.jadwal_shift_id)

    beh_start_dt = datetime.combine(beh_start, datetime.min.time())
    beh_end_dt = datetime.combine(beh_end, datetime.max.time())
    tukar_by_emp: Dict[str, int] = {}
    for ts in (
        await db.execute(
            select(TukarShift).where(
                and_(TukarShift.diajukan_at >= beh_start_dt, TukarShift.diajukan_at <= beh_end_dt)
            )
        )
    ).scalars().all():
        tukar_by_emp[ts.karyawan_pengaju_id] = tukar_by_emp.get(ts.karyawan_pengaju_id, 0) + 1

    shifts_by_emp: Dict[str, List[JadwalShift]] = {}
    for s in shifts:
        shifts_by_emp.setdefault(s.karyawan_id, []).append(s)

    items: List[EmployeeBehaviorItem] = []
    team_hadir = 0
    team_tepat = 0
    team_telat = 0
    team_alpha = 0

    for k in staff_list:
        emp_shifts = shifts_by_emp.get(k.id, [])
        total_scheduled = 0
        hadir = 0
        tepat = 0
        telat = 0
        menit_telat_sum = 0
        lupa_pulang = 0
        alpha = 0

        for js in emp_shifts:
            shift_start_dt = datetime.combine(js.tanggal, js.jam_mulai)
            shift_end_dt = datetime.combine(js.tanggal, js.jam_selesai)
            if js.jam_selesai <= js.jam_mulai:
                shift_end_dt += timedelta(days=1)

            abs_row = abs_by_shift.get(js.id)
            if shift_start_dt <= now or abs_row is not None:
                total_scheduled += 1

            if abs_row is not None:
                hadir += 1
                m_late = int(abs_row.menit_telat or 0)
                if m_late > 0:
                    telat += 1
                    menit_telat_sum += m_late
                else:
                    tepat += 1

                if abs_row.status_pulang == "lupa_absen" or (
                    abs_row.jam_pulang is None
                    and shift_end_dt + timedelta(minutes=90) < now
                ):
                    lupa_pulang += 1
            else:
                if js.id not in izin_tm_approved_shifts and shift_end_dt < now:
                    alpha += 1

        izin_t = izin_telat_by_emp.get(k.id, 0)
        izin_tm = izin_tm_by_emp.get(k.id, 0)
        tukar_c = tukar_by_emp.get(k.id, 0)
        rata_late = round(menit_telat_sum / telat, 1) if telat > 0 else 0.0
        ketepatan_pct = round((tepat / hadir) * 100, 1) if hadir > 0 else 100.0

        kategori, ringkasan = _classify_behavior(
            total_hadir=hadir,
            total_shift_terjadwal=total_scheduled,
            telat_count=telat,
            total_menit_telat=menit_telat_sum,
            lupa_absen_pulang_count=lupa_pulang,
            tanpa_keterangan_count=alpha,
            izin_tidak_masuk_count=izin_tm,
        )

        team_hadir += hadir
        team_tepat += tepat
        team_telat += telat
        team_alpha += alpha

        items.append(
            EmployeeBehaviorItem(
                karyawan_id=k.id,
                nama=k.nama,
                divisi=k.divisi or "kasir",
                total_shift_terjadwal=total_scheduled,
                total_hadir=hadir,
                tepat_waktu_count=tepat,
                telat_count=telat,
                total_menit_telat=menit_telat_sum,
                rata_menit_telat=rata_late,
                izin_telat_count=izin_t,
                izin_tidak_masuk_count=izin_tm,
                lupa_absen_pulang_count=lupa_pulang,
                tanpa_keterangan_count=alpha,
                tukar_shift_count=tukar_c,
                tingkat_ketepatan_persen=ketepatan_pct,
                kategori_perilaku=kategori,
                ringkasan_perilaku=ringkasan,
            )
        )

    rank_order = {
        "perlu_perhatian": 0,
        "waspada": 1,
        "disiplin": 2,
        "belum_ada_data": 3,
    }
    items.sort(
        key=lambda x: (
            rank_order.get(x.kategori_perilaku, 4),
            -x.telat_count,
            -x.tanpa_keterangan_count,
            -x.lupa_absen_pulang_count,
            -x.total_menit_telat,
            x.nama.lower(),
        )
    )

    team_pct = round((team_tepat / team_hadir) * 100, 1) if team_hadir > 0 else 100.0
    return beh_start, beh_end, {
        "total_hadir": team_hadir,
        "tepat_waktu": team_tepat,
        "telat": team_telat,
        "alpha": team_alpha,
        "tingkat_ketepatan_tim_persen": team_pct,
        "items": items,
    }

