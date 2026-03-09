package sui.k.als

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.graphics.Typeface
import android.view.KeyEvent
import android.view.MotionEvent
import android.view.inputmethod.InputMethodManager
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.viewinterop.AndroidView
import com.termux.terminal.TerminalSession
import com.termux.terminal.TerminalSessionClient
import com.termux.view.TerminalView
import com.termux.view.TerminalViewClient
import kotlinx.coroutines.delay
import java.io.File

private var sessionInstance: TerminalSession? = null

fun termRun(command: String) {
    sessionInstance?.write(command + "\n")
}

open class TermSessionStub : TerminalSessionClient {
    override fun onTextChanged(s: TerminalSession) {}
    override fun onTitleChanged(s: TerminalSession) {}
    override fun onSessionFinished(s: TerminalSession) {}
    override fun onCopyTextToClipboard(s: TerminalSession, t: String) {}
    override fun onPasteTextFromClipboard(s: TerminalSession) {}
    override fun onBell(s: TerminalSession) {}
    override fun onColorsChanged(s: TerminalSession) {}
    override fun onTerminalCursorStateChange(b: Boolean) {}
    override fun getTerminalCursorStyle() = 0
    override fun logError(t: String, m: String) {}
    override fun logWarn(t: String, m: String) {}
    override fun logInfo(t: String, m: String) {}
    override fun logDebug(t: String, m: String) {}
    override fun logVerbose(t: String, m: String) {}
    override fun logStackTrace(t: String, e: Exception) {}
    override fun logStackTraceWithMessage(t: String, m: String, e: Exception) {}
}

open class TermViewStub : TerminalViewClient {
    override fun onScale(f: Float) = 1f
    override fun onSingleTapUp(e: MotionEvent) {}
    override fun shouldBackButtonBeMappedToEscape() = false
    override fun shouldEnforceCharBasedInput() = false
    override fun shouldUseCtrlSpaceWorkaround() = false
    override fun isTerminalViewSelected() = true
    override fun copyModeChanged(b: Boolean) {}
    override fun onKeyDown(i: Int, e: KeyEvent, s: TerminalSession) = false
    override fun onKeyUp(i: Int, e: KeyEvent) = false
    override fun onLongPress(e: MotionEvent) = false
    override fun readControlKey() = false
    override fun readAltKey() = false
    override fun readShiftKey() = false
    override fun readFnKey() = false
    override fun onCodePoint(i: Int, b: Boolean, s: TerminalSession) = false
    override fun onEmulatorSet() {}
    override fun logError(t: String, m: String) {}
    override fun logWarn(t: String, m: String) {}
    override fun logInfo(t: String, m: String) {}
    override fun logDebug(t: String, m: String) {}
    override fun logVerbose(t: String, m: String) {}
    override fun logStackTrace(t: String, e: Exception) {}
    override fun logStackTraceWithMessage(t: String, m: String, e: Exception) {}
}

@Composable
fun TerminalScreen() {
    val context = LocalContext.current
    val terminalView = remember { TerminalView(context, null) }
    val currentFont = LocalAppFont.current

    val session = remember {
        val dir = context.filesDir.absolutePath.also { File(it).mkdirs() }
        TerminalSession(
            "/system/bin/sh",
            dir,
            arrayOf("-i"),
            arrayOf("TERM=xterm-256color", "HOME=$dir"),
            3000,
            object : TermSessionStub() {
                override fun onTextChanged(s: TerminalSession) = terminalView.onScreenUpdated()
                override fun onCopyTextToClipboard(s: TerminalSession, t: String) {
                    (context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager).setPrimaryClip(
                        ClipData.newPlainText("T", t)
                    )
                }

                override fun onPasteTextFromClipboard(s: TerminalSession) {
                    (context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager).primaryClip?.getItemAt(
                        0
                    )?.let { s.write(it.coerceToText(context).toString()) }
                }

                override fun getTerminalCursorStyle() = 2
            })
    }

    DisposableEffect(session) {
        sessionInstance = session
        onDispose {
            if (sessionInstance == session) sessionInstance = null
        }
    }

    val viewClient = remember {
        object : TermViewStub() {
            private var size = 18f
            override fun onScale(f: Float) = (size * f).coerceAtLeast(1f)
                .also { size = it; terminalView.setTextSize(it.toInt()) }.let { 1f }

            override fun onSingleTapUp(e: MotionEvent) {
                terminalView.requestFocus()
                val imm =
                    context.getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager
                imm.showSoftInput(terminalView, InputMethodManager.SHOW_IMPLICIT)
            }

            override fun shouldEnforceCharBasedInput() = true
        }
    }

    LaunchedEffect(session) {
        terminalView.requestFocus()
        terminalView.setTerminalCursorBlinkerRate(300)
        terminalView.setTerminalCursorBlinkerState(true, true)

        termRun("su")
        termRun("cd /data/als && clear && ./busybox")
    }

    DisposableEffect(currentFont) {
        terminalView.apply {
            setTextSize(18)
            setTypeface(
                try {
                    Typeface.createFromAsset(context.assets, "fonts/GoogleSansCode.ttf")
                } catch (_: Exception) {
                    Typeface.DEFAULT
                }
            )
            setBackgroundColor(Color.Black.toArgb())
            setTerminalViewClient(viewClient)
            attachSession(session)
            isFocusable = true
            isFocusableInTouchMode = true
            isClickable = true
        }
        onDispose { session.finishIfRunning() }
    }

    AndroidView(factory = { terminalView }, modifier = Modifier.fillMaxSize(), update = {
        it.requestFocus()
        it.setTerminalCursorBlinkerState(true, false)
    })
}
