package com.example.kyfein_frontend

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper

class SqliteDbHelper(context: Context) : SQLiteOpenHelper(context, "db_kyfein_local", null, 1) {
    override fun onCreate(db: SQLiteDatabase?) {
        // Membuat tabel transaksi sesuai skema Kyfein
        val tTransaksi = """
            CREATE TABLE transaksi (
                id TEXT PRIMARY KEY,
                jadwal_shift_id TEXT NOT NULL,
                kasir_id TEXT NOT NULL,
                nomor_transaksi TEXT NOT NULL,
                metode_bayar TEXT NOT NULL,
                total_harga REAL NOT NULL,
                uang_diterima REAL,
                kembalian REAL,
                status TEXT NOT NULL,
                waktu_transaksi TEXT NOT NULL
            )
        """.trimIndent()
        db?.execSQL(tTransaksi)
    }

    override fun onUpgrade(db: SQLiteDatabase?, oldVersion: Int, newVersion: Int) {
        db?.execSQL("DROP TABLE IF EXISTS transaksi")
        onCreate(db)
    }

    fun insert(
        id: String,
        jadwalShiftId: String,
        kasirId: String,
        nomorTransaksi: String,
        metodeBayar: String,
        totalHarga: Double,
        uangDiterima: Double,
        kembalian: Double,
        status: String,
        waktuTransaksi: String
    ): Boolean {
        val db = writableDatabase
        val cv = ContentValues()
        cv.put("id", id)
        cv.put("jadwal_shift_id", jadwalShiftId)
        cv.put("kasir_id", kasirId)
        cv.put("nomor_transaksi", nomorTransaksi)
        cv.put("metode_bayar", metodeBayar)
        cv.put("total_harga", totalHarga)
        cv.put("uang_diterima", uangDiterima)
        cv.put("kembalian", kembalian)
        cv.put("status", status)
        cv.put("waktu_transaksi", waktuTransaksi)
        return db.insert("transaksi", null, cv) != -1L
    }
}

