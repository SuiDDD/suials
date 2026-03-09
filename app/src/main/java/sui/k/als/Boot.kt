package sui.k.als
import android.provider.OpenableColumns
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.*
import androidx.compose.foundation.gestures.detectVerticalDragGestures
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.*
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.*
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.*
import kotlinx.coroutines.*
import java.io.File
@Composable
fun BootScreen(onFinished: () -> Unit) {
    val font = LocalAppFont.current
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    var res by remember { mutableStateOf("") }
    var sub by remember { mutableStateOf(false) }
    var idx by remember { mutableIntStateOf(0) }
    var info by remember { mutableStateOf("") }
    val items = if (!sub) listOf("Setup Linux", "Exit") else listOf("Import RootFS", "Back")
    val picker = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { u ->
        u?.let {
            scope.launch(Dispatchers.IO) {
                val name = ctx.contentResolver.query(it, null, null, null, null)?.use { c ->
                    c.moveToFirst()
                    c.getString(c.getColumnIndexOrThrow(OpenableColumns.DISPLAY_NAME))
                } ?: "file"
                val f = File(ctx.cacheDir, name).apply { ctx.contentResolver.openInputStream(it)?.use { i -> outputStream().use { o -> i.copyTo(o) } } }
                res += ProcessBuilder("su", "-c", "file -b \"${f.absolutePath}\"").start().inputStream.bufferedReader().readText() + "\n"
                f.delete()
            }
        }
    }
    LaunchedEffect(Unit) {
        withContext(Dispatchers.IO) {
            File(ctx.cacheDir, "busybox").apply { if (!exists()) ctx.assets.open("busybox").use { it.copyTo(outputStream()) }; setExecutable(true) }
            info = ProcessBuilder("su", "-c", "echo \"$(uname -m)\n$(getenforce)\n$(df /data | awk 'NR==2 {printf \"%.2f GB\", $4/1024/1024}') Free\n$(cat /sys/class/power_supply/battery/capacity)% [$(cat /sys/class/power_supply/battery/status)]\n$(uname -r)\"").start().inputStream.bufferedReader().readText()
        }
    }
    Column(Modifier.fillMaxSize().background(Color.Black).pointerInput(sub) {
        detectVerticalDragGestures { _, d -> if (d > 15f) idx = (idx - 1).coerceAtLeast(0) else if (d < -15f) idx = (idx + 1).coerceAtMost(items.size - 1) }
    }.clickable(interactionSource = remember { MutableInteractionSource() }, indication = null) {
        if (!sub) when (idx) { 0 -> { sub = true; idx = 0 }; 1 -> onFinished() }
        else when (idx) { 0 -> picker.launch("*/*"); 1 -> { sub = false; idx = 0 } }
    }) {
        Box(Modifier.weight(0.236f).fillMaxWidth(), Alignment.BottomCenter) {
            Text(info, Modifier.align(Alignment.TopStart).padding(8.dp), Color.Green, 9.sp, fontFamily = font, lineHeight = 11.sp)
            Text("AndLinSys", color = Color.White, fontSize = 27.sp, fontFamily = font)
        }
        Column(Modifier.weight(0.618f).fillMaxWidth()) {
            Spacer(Modifier.height(10.dp))
            items.forEachIndexed { i, t ->
                Box(Modifier.fillMaxWidth().height(20.dp).background(if (idx == i) Color(0xFF222222) else Color.Transparent), Alignment.Center) {
                    Text(if (idx == i) "> $t <" else t, color = Color.White, fontSize = 12.sp, fontFamily = font)
                }
            }
            if (sub && res.isNotEmpty()) Box(Modifier.fillMaxSize().padding(12.dp).background(Color(0xFF0A0A0A)).border(0.5.dp, Color.Gray).padding(6.dp)) {
                Text(res, Modifier.verticalScroll(rememberScrollState()), Color.Green, 9.sp, fontFamily = font)
            }
        }
        Column(Modifier.weight(0.146f).fillMaxWidth(), Arrangement.Center, Alignment.CenterHorizontally) {
            Text("Powered by", color = Color.Gray, fontSize = 9.sp, fontFamily = font)
            Text("Chroot", color = Color.White, fontSize = 15.sp, fontFamily = font)
        }
    }
}
