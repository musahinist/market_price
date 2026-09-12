package com.mshn.market_price

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Haber bağlantılarını tarayıcıda açar.
 *
 * Bunun için eklenti yerine küçük bir kanal kullanıyoruz; uygulamanın başka
 * yerli koda ihtiyacı yok.
 */
class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method != "open") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }

                val url = call.argument<String>("url")
                if (url.isNullOrBlank()) {
                    result.error("no_url", "Bağlantı boş.", null)
                    return@setMethodCallHandler
                }

                try {
                    startActivity(
                        Intent(Intent.ACTION_VIEW, Uri.parse(url))
                            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    )
                    result.success(true)
                } catch (e: ActivityNotFoundException) {
                    result.error("no_browser", "Tarayıcı bulunamadı.", null)
                }
            }
    }

    private companion object {
        const val CHANNEL = "market_price/url"
    }
}
