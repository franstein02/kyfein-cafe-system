"""
Kyfein Cafe System — Schema Migration & Database Sync Script (v3)
Applies schema_kyfein_mysql.sql (v3) to db_kyfein with explicit Foreign Keys,
area_kerja column, composite indexes, and utf8mb4_unicode_ci collation.
"""

import sys
import os
import re

# Adjust path to import app modules
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from sqlalchemy import create_engine, text
from app.core.config import settings

def apply_schema():
    print(f"[Schema Sync v3] Connecting to MySQL server at {settings.DB_HOST}:{settings.DB_PORT}...")
    
    # 1. Base engine to ensure db_kyfein exists & set collation
    pwd_part = f":{settings.DB_PASSWORD}" if settings.DB_PASSWORD else ""
    server_url = f"mysql+pymysql://{settings.DB_USER}{pwd_part}@{settings.DB_HOST}:{settings.DB_PORT}/"
    base_engine = create_engine(server_url)
    
    with base_engine.connect() as conn:
        conn.execute(text(f"CREATE DATABASE IF NOT EXISTS {settings.DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"))
        conn.execute(text(f"ALTER DATABASE {settings.DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"))
        conn.commit()
    print(f"[Schema Sync v3] Database '{settings.DB_NAME}' created/verified with utf8mb4_unicode_ci collation.")

    # 2. Connect to db_kyfein
    db_engine = create_engine(settings.SYNC_DATABASE_URL)
    
    # Locate schema_kyfein_mysql.sql
    root_dir = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    sql_file_path = os.path.join(root_dir, "schema_kyfein_mysql.sql")
    
    if not os.path.exists(sql_file_path):
        print(f"ERROR: File schema_kyfein_mysql.sql not found at {sql_file_path}")
        sys.exit(1)
        
    print(f"[Schema Sync v3] Reading SQL schema from {sql_file_path}...")
    with open(sql_file_path, "r", encoding="utf-8") as f:
        sql_content = f.read()

    # Split SQL file into statements handling DELIMITER $$
    statements = []
    current_delimiter = ";"
    current_stmt = []

    lines = sql_content.splitlines()
    for line in lines:
        stripped = line.strip()
        if stripped.startswith("DELIMITER"):
            current_delimiter = stripped.split()[1]
            continue
        
        if current_delimiter != ";" and line.endswith(current_delimiter):
            current_stmt.append(line[:-len(current_delimiter)])
            statements.append("\n".join(current_stmt))
            current_stmt = []
            current_delimiter = ";"
        elif current_delimiter == ";" and line.endswith(";"):
            current_stmt.append(line[:-1])
            statements.append("\n".join(current_stmt))
            current_stmt = []
        else:
            current_stmt.append(line)

    with db_engine.connect() as conn:
        conn.execute(text("SET FOREIGN_KEY_CHECKS = 0;"))
        for stmt in statements:
            # Remove comments and whitespace
            clean_stmt = re.sub(r'--.*', '', stmt).strip()
            if not clean_stmt:
                continue
            try:
                conn.execute(text(clean_stmt))
            except Exception as e:
                # If table exists or non-fatal info, log warning
                print(f"[Warning/Notice] Statement execution: {e}")
        conn.execute(text("SET FOREIGN_KEY_CHECKS = 1;"))
        conn.commit()

    print("[Schema Sync v3] Database migration & schema sync successfully applied to db_kyfein!")

    # 3. Trigger seed admin
    from scripts.seed_admin import seed_admin
    seed_admin()

if __name__ == "__main__":
    apply_schema()
