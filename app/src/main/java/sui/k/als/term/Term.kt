package sui.k.als.term
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.graphics.Typeface
import android.os.Process
import android.view.Choreographer
import android.view.KeyEvent
import android.view.MotionEvent
import android.view.View
import android.view.inputmethod.InputMethodManager
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.imePadding
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.viewinterop.AndroidView
import com.termux.terminal.TerminalSession
import com.termux.terminal.TerminalSessionClient
import com.termux.view.TerminalView
import com.termux.view.TerminalViewClient
import java.io.File
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean
internal var sessionInstance: TerminalSession? = null
private val ioExecutor = Executors.newFixedThreadPool(4) { r ->
    Thread(r, "als-pwr-blast").apply { priority = 10 }
}
fun termRun(command: String) {
    ioExecutor.execute { sessionInstance?.write("$command\n") }
}
@Composable
fun TerminalScreen() {
    val context = LocalContext.current
    val terminalView = remember { TerminalView(context, null) }
    val dirtyBit = remember { AtomicBoolean(false) }
    val session = remember {
        val dir = context.filesDir.absolutePath.also { File(it).mkdirs() }
        TerminalSession(
            "/system/bin/sh",
            dir,
            arrayOf("-i"),
            arrayOf("TERM=xterm-256color", "HOME=$dir", "LANG=en_US.UTF-8", "PATH=/system/bin:/system/xbin:/data/als"),
            500000,
            object : TermSessionStub() {
                override fun onTextChanged(s: TerminalSession) {
                    dirtyBit.lazySet(true)
                }
                override fun onCopyTextToClipboard(s: TerminalSession, t: String) {
                    (context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager)
                        .setPrimaryClip(ClipData.newPlainText("T", t))
                }
                override fun onPasteTextFromClipboard(s: TerminalSession?) {
                    val item = (context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager)
                        .primaryClip?.getItemAt(0)
                    item?.let { clip -> s?.let { ioExecutor.execute { it.write(clip.coerceToText(context).toString()) } } }
                }
                override fun getTerminalCursorStyle() = 2
            })
    }
    DisposableEffect(Unit) {
        val choreographer = Choreographer.getInstance()
        val frameCallback = object : Choreographer.FrameCallback {
            override fun doFrame(frameTimeNanos: Long) {
                if (dirtyBit.compareAndSet(true, false)) {
                    terminalView.invalidate()
                    terminalView.onScreenUpdated()
                }
                choreographer.postFrameCallback(this)
            }
        }
        choreographer.postFrameCallback(frameCallback)
        onDispose { choreographer.removeFrameCallback(frameCallback) }
    }
    val viewClient = remember {
        object : TermViewStub() {
            private var size = 18f
            override fun onScale(f: Float) = (size * f).coerceAtLeast(1f).also {
                size = it; terminalView.setTextSize(it.toInt())
            }.let { 1f }
            override fun onSingleTapUp(e: MotionEvent) {
                if (!PanelKeyState.isFullKeyboardVisible) {
                    terminalView.requestFocus()
                    (context.getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager)
                        .showSoftInput(terminalView, InputMethodManager.SHOW_IMPLICIT)
                }
            }
            override fun shouldEnforceCharBasedInput() = true
        }
    }
    DisposableEffect(session) {
        sessionInstance = session
        onDispose { if (sessionInstance == session) sessionInstance = null }
    }
    LaunchedEffect(session) {
        terminalView.apply { setLayerType(View.LAYER_TYPE_HARDWARE, null) }
        ioExecutor.execute {
            val pid = Process.myPid()
            termRun("su -M")
            termRun($$"renice -n -20 -p $$pid && ionice -c 1 -n 0 -p $$pid && taskset -p f0 $$pid && for tid in /proc/$$pid/task/*; do t=${tid##*/}; echo $t > /dev/stune/top-app/tasks; echo $t > /dev/cpuset/top-app/tasks; done && cd /data/als && clear && ./busybox")
        }
    }
    DisposableEffect(context) {
        terminalView.apply {
            setTextSize(18)
            setTypeface(try {
                Typeface.createFromAsset(context.assets, "fonts/GoogleSansCode.ttf")
            } catch (_: Exception) { Typeface.MONOSPACE })
            setBackgroundColor(Color.Black.toArgb())
            setTerminalViewClient(viewClient)
            attachSession(session)
            isFocusable = true
            isFocusableInTouchMode = true
            keepScreenOn = true
        }
        onDispose { ioExecutor.execute { session.finishIfRunning() } }
    }
    androidx.compose.foundation.layout.Column(modifier = Modifier.fillMaxSize().imePadding()) {
        AndroidView(
            factory = { terminalView },
            modifier = Modifier.weight(1f),
            update = {
                if (PanelKeyState.isFullKeyboardVisible) it.clearFocus() else it.requestFocus()
            }
        )
        PanelKeys()
    }
}
open class TermSessionStub : TerminalSessionClient {
    override fun onTextChanged(s: TerminalSession) {}
    override fun onTitleChanged(s: TerminalSession) {}
    override fun onSessionFinished(s: TerminalSession) {}
    override fun onCopyTextToClipboard(s: TerminalSession, t: String) {}
    override fun onPasteTextFromClipboard(s: TerminalSession?) {}
    override fun onBell(s: TerminalSession) {}
    override fun onColorsChanged(s: TerminalSession) {}
    override fun onTerminalCursorStateChange(b: Boolean) {}
    override fun getTerminalCursorStyle(): Int = 2
    override fun setTerminalShellPid(s: TerminalSession, pid: Int) {}
    override fun logError(t: String, m: String) {}
    override fun logWarn(t: String, m: String) {}
    override fun logInfo(t: String, m: String) {}
    override fun logDebug(t: String, m: String) {}
    override fun logVerbose(t: String, m: String) {}
    override fun logStackTrace(t: String, e: Exception) {}
    override fun logStackTraceWithMessage(t: String, m: String, e: Exception) {}
}
open class TermViewStub : TerminalViewClient {
    override fun readControlKey(): Boolean = PanelKeyState.consumeCtrl()
    override fun readAltKey(): Boolean = PanelKeyState.consumeAlt()
    override fun readShiftKey(): Boolean = PanelKeyState.consumeShift()
    override fun readFnKey(): Boolean = false
    override fun onKeyDown(i: Int, e: KeyEvent, s: TerminalSession): Boolean {
        if (i == KeyEvent.KEYCODE_BACK) return shouldBackButtonBeMappedToEscape()
        return false
    }
    override fun onKeyUp(i: Int, e: KeyEvent): Boolean = false
    override fun onCodePoint(i: Int, b: Boolean, s: TerminalSession): Boolean = false
    override fun onSingleTapUp(e: MotionEvent) {}
    override fun onLongPress(e: MotionEvent): Boolean = false
    override fun onScale(f: Float): Float = 1f
    override fun shouldEnforceCharBasedInput(): Boolean = true
    override fun shouldBackButtonBeMappedToEscape(): Boolean = true
    override fun shouldUseCtrlSpaceWorkaround(): Boolean = false
    override fun isTerminalViewSelected(): Boolean = true
    override fun copyModeChanged(b: Boolean) {}
    override fun onEmulatorSet() {}
    override fun logError(t: String, m: String) {}
    override fun logWarn(t: String, m: String) {}
    override fun logInfo(t: String, m: String) {}
    override fun logDebug(t: String, m: String) {}
    override fun logVerbose(t: String, m: String) {}
    override fun logStackTrace(t: String, e: Exception) {}
    override fun logStackTraceWithMessage(t: String, m: String, e: Exception) {}
}