package com.aritxonly.hyperpiliplus

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationManager
import android.os.CancellationSignal
import android.os.Handler
import android.os.Looper
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.atomic.AtomicBoolean

/** A foreground-only, one-shot location bridge for an explicit check-in. */
class FamilyLocation(
    private val activity: Activity,
    engine: FlutterEngine,
) {
    private val channel = MethodChannel(
        engine.dartExecutor.binaryMessenger,
        "hyper_piliplus/family_location",
    )
    private val locationManager =
        activity.getSystemService(Context.LOCATION_SERVICE) as LocationManager
    private val handler = Handler(Looper.getMainLooper())
    private val cancellationSignals = mutableListOf<CancellationSignal>()
    private var pendingResult: MethodChannel.Result? = null
    private var timeout: Runnable? = null

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getCurrentLocation" -> getCurrentLocation(result)
                else -> result.notImplemented()
            }
        }
    }

    private fun getCurrentLocation(result: MethodChannel.Result) {
        if (pendingResult != null) {
            result.error("busy", "A location request is already running", null)
            return
        }
        if (!hasLocationPermission()) {
            result.error("permission_denied", "Foreground location permission is required", null)
            return
        }
        if (!locationManager.isLocationEnabled) {
            result.error("service_disabled", "System location service is disabled", null)
            return
        }

        val providers = listOf(
            LocationManager.FUSED_PROVIDER,
            LocationManager.GPS_PROVIDER,
            LocationManager.NETWORK_PROVIDER,
        ).filter { provider ->
            locationManager.allProviders.contains(provider) &&
                locationManager.isProviderEnabled(provider)
        }.distinct()
        if (providers.isEmpty()) {
            result.error("unavailable", "No enabled location provider", null)
            return
        }

        pendingResult = result
        val completed = AtomicBoolean(false)
        val timeoutRunnable = Runnable {
            if (completed.compareAndSet(false, true)) {
                finishWithError("timeout", "Timed out while getting location")
            }
        }
        timeout = timeoutRunnable
        handler.postDelayed(timeoutRunnable, LOCATION_TIMEOUT_MS)

        providers.forEach { provider ->
            val cancellationSignal = CancellationSignal()
            cancellationSignals += cancellationSignal
            try {
                locationManager.getCurrentLocation(
                    provider,
                    cancellationSignal,
                    activity.mainExecutor,
                ) { location ->
                    if (location != null && completed.compareAndSet(false, true)) {
                        finishWithLocation(location)
                    }
                }
            } catch (_: SecurityException) {
                if (completed.compareAndSet(false, true)) {
                    finishWithError("permission_denied", "Location permission was revoked")
                }
            } catch (_: IllegalArgumentException) {
                // Another provider may still return a valid location.
            }
        }
    }

    private fun hasLocationPermission(): Boolean =
        ContextCompat.checkSelfPermission(
            activity,
            Manifest.permission.ACCESS_COARSE_LOCATION,
        ) == PackageManager.PERMISSION_GRANTED ||
            ContextCompat.checkSelfPermission(
                activity,
                Manifest.permission.ACCESS_FINE_LOCATION,
            ) == PackageManager.PERMISSION_GRANTED

    private fun finishWithLocation(location: Location) {
        val result = pendingResult ?: return
        clearPending()
        result.success(
            mapOf(
                "latitude" to location.latitude,
                "longitude" to location.longitude,
                "accuracyMeters" to location.accuracy.toDouble(),
                "capturedAtMs" to location.time,
            ),
        )
    }

    private fun finishWithError(code: String, message: String) {
        val result = pendingResult ?: return
        clearPending()
        result.error(code, message, null)
    }

    private fun clearPending() {
        timeout?.let(handler::removeCallbacks)
        timeout = null
        cancellationSignals.forEach(CancellationSignal::cancel)
        cancellationSignals.clear()
        pendingResult = null
    }

    fun dispose() {
        pendingResult?.error("unavailable", "Activity was destroyed", null)
        clearPending()
        channel.setMethodCallHandler(null)
    }

    companion object {
        private const val LOCATION_TIMEOUT_MS = 15_000L
    }
}
