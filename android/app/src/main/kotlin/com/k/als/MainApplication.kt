package com.k.als
import android.app.Application
import android.content.Context
import com.google.android.material.color.DynamicColors
import me.weishu.reflection.Reflection
import kotlin.concurrent.thread
class MainApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        DynamicColors.applyToActivitiesIfAvailable(this)
    }
    override fun attachBaseContext(base: Context?) {
        super.attachBaseContext(base)
        thread {
            Reflection.unseal(base)
        }
    }
}