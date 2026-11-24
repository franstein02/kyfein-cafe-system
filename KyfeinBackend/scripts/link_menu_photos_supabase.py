"""Upload dan tautkan foto seluruh 31 menu (Bar & Kitchen) ke Supabase Storage & db_kyfein.

Catatan:
- 5 foto yang sudah ada di Supabase Storage (`Storage/menu/`) langsung ditautkan ke menu terkait.
- 26 foto tambahan diunggah ke `Storage/menu/<kode>.jpg` (opsional lewat `--upload`, default hanya verifikasi HTTP 200 dan tautkan DB jika objek sudah ada).
- Idempoten: menjalankan ulang tidak membuat duplikat record `Foto` untuk URL yang sama.
"""

from __future__ import annotations

import argparse
import asyncio
from io import BytesIO
import os
from pathlib import Path
import sys
import urllib.error
import urllib.request
import uuid

from PIL import Image, ImageOps
from sqlalchemy import select

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.core.database import AsyncSessionLocal
from app.models.foto import Foto
from app.models.karyawan import Karyawan
from app.models.master_data import Menu

DEFAULT_SUPABASE_URL = os.getenv("SUPABASE_URL", "https://psdeyhujegvaczqyozbz.supabase.co")
DEFAULT_SUPABASE_KEY = os.getenv("SUPABASE_KEY", "sb_publishable_-uzUI0ciD9S5VJTr-NHeCA_IWZb-eHe")
DEFAULT_BUCKET = os.getenv("SUPABASE_BUCKET", "Storage")

# Peta lengkap 31 menu aktif -> nama objek di bucket Supabase Storage/menu/
EXISTING_SUPABASE_OBJECTS: dict[str, str] = {
    "MNM01": "menu/1791720814888.jpg",  # Coffee Latte
    "MNM03": "menu/1791720792561.jpg",  # Americano
    "MNM17": "menu/1792135024061.jpg",  # Matcha Original
    "MKN01": "menu/1791720824900.jpg",  # Nasi Goreng
    "MKN02": "menu/1791722284520.jpg",  # Nasi Kebuli
}

UPLOAD_TARGET_OBJECTS: dict[str, str] = {
    "MNM02": "menu/mnm02_kopi_susu_gula_aren.jpg",
    "MNM04": "menu/mnm04_americano_gula_aren.jpg",
    "MNM05": "menu/mnm05_coconut_aren_latte.jpg",
    "MNM06": "menu/mnm06_vanila_latte.jpg",
    "MNM07": "menu/mnm07_mochacino.jpg",
    "MNM08": "menu/mnm08_kayuhan_creamy_latte.jpg",
    "MNM09": "menu/mnm09_salted_caramel_latte.jpg",
    "MNM10": "menu/mnm10_pandan_latte.jpg",
    "MNM11": "menu/mnm11_alpenliebe_butterscotch.jpg",
    "MNM12": "menu/mnm12_kayuhan_signature.jpg",
    "MNM13": "menu/mnm13_chocolate.jpg",
    "MNM14": "menu/mnm14_choco_caramel.jpg",
    "MNM15": "menu/mnm15_choco_vanila.jpg",
    "MNM16": "menu/mnm16_choco_butterscotch.jpg",
    "MNM18": "menu/mnm18_matcha_vanilla.jpg",
    "MNM19": "menu/mnm19_matcha_caramel.jpg",
    "MNM20": "menu/mnm20_matcha_butterscotch.jpg",
    "MNM21": "menu/mnm21_matcha_strawberry.jpg",
    "MNM22": "menu/mnm22_korean_strawberry_milk.jpg",
    "MNM23": "menu/mnm23_strawberry_vanilla.jpg",
    "MKN03": "menu/mkn03_chicken_katsu_rice_bowl.jpg",
    "MKN04": "menu/mkn04_chicken_rice_bowl_telur.jpg",
    "MKN05": "menu/mkn05_kentang_goreng.jpg",
    "MKN06": "menu/mkn06_mix_platter.jpg",
    "MKN07": "menu/mkn07_sosis_nugget_goreng.jpg",
    "MKN08": "menu/mkn08_roti_bakar_keju.jpg",
}

DEFAULT_SOURCE_FILES: dict[str, str] = {
    "MNM02": r"C:\Users\ACER\.gemini\antigravity\brain\4a6f4da2-a9d2-4287-b04c-bd7319992394\mnm02_kopi_susu_gula_aren_v2_1794920904935.jpg",
    "MNM04": r"C:\Users\ACER\.gemini\antigravity\brain\4a6f4da2-a9d2-4287-b04c-bd7319992394\mnm04_americano_gula_aren_1794920905281.jpg",
    "MNM05": r"C:\Users\ACER\.gemini\antigravity\brain\4a6f4da2-a9d2-4287-b04c-bd7319992394\mnm05_coconut_aren_latte_1794920882703.jpg",
    "MNM06": r"C:\Users\ACER\.gemini\antigravity\brain\4a6f4da2-a9d2-4287-b04c-bd7319992394\mnm06_vanila_latte_1794920883268.jpg",
    "MNM07": r"C:\Users\ACER\.gemini\antigravity\brain\4a6f4da2-a9d2-4287-b04c-bd7319992394\mnm07_mochacino_1794920889862.jpg",
    "MNM08": r"C:\Users\ACER\.gemini\antigravity\brain\4a6f4da2-a9d2-4287-b04c-bd7319992394\mnm08_kayuhan_creamy_latte_1794920889430.jpg",
    "MNM09": r"C:\Users\ACER\.gemini\antigravity\brain\4a6f4da2-a9d2-4287-b04c-bd7319992394\mnm09_salted_caramel_latte_1794920979615.jpg",
    "MNM10": r"C:\Users\ACER\.gemini\antigravity\brain\4a6f4da2-a9d2-4287-b04c-bd7319992394\mnm10_pandan_latte_1794920984587.jpg",
    "MNM11": r"C:\Users\ACER\.gemini\antigravity\brain\4a6f4da2-a9d2-4287-b04c-bd7319992394\mnm11_alpenliebe_butterscotch_1794920990769.jpg",
    "MNM12": r"C:\Users\ACER\.gemini\antigravity\brain\4a6f4da2-a9d2-4287-b04c-bd7319992394\mnm12_kayuhan_signature_1794920987831.jpg",
    "MNM13": r"C:\Users\ACER\.gemini\antigravity\brain\4a6f4da2-a9d2-4287-b04c-bd7319992394\scratch\candidates\mnm15_choco_vanila_b.jpg",
    "MNM14": r"C:\Users\ACER\.gemini\antigravity\brain\4a6f4da2-a9d2-4287-b04c-bd7319992394\mnm14_choco_caramel_1794920997836.jpg",
    "MNM15": r"C:\Users\ACER\.gemini\antigravity\brain\4a6f4da2-a9d2-4287-b04c-bd7319992394\scratch\candidates\mnm15_choco_vanila_a.jpg",
    "MNM16": r"C:\Users\ACER\.gemini\antigravity\brain\4a6f4da2-a9d2-4287-b04c-bd7319992394\scratch\candidates\mnm16_choco_butterscotch_fl1.jpg",
    "MNM18": r"C:\Users\ACER\.gemini\antigravity\brain\4a6f4da2-a9d2-4287-b04c-bd7319992394\scratch\candidates\mnm18_matcha_vanilla_a.jpg",
    "MNM19": r"C:\Users\ACER\.gemini\antigravity\brain\4a6f4da2-a9d2-4287-b04c-bd7319992394\scratch\candidates\mnm19_matcha_caramel_ov1.jpg",
    "MNM20": r"C:\Users\ACER\.gemini\antigravity\brain\4a6f4da2-a9d2-4287-b04c-bd7319992394\scratch\candidates\mnm20_matcha_butterscotch_ov1.jpg",
    "MNM21": r"C:\Users\ACER\.gemini\antigravity\brain\4a6f4da2-a9d2-4287-b04c-bd7319992394\scratch\candidates\mnm21_matcha_strawberry_ov1.jpg",
    "MNM22": r"C:\Users\ACER\.gemini\antigravity\brain\4a6f4da2-a9d2-4287-b04c-bd7319992394\scratch\candidates\mnm22_strawberry_wm.jpg",
    "MNM23": r"C:\Users\ACER\.gemini\antigravity\brain\4a6f4da2-a9d2-4287-b04c-bd7319992394\scratch\candidates\mnm23_strawberry_vanilla_a.jpg",
    "MKN03": r"C:\Users\ACER\.gemini\antigravity\brain\4a6f4da2-a9d2-4287-b04c-bd7319992394\scratch\candidates\mkn03_chicken_katsu_a.jpg",
    "MKN04": r"C:\Users\ACER\.gemini\antigravity\brain\4a6f4da2-a9d2-4287-b04c-bd7319992394\scratch\candidates\mkn03_chicken_katsu_b.jpg",
    "MKN05": r"C:\Users\ACER\.gemini\antigravity\brain\4a6f4da2-a9d2-4287-b04c-bd7319992394\scratch\candidates\mkn05_kentang_goreng_b.jpg",
    "MKN06": r"C:\Users\ACER\.gemini\antigravity\brain\4a6f4da2-a9d2-4287-b04c-bd7319992394\scratch\candidates\mkn06_mix_platter_a.jpg",
    "MKN07": r"C:\Users\ACER\.gemini\antigravity\brain\4a6f4da2-a9d2-4287-b04c-bd7319992394\scratch\candidates\mkn07_nugget_wm.jpg",
    "MKN08": r"C:\Users\ACER\.gemini\antigravity\brain\4a6f4da2-a9d2-4287-b04c-bd7319992394\scratch\candidates\mkn08_roti_bakar_keju_a.jpg",
}


def public_object_url(base_url: str, bucket: str, object_path: str) -> str:
    return f"{base_url.rstrip('/')}/storage/v1/object/public/{bucket}/{object_path}"


def optimize_jpeg_bytes(src_path: Path, max_dim: int = 900) -> bytes:
    with Image.open(src_path) as img:
        img = ImageOps.exif_transpose(img).convert("RGB")
        img.thumbnail((max_dim, max_dim), Image.Resampling.LANCZOS)
        buf = BytesIO()
        img.save(buf, format="JPEG", quality=88, optimize=True)
        return buf.getvalue()


def upload_to_supabase(base_url: str, api_key: str, bucket: str, object_path: str, data: bytes) -> None:
    upload_url = f"{base_url.rstrip('/')}/storage/v1/object/{bucket}/{object_path}"
    req = urllib.request.Request(
        upload_url,
        data=data,
        method="POST",
        headers={
            "apikey": api_key,
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "image/jpeg",
            "x-upsert": "true",
        },
    )
    with urllib.request.urlopen(req, timeout=30) as resp:
        if resp.status not in (200, 201):
            raise RuntimeError(f"Upload gagal ({resp.status}) untuk {object_path}")


def verify_public_image_url(url: str) -> tuple[int, str, int]:
    req = urllib.request.Request(url, method="HEAD")
    with urllib.request.urlopen(req, timeout=20) as resp:
        ctype = resp.headers.get("Content-Type", "")
        clen = int(resp.headers.get("Content-Length", "0") or "0")
        return resp.status, ctype, clen


async def link_photos_in_db(url_by_kode: dict[str, str]) -> None:
    async with AsyncSessionLocal() as db:
        admin_res = await db.execute(select(Karyawan).where(Karyawan.role == "admin"))
        admin = admin_res.scalars().first()
        if not admin:
            raise RuntimeError("Karyawan admin tidak ditemukan di database.")

        menus_res = await db.execute(select(Menu).order_by(Menu.kode_menu))
        menus = menus_res.scalars().all()
        menu_by_kode = {m.kode_menu: m for m in menus}

        missing = sorted(set(menu_by_kode.keys()) - set(url_by_kode.keys()))
        if missing:
            raise RuntimeError(f"Menu tanpa mapping foto: {missing}")

        existing_fotos_res = await db.execute(select(Foto).where(Foto.jenis == "menu"))
        foto_by_url = {f.path: f for f in existing_fotos_res.scalars().all()}

        linked_count = 0
        for kode, pub_url in sorted(url_by_kode.items()):
            menu = menu_by_kode.get(kode)
            if not menu:
                print(f"[SKIP] Kode menu {kode} tidak ditemukan di DB")
                continue

            foto = foto_by_url.get(pub_url)
            if not foto:
                foto = Foto(
                    id=str(uuid.uuid4()),
                    jenis="menu",
                    path=pub_url,
                    uploader_id=admin.id,
                    dipakai=True,
                )
                db.add(foto)
                await db.flush()
                foto_by_url[pub_url] = foto
            else:
                foto.dipakai = True

            if menu.foto_id and menu.foto_id != foto.id:
                old_foto = await db.get(Foto, menu.foto_id)
                if old_foto and old_foto.path != pub_url:
                    old_foto.dipakai = False

            menu.foto_id = foto.id
            menu.diubah_oleh = admin.id
            linked_count += 1

        await db.commit()
        print(f"DB SUKSES: {linked_count}/{len(menus)} menu berhasil ditautkan ke Foto Supabase.")


def main() -> None:
    parser = argparse.ArgumentParser(description="Upload & tautkan seluruh foto menu ke Supabase.")
    parser.add_argument("--upload", action="store_true", help="Unggah 26 foto lokal baru ke Supabase Storage.")
    parser.add_argument("--base-url", default=DEFAULT_SUPABASE_URL)
    parser.add_argument("--api-key", default=DEFAULT_SUPABASE_KEY)
    parser.add_argument("--bucket", default=DEFAULT_BUCKET)
    args = parser.parse_args()

    all_objects = {**EXISTING_SUPABASE_OBJECTS, **UPLOAD_TARGET_OBJECTS}

    if args.upload:
        for kode, obj_path in sorted(UPLOAD_TARGET_OBJECTS.items()):
            src_str = DEFAULT_SOURCE_FILES.get(kode)
            if not src_str or not Path(src_str).is_file():
                raise FileNotFoundError(f"Sumber foto untuk {kode} tidak ditemukan: {src_str}")
            jpeg_bytes = optimize_jpeg_bytes(Path(src_str))
            upload_to_supabase(args.base_url, args.api_key, args.bucket, obj_path, jpeg_bytes)
            print(f"[UPLOAD] {kode} -> {obj_path} ({len(jpeg_bytes)} B)")

    url_by_kode: dict[str, str] = {}
    for kode, obj_path in sorted(all_objects.items()):
        pub_url = public_object_url(args.base_url, args.bucket, obj_path)
        status, ctype, clen = verify_public_image_url(pub_url)
        if status != 200 or not ctype.startswith("image/"):
            raise RuntimeError(f"Verifikasi URL gagal untuk {kode}: {pub_url} -> {status} {ctype}")
        url_by_kode[kode] = pub_url
        print(f"[VERIFIED 200] {kode} -> {obj_path} ({ctype}, {clen} B)")

    asyncio.run(link_photos_in_db(url_by_kode))


if __name__ == "__main__":
    main()

