package kr.co.taoist.gwansang

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        installCrashLogger()
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "append" -> {
                        val line = call.argument<String>("line") ?: ""
                        try {
                            AuraLogStore.append(applicationContext, line)
                            result.success(AuraLogStore.pathHint())
                        } catch (e: Exception) {
                            result.error("log_write", e.message, null)
                        }
                    }
                    "path" -> result.success(AuraLogStore.pathHint())
                    else -> result.notImplemented()
                }
            }
    }

    private fun installCrashLogger() {
        val previous = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, throwable ->
            try {
                AuraLogStore.append(
                    applicationContext,
                    "${System.currentTimeMillis()} [FATAL] thread=${thread.name}\n" +
                        throwable.stackTraceToString() + "\n",
                )
            } catch (_: Throwable) {
            }
            previous?.uncaughtException(thread, throwable)
        }
    }

    companion object {
        private const val CHANNEL = "kr.co.taoist.gwansang/log"
    }
}
