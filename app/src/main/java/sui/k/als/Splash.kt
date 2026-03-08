package sui.k.als

import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.*
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.text.*
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.*

@Composable
fun SplashScreen(onTimeout: () -> Unit) {
    val font = LocalAppFont.current
    val logLines = remember { mutableStateListOf<AnnotatedString>() }
    val listState = rememberLazyListState()
    var isAutoScrollEnabled by remember { mutableStateOf(true) }
    val clipboardManager = LocalClipboardManager.current

    LaunchedEffect(Unit) {
        val scope = this
        withContext(Dispatchers.IO) {
            runCatching {
                ProcessBuilder("su", "-c", "logcat --uid ${android.os.Process.myUid()} -v tag").start().inputStream.bufferedReader().useLines { lines ->
                    for (line in lines) if (line.isNotBlank()) {
                        val styledLine = buildAnnotatedString {
                            withStyle(SpanStyle(when (line.getOrNull(0)) {
                                'V' -> Color(0xFFD6D6D6)
                                'D' -> Color(0xFFCFE7FF)
                                'I' -> Color(0xFFE9F5E6)
                                'W' -> Color(0xFFF5EAC1)
                                'E' -> Color(0xFFCF5B56)
                                'A' -> Color(0xFF7F0000)
                                else -> Color.White
                            })) { append(line) }
                        }
                        withContext(Dispatchers.Main) {
                            if (logLines.isEmpty()) scope.launch { delay(3000); onTimeout() }
                            if (logLines.size > 2999) logLines.removeAt(0)
                            logLines.add(styledLine)
                            if (isAutoScrollEnabled) listState.scrollToItem(logLines.size - 1)
                        }
                    }
                }
            }
        }
    }

    Column(Modifier.fillMaxSize().background(Color.Black)) {
        Box(Modifier.weight(0.236f).fillMaxWidth(), Alignment.BottomCenter) {
            Text("AndLinSys", color = Color.White, fontSize = 27.sp, fontFamily = font)
        }
        Box(Modifier.weight(0.618f).fillMaxWidth().pointerInput(Unit) {
            detectTapGestures(onPress = { isAutoScrollEnabled = false }, onDoubleTap = { clipboardManager.setText(AnnotatedString(logLines.joinToString("\n"))) })
        }) {
            LazyColumn(Modifier.fillMaxSize(), listState) {
                items(logLines) { Text(it, fontSize = 10.sp, fontFamily = font) }
            }
        }
        Column(Modifier.weight(0.146f).fillMaxWidth(), Arrangement.Center, Alignment.CenterHorizontally) {
            Text("Powered by", color = Color.Gray, fontSize = 9.sp, fontFamily = font)
            Text("Chroot", color = Color.White, fontSize = 15.sp, fontFamily = font)
        }
    }
}