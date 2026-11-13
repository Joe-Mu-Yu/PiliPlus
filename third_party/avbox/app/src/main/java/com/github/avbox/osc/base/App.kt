package com.github.avbox.osc.base

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import android.os.Build
import android.os.StrictMode
import android.os.SystemClock

import com.github.catvod.crawler.JsLoader
import com.github.avbox.osc.BuildConfig
import com.github.avbox.osc.boot.BootGuard
import com.github.avbox.osc.data.AppDataManager
import com.github.avbox.osc.io.FileUtils
import com.github.avbox.osc.net.HttpClients
import com.github.avbox.osc.server.ControlManager
import com.github.avbox.osc.util.AppContextHolder
import com.github.avbox.osc.util.ActivityStack
import com.github.avbox.osc.util.EpgUtil
import com.github.avbox.osc.util.KVKeys
import com.github.avbox.osc.util.KV
import com.github.avbox.osc.util.AppLog
import com.github.avbox.osc.util.LanguageManager
import com.github.avbox.osc.util.Probe
import com.github.avbox.osc.util.VodImages
import com.whl.quickjs.android.QuickJSLoader

class App private constructor(base: Context) : ContextWrapper(base.applicationContext) {

    private var bootLastMs = 0L

    private fun bootMark(step: String) {
        if (!BuildConfig.DEBUG) return
        val now = SystemClock.elapsedRealtime()
        AppLog.i("echo-boot $step dt=" + (now - bootLastMs) + "ms")
        bootLastMs = now
    }

    private fun initialize() {
        bootLastMs = SystemClock.elapsedRealtime()
        installStrictMode()
        bootMark("installStrictMode")
        instance = this
        AppContextHolder.install(this)
        BootGuard.install()
        bootMark("bootGuard")
        initParams()
        bootMark("initParams")
        Probe.trace("boot:httpClients") { HttpClients.init() }
        bootMark("httpClients")
        Probe.trace("boot:epgUtil") { EpgUtil.init() }
        bootMark("epgUtil")
        Probe.trace("boot:controlManager") { ControlManager.init(this) }
        bootMark("controlManager")
        Probe.trace("boot:appDataManager") { AppDataManager.init() }
        bootMark("appDataManager")
        // Hyper-PiliPlus embeds AVBox in the same process as Flutter. The upstream
        // global AutoSize setup rewrites shared DisplayMetrics and shrinks Flutter,
        // the host glass navigation, and live playback after AVBox is initialized.
        // Compose already handles the embedded root responsively, so do not mutate
        // process-wide density here.
        Probe.trace("boot:quickJSLoader") { loadQuickJs() }
        bootMark("quickJSLoader")
        Probe.trace("boot:vodImages") { VodImages.init() }
        bootMark("vodImages")
        Thread({
            FileUtils.ensureNoMediaMarker()
            Probe.trace("boot:cleanPlayerCache") { FileUtils.cleanPlayerCache() }
        }, "exo-cache-boot").start()
        bootMark("onCreateDone")
    }

    private fun loadQuickJs() {
        val previous = StrictMode.allowThreadDiskReads()
        try {
            QuickJSLoader.init()
        } finally {
            StrictMode.setThreadPolicy(previous)
        }
    }

    private fun initParams() {
        KV.put(KVKeys.PLAYER_IS_LIVE, false)
        if (!KV.contains(KVKeys.PLAY_TYPE)) {
            KV.put(KVKeys.PLAY_TYPE, 2)
        } else {
            val playType = KV.get(KVKeys.PLAY_TYPE, 2)
            if (playType == 0 || playType == 1 || (playType > 2 && playType != 13)) {
                KV.put(KVKeys.PLAY_TYPE, 2)
            }
        }
    }

    private fun installStrictMode() {
        if (!BuildConfig.DEBUG) return
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) return
        StrictMode.setThreadPolicy(
            StrictMode.ThreadPolicy.Builder()
                .detectDiskReads()
                .detectDiskWrites()
                .detectNetwork()
                .penaltyLog()
                .build()
        )
        StrictMode.setVmPolicy(
            StrictMode.VmPolicy.Builder()
                .detectLeakedSqlLiteObjects()
                .detectLeakedClosableObjects()
                .detectActivityLeaks()
                .detectFileUriExposure()
                .penaltyLog()
                .build()
        )
    }

    fun shutdown() {
        JsLoader.destroy()
    }

    fun getCurrentActivity(): Activity {
        return ActivityStack.getInstance().currentActivity()
    }


    companion object {
        @Volatile
        private var instance: App? = null

        var dashData: String? = null

        @JvmStatic
        fun getInstance(): App? {
            return instance
        }

        @JvmStatic
        fun initialize(context: Context): App {
            instance?.let { return it }
            return synchronized(this) {
                instance ?: App(context).also { app ->
                    Probe.step("kvInit") { KV.init(app) }
                    instance = app
                    app.initialize()
                }
            }
        }
    }
}
