# Kyfein — Cafe POS & Management System

Kyfein is an on-premise Cafe POS & Operations Management System built with a **Modular Monolith** architecture. Designed for 1 cafe location, featuring 6 core operational modules.

---

## 🏗️ Architecture & Stack

- **Backend (`KyfeinBackend/`):** Python FastAPI + SQLAlchemy + MySQL (`db_kyfein`), WebSockets for KDS realtime events.
- **Frontend (`KyfeinFrontend/`):** Flutter (Flutter Web for Laragon/Nginx deployment on iOS/PC, APK for Android POS/KDS devices).
- **Web Server & Reverse Proxy:** Nginx (Laragon environment on Windows PC Server).
- **Database:** MySQL / MariaDB (Database name: `db_kyfein`).

---

## 📁 Repository Structure

```
Project-Kyfein/
├── .gitignore
├── README.md
├── nginx.conf.example
├── rencana-pengembangan-kyfein.md    # Architecture & business rules reference
├── schema_kyfein_mysql.sql           # MySQL database schema definition
├── KyfeinBackend/                    # FastAPI Modular Monolith Backend
│   ├── app/
│   │   ├── api/v1/endpoints/        # Auth, Karyawan, Master, Transaksi, Stok, Absensi, Jadwal, KDS, Reporting
│   │   ├── core/                    # Security, Database, Config, Dependencies
│   │   ├── models/                  # SQLAlchemy ORM Models
│   │   ├── schemas/                 # Pydantic Schemas
│   │   └── main.py                  # FastAPI Application & WebSocket Manager
│   ├── scripts/                     # Seed Admin script
│   ├── .env.example
│   └── requirements.txt
└── KyfeinFrontend/                   # Flutter Web & Mobile Client Application
    ├── lib/
    │   ├── core/                    # API client, WebSocket client, Theme, Storage
    │   ├── features/                # Auth, POS, KDS, Absensi, Stok, Jadwal, Reporting
    │   └── main.dart
    └── pubspec.yaml
```

---

## 🚀 Setup & Installation Guide

### 1. Database Setup (`db_kyfein`)
1. Open Laragon / MySQL Server.
2. Create database named `db_kyfein`:
   ```sql
   CREATE DATABASE db_kyfein CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
   ```
3. Import `schema_kyfein_mysql.sql` into `db_kyfein`.

### 2. Backend Setup (`KyfeinBackend`)
1. Navigate to backend directory:
   ```bash
   cd KyfeinBackend
   ```
2. Create and activate a virtual environment:
   ```bash
   python -m venv venv
   # On Windows PowerShell:
   .\venv\Scripts\Activate.ps1
   ```
3. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```
4. Copy `.env.example` to `.env` and adjust database credentials:
   ```bash
   copy .env.example .env
   ```
5. Seed initial Admin account directly in the database (as specified in 4.3):
   ```bash
   python scripts/seed_admin.py
   ```
6. Run the FastAPI development server:
   ```bash
   uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
   ```
   - OpenAPI Docs: `http://localhost:8000/docs`

### 3. Nginx Reverse Proxy Setup (Laragon)
Copy snippet from `nginx.conf.example` into your Nginx virtual host configuration (`nginx/conf/vhosts/kyfein.conf`).

### 4. Frontend Setup (`KyfeinFrontend`)
1. Navigate to frontend directory:
   ```bash
   cd KyfeinFrontend
   ```
2. Fetch dependencies:
   ```bash
   flutter pub get
   ```
3. Run locally:
   ```bash
   flutter run -d chrome
   ```

---

## 🔐 Key Business Rules Implemented

1. **Void Transaction Enforcement (`transaksi.py`):** Transactions can only be canceled by the cashier before the `stok_opname` with type `akhir_shift` for that shift is submitted. Status changes to `dibatalkan` (never hard-deleted).
2. **Active Shift Report (`transaksi.py` / `reporting.py`):** Read-only on-demand query for revenue and payment breakdown (cash/QRIS) strictly scoped to the employee's currently active shift.
3. **Daily Profit Calculation (`reporting.py`):**
   $$\text{Daily Profit} = \text{Sales} - \text{HPP} - \frac{\text{Monthly Expenses}}{\text{Days in Month}} - \text{One-Time Expenses}$$
   HPP is calculated on-demand from recipes ($\text{recipe} \times \text{sold qty}$), not warehouse purchases.
4. **KDS Realtime Routing (`kds.py`):** WebSocket broadcasts are filtered by `area_produksi` (`kitchen` vs `bar`).
5. **Twin Checkpoint Stock Opname (`stok.py`):** Supports `carry_forward` (1-tap handover confirmation for same-day shifts) and `hitung_manual` (mandatory physical count for overnight/cross-day shifts).
6. **Admin Account Security:** Admin accounts are created initially via `scripts/seed_admin.py`.
