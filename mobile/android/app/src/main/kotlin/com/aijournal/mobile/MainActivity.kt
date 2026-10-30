package com.aijournal.mobile

import android.content.ComponentName
import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// local_auth shows the system prompt from a FragmentActivity.
class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ai_diary/app_icon")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "current" -> result.success(currentIcon())
                    "set" -> {
                        val id = call.argument<String>("id")
                        if (id == null || id !in ICONS) {
                            result.error("unknown_icon", "No launcher icon $id", null)
                        } else {
                            setIcon(id)
                            result.success(null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun alias(id: String) = ComponentName(this, "$packageName.Launcher_$id")

    /** The launcher alias that is on; "default" unless one was chosen. */
    private fun currentIcon(): String = ICONS.firstOrNull { id ->
        when (packageManager.getComponentEnabledSetting(alias(id))) {
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED -> true
            // As declared in the manifest: only "default" is enabled there.
            PackageManager.COMPONENT_ENABLED_STATE_DEFAULT -> id == "default"
            else -> false
        }
    } ?: "default"

    /**
     * The home-screen icon is the enabled launcher alias (AndroidManifest):
     * [id]'s on first, then every other off, so there is always one.
     * DONT_KILL_APP keeps the app open where the launcher allows it.
     */
    private fun setIcon(id: String) {
        val flags = PackageManager.DONT_KILL_APP
        packageManager.setComponentEnabledSetting(
            alias(id), PackageManager.COMPONENT_ENABLED_STATE_ENABLED, flags)
        for (other in ICONS) {
            if (other == id) continue
            packageManager.setComponentEnabledSetting(
                alias(other), PackageManager.COMPONENT_ENABLED_STATE_DISABLED, flags)
        }
    }

    companion object {
        // Must match the activity-alias names in AndroidManifest.xml and
        // AppIcon in lib/features/profile/data/app_icon.dart.
        val ICONS = listOf(
            "default", "security", "student", "guide", "restaurant",
            "office", "nurse", "repair",
        )
    }
}
