package sui.k.als

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.text.font.*
import androidx.core.view.*
import sui.k.als.boot.BootScreen
import sui.k.als.boot.Splash
import sui.k.als.term.TerminalScreen
import java.io.File

val localAppFont = staticCompositionLocalOf<FontFamily> { FontFamily.Default }

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        WindowCompat.getInsetsController(window, window.decorView).apply {
            systemBarsBehavior = WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
            hide(WindowInsetsCompat.Type.systemBars())
        }
        setContent {
            var switch by rememberSaveable { mutableStateOf("splash") }
            CompositionLocalProvider(localAppFont provides remember {
                runCatching { FontFamily(Font("fonts/GoogleSansFlex.ttf", assets)) }.getOrDefault(FontFamily.Default)
            }) {
                when (switch) {
                    "splash" -> Splash(onTimeout = {
                        switch = if (File("/data/als/dev").exists()) "terminal" else "boot"
                    })
                    "boot" -> BootScreen { switch = "terminal" }
                    else -> TerminalScreen()
                }
            }
        }
    }
}
