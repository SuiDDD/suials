package com.k.als

import android.view.WindowManager
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
// 注意:删除了 android.system.Os.setenv 和 android.content.Intent 的导入,因为它们已不再使用

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        
        window.setFlags(WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS, WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS)
        window.decorView.systemUiVisibility = android.view.View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN or android.view.View.SYSTEM_UI_FLAG_LAYOUT_STABLE
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger, "android"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                // 彻底删除:launchSignal9Page 的逻辑
                "getNativeLibraryPath" -> {
                    // 保留:获取原生库路径的逻辑
                    result.success(getApplicationInfo().nativeLibraryDir)
                }

                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
