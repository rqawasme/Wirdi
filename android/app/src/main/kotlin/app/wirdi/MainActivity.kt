package app.wirdi

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * The Android half of the self-updater, and the only reason this class has a
 * body at all — it was the stock `class MainActivity : FlutterActivity()`.
 *
 * Everything here comes out together with the INTERNET,
 * REQUEST_INSTALL_PACKAGES and FileProvider blocks in AndroidManifest.xml when
 * this app is prepared for Play. See docs/SELF_UPDATE.md.
 */
class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler(::onMethodCall)
    }

    private fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "canInstall" -> result.success(canInstall())
            "requestInstallPermission" -> requestInstallPermission(result)
            "install" -> install(call.argument<String>("path"), result)
            else -> result.notImplemented()
        }
    }

    /**
     * Whether Android will let this app install a package right now.
     *
     * Below API 26 this is governed by one global "Unknown sources" toggle that
     * an app can neither read nor request, so the answer is yes and the install
     * intent then either works or does not. From 26 it is a per-app appop —
     * note that this is *not* a runtime permission, so requestPermissions()
     * does nothing with it and there is no dialog anyone can show.
     */
    private fun canInstall(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
            packageManager.canRequestPackageInstalls()

    /**
     * Opens the system settings page that grants it.
     *
     * A round trip to Settings, not a permission dialog. The Dart side does not
     * wait for an answer: that screen returns RESULT_CANCELED whatever the user
     * did, and the app may well be killed while it is in the foreground. The
     * banner asks the user to come back and tap again instead, which needs no
     * result to be delivered and survives the process dying.
     */
    private fun requestInstallPermission(result: MethodChannel.Result) {
        if (canInstall() || Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            // Nothing to ask for. ACTION_MANAGE_UNKNOWN_APP_SOURCES does not
            // exist before API 26 and the global toggle it replaced is not
            // reachable per app.
            result.success(null)
            return
        }
        try {
            startActivity(
                Intent(
                    Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                    Uri.parse("package:$packageName"),
                ),
            )
        } catch (e: ActivityNotFoundException) {
            // A device with no such settings screen. Nothing to do about it,
            // and not worth failing the call over: the install attempt that
            // follows will report the real problem.
        }
        result.success(null)
    }

    private fun install(path: String?, result: MethodChannel.Result) {
        if (path == null) {
            result.error("no_path", "install needs a path", null)
            return
        }
        val apk = File(path)
        if (!apk.isFile) {
            result.error("missing_apk", "no file at $path", null)
            return
        }

        val uri = try {
            // Since API 24 a file:// URI in an Intent throws
            // FileUriExposedException. This throws IllegalArgumentException for
            // a file outside the paths res/xml/file_paths.xml declares, which
            // is a mistake worth naming rather than crashing on.
            FileProvider.getUriForFile(this, "$packageName.updates", apk)
        } catch (e: IllegalArgumentException) {
            result.error(
                "not_shareable",
                "${apk.path} is outside the FileProvider paths",
                null,
            )
            return
        }

        // ACTION_VIEW rather than ACTION_INSTALL_PACKAGE, which is deprecated
        // since API 29. No resolveActivity() check first: package visibility
        // filtering on API 30+ returns null for the system installer without a
        // <queries> entry naming it, so trying it is the honest test.
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        try {
            startActivity(intent)
            result.success(null)
        } catch (e: ActivityNotFoundException) {
            result.error("no_installer", "no activity handles a package install", null)
        }
    }

    private companion object {
        /**
         * Must match UpdateClient._channel in lib/data/update_client.dart.
         * test/app/update_manifest_test.dart is what keeps the two honest.
         */
        const val CHANNEL = "app.wirdi/installer"
    }
}
