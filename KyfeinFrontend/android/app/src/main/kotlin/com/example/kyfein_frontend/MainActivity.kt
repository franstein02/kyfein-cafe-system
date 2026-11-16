package com.example.kyfein_frontend

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.async
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import java.util.UUID
import kotlin.random.Random

class MainActivity : FlutterActivity() {
    private val methodChannelName = "com.example.kyfein_frontend/coroutine_test"
    private val eventChannelName = "com.example.kyfein_frontend/coroutine_progress"

    private val mainScope = CoroutineScope(Dispatchers.Main + SupervisorJob())
    private var stressTestJob: Job? = null
    private var eventSink: EventChannel.EventSink? = null
    private lateinit var dbHelper: SqliteDbHelper

    data class MenuSample(val id: String, val nama: String, val harga: Double)

    private val sampleMenus = listOf(
        MenuSample("42c1e110-4fd6-45ba-ae09-7df1cb9e8b6b", "Coffee Latte", 15000.0),
        MenuSample("6888df9d-9cbf-4ca7-8eab-fcdb8dc601e2", "Nasi Goreng", 25000.0),
        MenuSample("6b471e3e-e570-4240-87b3-63ab987aac59", "Kopi Susu Gula Aren", 18000.0),
        MenuSample("e26e1a8d-1025-4f70-aca7-2b7a3c7075da", "Nasi Kebuli", 25000.0)
    )

    class DataCounter {
        var value = 0
        val mutex = Mutex()

        suspend fun increment(): Int = mutex.withLock {
            value++
            value
        }

        suspend fun get(): Int = mutex.withLock { value }
    }

    private fun currentIsoTime(): String {
        val sdf = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US)
        sdf.timeZone = TimeZone.getTimeZone("UTC")
        return sdf.format(Date())
    }

    private fun emitProgress(
        sqlite: Int,
        firebase: Int,
        total: Int,
        done: Boolean,
        cancelled: Boolean
    ) {
        eventSink?.success(
            mapOf(
                "sqlite" to sqlite,
                "firebase" to firebase,
                "total" to total,
                "done" to done,
                "cancelled" to cancelled
            )
        )
    }

    private fun startStressTest() {
        stressTestJob?.cancel()
        val total = 100
        val sqliteCounter = DataCounter()
        val firebaseCounter = DataCounter()

        stressTestJob = mainScope.launch {
            var wasCancelled = false
            try {
                emitProgress(0, 0, total, done = false, cancelled = false)

                val workers = mutableListOf<Job>()
                for (i in 1..total) {
                    if (!isActive) break
                    delay(80L)

                    val worker = launch(Dispatchers.IO) {
                        val id = UUID.randomUUID().toString()
                        val jadwalShiftId = "jadwal-frans-today"
                        val kasirId = "6eb0abd6-c196-11f1-84bd-00155dbd31c3"
                        val nomorTransaksi = "TRX-${System.currentTimeMillis()}-$i"
                        val metodeBayar = if (i % 2 == 0) "qris" else "cash"
                        val menu = sampleMenus[Random.nextInt(sampleMenus.size)]
                        val qty = Random.nextInt(1, 5)
                        val totalHarga = menu.harga * qty
                        val uangDiterima = if (metodeBayar == "cash") totalHarga + 5000.0 else totalHarga
                        val kembalian = uangDiterima - totalHarga
                        val status = "selesai"
                        val waktuTransaksi = currentIsoTime()

                        val sqliteDeferred = async {
                            try {
                                dbHelper.insert(
                                    id, jadwalShiftId, kasirId, nomorTransaksi,
                                    metodeBayar, totalHarga, uangDiterima, kembalian,
                                    status, waktuTransaksi
                                )
                            } catch (e: Exception) {
                                false
                            }
                        }

                        val firebaseDeferred = async {
                            try {
                                FirebaseRealtimeHelper.insert(
                                    id, jadwalShiftId, kasirId, nomorTransaksi,
                                    metodeBayar, menu.id, qty, menu.harga,
                                    totalHarga, uangDiterima, kembalian,
                                    status, waktuTransaksi
                                )
                            } catch (e: Exception) {
                                false
                            }
                        }

                        val sqlOk = sqliteDeferred.await()
                        val fbOk = firebaseDeferred.await()

                        val sCount = if (sqlOk) sqliteCounter.increment() else sqliteCounter.get()
                        val fCount = if (fbOk) firebaseCounter.increment() else firebaseCounter.get()

                        withContext(Dispatchers.Main) {
                            emitProgress(sCount, fCount, total, done = false, cancelled = false)
                        }
                    }
                    workers.add(worker)
                }

                workers.forEach { it.join() }
            } catch (_: CancellationException) {
                wasCancelled = true
            } finally {
                withContext(NonCancellable + Dispatchers.Main) {
                    val sFinal = sqliteCounter.get()
                    val fFinal = firebaseCounter.get()
                    emitProgress(
                        sFinal,
                        fFinal,
                        total,
                        done = true,
                        cancelled = wasCancelled
                    )
                }
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        dbHelper = SqliteDbHelper(this)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, eventChannelName)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            })

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, methodChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startStressTest" -> {
                        startStressTest()
                        result.success(true)
                    }
                    "cancelStressTest" -> {
                        stressTestJob?.cancel()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        stressTestJob?.cancel()
        mainScope.cancel()
        super.onDestroy()
    }
}
