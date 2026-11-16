package com.example.kyfein_frontend

import com.google.firebase.database.DatabaseReference
import com.google.firebase.database.FirebaseDatabase
import java.util.UUID
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException
import kotlinx.coroutines.suspendCancellableCoroutine

object FirebaseRealtimeHelper {
    val fbDb: FirebaseDatabase by lazy { FirebaseDatabase.getInstance() }
    val ref: DatabaseReference by lazy { fbDb.getReference("transaksi") }
    val detailRef: DatabaseReference by lazy { fbDb.getReference("transaksi_detail") }

    suspend fun insert(
        id: String,
        jadwalShiftId: String,
        kasirId: String,
        nomorTransaksi: String,
        metodeBayar: String,
        menuId: String,
        qty: Int,
        hargaSatuan: Double,
        totalHarga: Double,
        uangDiterima: Double,
        kembalian: Double,
        status: String,
        waktuTransaksi: String
    ): Boolean = suspendCancellableCoroutine { cont ->
        val payload = mapOf(
            "id" to id,
            "jadwal_shift_id" to jadwalShiftId,
            "kasir_id" to kasirId,
            "nomor_transaksi" to nomorTransaksi,
            "metode_bayar" to metodeBayar,
            "total_harga" to totalHarga,
            "uang_diterima" to uangDiterima,
            "kembalian" to kembalian,
            "foto_bukti_qris_id" to null,
            "status" to status,
            "waktu_transaksi" to waktuTransaksi,
            "created_at" to waktuTransaksi
        )
        val detailId = UUID.randomUUID().toString()
        val detailPayload = mapOf(
            "id" to detailId,
            "transaksi_id" to id,
            "menu_id" to menuId,
            "qty" to qty,
            "harga_satuan" to hargaSatuan,
            "hpp_satuan" to (hargaSatuan * 0.4),
            "catatan" to "Test Coroutine",
            "subtotal" to totalHarga,
            "status_item" to "menunggu"
        )
        ref.child(id).setValue(payload)
            .addOnSuccessListener {
                detailRef.child(detailId).setValue(detailPayload)
                    .addOnSuccessListener {
                        if (cont.isActive) cont.resume(true)
                    }
                    .addOnFailureListener { except ->
                        if (cont.isActive) cont.resumeWithException(except)
                    }
            }
            .addOnFailureListener { except ->
                if (cont.isActive) cont.resumeWithException(except)
            }
    }
}
