package sui.k.als

import android.graphics.Typeface
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import java.io.File

val LocalAppFont = staticCompositionLocalOf<FontFamily> { FontFamily.Monospace }

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        WindowCompat.getInsetsController(window, window.decorView).apply {
            systemBarsBehavior = WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
            hide(WindowInsetsCompat.Type.systemBars())
        }
        setContent {
            val context = LocalContext.current
            val customFont = remember {
                try {
                    FontFamily(
                        Typeface.createFromAsset(
                            context.assets, "fonts/RobotoMono-Regular.ttf"
                        )
                    )
                } catch (e: Exception) {
                    FontFamily.Monospace
                }
            }
            var currentScreen by rememberSaveable { mutableStateOf("splash") }
            CompositionLocalProvider(LocalAppFont provides customFont) {
                when (currentScreen) {
                    "splash" -> SplashScreen {
                        currentScreen = if (File("/data/als/dev").exists()) "terminal" else "boot"
                    }
                    "boot" -> BootScreen { currentScreen = "terminal" }
                    else -> TerminalScreen()
                }
            }
        }
    }
}
