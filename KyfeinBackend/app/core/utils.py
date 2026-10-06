from datetime import datetime

def now_local() -> datetime:
    """
    Mengembalikan datetime lokasi server tanpa timezone (naive)
    selaras dengan kolom DATETIME pada database MySQL / SQLite.
    """
    return datetime.now()
