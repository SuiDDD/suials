package sui.k.als.term

import android.view.HapticFeedbackConstants
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.horizontalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.RectangleShape
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlin.math.roundToInt

object PanelKeyState {
    var isCtrlActive by mutableStateOf(false)
    var isShiftActive by mutableStateOf(false)
    var isAltActive by mutableStateOf(false)
    var isCapsActive by mutableStateOf(false)
    var isFullKeyboardVisible by mutableStateOf(false)
    var keyboardOffset by mutableStateOf(IntOffset(0, 0))

    fun consumeCtrl(): Boolean = isCtrlActive
    fun consumeShift(): Boolean = isShiftActive
    fun consumeAlt(): Boolean = isAltActive
}

private val keyCodes = mapOf("Tab" to "\u0009", "Esc" to "\u001b", "Enter" to "\r", "Back" to "\u007f", " " to " ", "↑" to "\u001b[A", "↓" to "\u001b[B", "←" to "\u001b[D", "→" to "\u001b[C", "Home" to "\u001b[1~", "End" to "\u001b[4~", "Del" to "\u001b[3~", "F1" to "\u001bOP", "F2" to "\u001bOQ", "F3" to "\u001bOR", "F4" to "\u001bOS", "F5" to "\u001b[15~", "F6" to "\u001b[17~", "F7" to "\u001b[18~", "F8" to "\u001b[19~", "F9" to "\u001b[20~", "F10" to "\u001b[21~", "F11" to "\u001b[23~", "F12" to "\u001b[24~")
private val symbolMap = mapOf("`" to "~", "1" to "!", "2" to "@", "3" to "#", "4" to "$", "5" to "%", "6" to "^", "7" to "&", "8" to "*", "9" to "(", "0" to ")", "-" to "_", "=" to "+", "[" to "{", "]" to "}", "\\" to "|", ";" to ":", "'" to "\"", "," to "<", "." to ">", "/" to "?")

@Composable
fun PanelKeys() {
    val configuration = LocalConfiguration.current
    val screenHeight = configuration.screenHeightDp.dp
    val isLandscape = configuration.orientation == android.content.res.Configuration.ORIENTATION_LANDSCAPE
    val totalHeight = if (isLandscape) screenHeight / 2 else screenHeight / 3

    BackHandler(PanelKeyState.isFullKeyboardVisible) { PanelKeyState.isFullKeyboardVisible = false }

    Box(Modifier.fillMaxSize()) {
        Column(
            Modifier
                .offset { PanelKeyState.keyboardOffset }
                .fillMaxWidth(if (isLandscape && PanelKeyState.isFullKeyboardVisible) 0.6f else 1f)
                .height(if (!PanelKeyState.isFullKeyboardVisible) 36.dp else totalHeight)
                .background(Color.Black)
                .align(Alignment.BottomCenter)
        ) {
            if (!PanelKeyState.isFullKeyboardVisible) {
                Row(Modifier.fillMaxSize().horizontalScroll(rememberScrollState())) {
                    val topKeys = listOf("Ctrl", "Alt", "Shift", "Caps", "Esc", "Tab", "F1", "F2", "F3", "F4", "F5", "F6")
                    topKeys.forEach { KeyBase(it, width = 45.dp, weight = null, isModifier = it in listOf("Ctrl", "Alt", "Shift", "Caps")) }
                    KeyBase("", width = 45.dp, weight = null, isControl = true)
                    val tailKeys = listOf("F7", "F8", "F9", "F10", "F11", "F12", "Home", "End", "Del", "Back", "Enter", "↑", "↓", "←", "→")
                    tailKeys.forEach { KeyBase(it, width = 45.dp, weight = null) }
                }
            } else {
                val layout = listOf(
                    listOf("Esc", "F1", "F2", "F3", "F4", "F5", "F6", "", "F7", "F8", "F9", "F10", "F11", "F12", "Del"),
                    listOf("`", "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "=", "Back"),
                    listOf("Tab", "Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P", "[", "]", "\\"),
                    listOf("Caps", "A", "S", "D", "F", "G", "H", "J", "K", "L", ";", "'", "Enter"),
                    listOf("Shift", "Z", "X", "C", "V", "B", "N", "M", ",", ".", "/", "↑"),
                    listOf("Ctrl", "Alt", "Home", " ", "End", "←", "↓", "→")
                )
                layout.forEach { row ->
                    Row(Modifier.fillMaxWidth().weight(1f)) {
                        row.forEachIndexed { index, label ->
                            val keyWeight = when { label == " " -> 2.4f; label == "→" -> 1.2f; index == 0 || index == row.lastIndex -> 1.5f; else -> 0.9f }
                            KeyBase(label, weight = keyWeight, width = null, isModifier = label in listOf("Ctrl", "Shift", "Alt", "Caps"), isControl = label == "")
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun RowScope.KeyBase(label: String, width: androidx.compose.ui.unit.Dp?, weight: Float?, isModifier: Boolean = false, isControl: Boolean = false) {
    var isPressed by remember { mutableStateOf(false) }
    val coroutineScope = rememberCoroutineScope()
    var repeatJob by remember { mutableStateOf<Job?>(null) }
    val view = LocalView.current
    val displayText = when {
        isControl || isModifier || label.length > 1 || (!label[0].isLetter() && !symbolMap.containsKey(label)) -> label
        PanelKeyState.isShiftActive -> symbolMap[label] ?: label.uppercase()
        PanelKeyState.isCapsActive && label[0].isLetter() -> label.uppercase()
        else -> label
    }
    val isActive = when(label) { "Ctrl" -> PanelKeyState.isCtrlActive; "Shift" -> PanelKeyState.isShiftActive; "Alt" -> PanelKeyState.isAltActive; "Caps" -> PanelKeyState.isCapsActive; else -> false }
    val baseModifier = if (weight != null) Modifier.weight(weight) else if (width != null) Modifier.width(width) else Modifier

    Box(
        modifier = baseModifier
            .fillMaxHeight()
            .pointerInput(label) {
                if (isControl) {
                    detectDragGestures { change, dragAmount ->
                        change.consume()
                        PanelKeyState.keyboardOffset = IntOffset(
                            (PanelKeyState.keyboardOffset.x + dragAmount.x).roundToInt(),
                            (PanelKeyState.keyboardOffset.y + dragAmount.y).roundToInt()
                        )
                    }
                }
            }
            .pointerInput(label) {
                detectTapGestures(
                    onTap = { if (isControl) PanelKeyState.isFullKeyboardVisible = !PanelKeyState.isFullKeyboardVisible },
                    onPress = {
                        if (isControl) return@detectTapGestures
                        isPressed = true
                        view.performHapticFeedback(HapticFeedbackConstants.KEYBOARD_TAP)
                        val startTime = System.currentTimeMillis()
                        repeatJob = coroutineScope.launch {
                            if (isModifier) {
                                when(label) {
                                    "Ctrl" -> PanelKeyState.isCtrlActive = !PanelKeyState.isCtrlActive
                                    "Shift" -> PanelKeyState.isShiftActive = !PanelKeyState.isShiftActive
                                    "Alt" -> PanelKeyState.isAltActive = !PanelKeyState.isAltActive
                                    "Caps" -> PanelKeyState.isCapsActive = !PanelKeyState.isCapsActive
                                }
                            } else {
                                while (true) {
                                    processKey(label)
                                    val elapsedTime = System.currentTimeMillis() - startTime
                                    delay(when { elapsedTime < 300 -> 300L; elapsedTime < 3000 -> 30L; else -> 9L })
                                }
                            }
                        }
                        try { awaitRelease() } catch (_: Exception) { } finally { isPressed = false; repeatJob?.cancel() }
                    }
                )
            }
            .padding(1.dp)
            .background(if (isPressed || isActive) Color(0xFF444444) else Color(0xFF1A1A1A), RectangleShape),
        contentAlignment = Alignment.Center
    ) {
        Text(displayText, color = Color.White, fontSize = 9.sp, softWrap = false)
    }
}

private fun processKey(label: String) {
    val code = keyCodes[label]
    if (code != null) transmit(if (PanelKeyState.isAltActive && label != "Alt") "\u001b$code" else code)
    else {
        val useUpper = PanelKeyState.isShiftActive || (PanelKeyState.isCapsActive && label.length == 1 && label[0].isLetter())
        var text = if (PanelKeyState.isShiftActive) (symbolMap[label] ?: label.uppercase()) else if (useUpper) label.uppercase() else label.lowercase()
        if (PanelKeyState.isCtrlActive && text.length == 1) { val upper = text.uppercase()[0]; if (upper in '@'..'_') text = (upper.code - '@'.code).toChar().toString() }
        transmit(if (PanelKeyState.isAltActive) "\u001b$text" else text)
    }
}

private fun transmit(data: String) = sessionInstance?.write(data)