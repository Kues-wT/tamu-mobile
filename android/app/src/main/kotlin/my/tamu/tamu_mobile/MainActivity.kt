package my.tamu.tamu_mobile

import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // FR4: tells the app whether Google ARCore is installed, so it can
        // choose floor AR (Scene Viewer) or the TAMU-card marker AR.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "tamu/ar")
            .setMethodCallHandler { call, result ->
                if (call.method == "hasArCore") {
                    result.success(isInstalled("com.google.ar.core"))
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun isInstalled(pkg: String): Boolean = try {
        packageManager.getPackageInfo(pkg, 0)
        true
    } catch (e: PackageManager.NameNotFoundException) {
        false
    }
}
