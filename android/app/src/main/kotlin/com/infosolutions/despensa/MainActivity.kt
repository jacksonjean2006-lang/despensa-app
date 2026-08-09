package com.infosolutions.despensa

import android.content.Intent
import android.content.pm.ShortcutInfo
import android.content.pm.ShortcutManager
import android.graphics.drawable.Icon
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CANAL = "despensa/atalho"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CANAL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "fixarNaTelaInicial" -> result.success(fixarNaTelaInicial())
                    else -> result.notImplemented()
                }
            }
    }

    // Pede pro Android fixar um atalho do app na tela inicial. A partir do
    // Android 8 (API 26) isso SEMPRE exige confirmação do usuário numa
    // caixinha do próprio sistema - não existe jeito de fazer isso
    // silenciosamente (é uma restrição de segurança do Android, não uma
    // limitação do app). Em versões mais antigas ou em launchers que não
    // suportam, simplesmente não faz nada e retorna false.
    private fun fixarNaTelaInicial(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false

        val shortcutManager = getSystemService(ShortcutManager::class.java) ?: return false
        if (!shortcutManager.isRequestPinShortcutSupported) return false

        val intentAbrir = Intent(this, MainActivity::class.java).apply {
            action = Intent.ACTION_MAIN
            addCategory(Intent.CATEGORY_LAUNCHER)
        }

        val shortcut = ShortcutInfo.Builder(this, "despensa_atalho_principal")
            .setShortLabel("Despensa")
            .setLongLabel("Minha Despensa")
            .setIcon(Icon.createWithResource(this, R.mipmap.ic_launcher))
            .setIntent(intentAbrir)
            .build()

        return shortcutManager.requestPinShortcut(shortcut, null)
    }
}
