package com.ningso.aps.ui

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Typography
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp

object Signal {
    val Background = Color(0xFF090D0B)
    val Surface = Color(0xFF141A16)
    val Raised = Color(0xFF1C241E)
    val Border = Color(0xFF2B362E)
    val Text = Color(0xFFEFF5ED)
    val Secondary = Color(0xFFA0AFA2)
    val Muted = Color(0xFF7D8D7F)
    val Accent = Color(0xFFC1F76B)
    val OnAccent = Color(0xFF17220B)
    val Mint = Color(0xFF7ADECF)
    val Warning = Color(0xFFEDBD79)
    val Error = Color(0xFFFF978A)
    val Mono = FontFamily.Monospace
}

@Composable
fun SignalTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = darkColorScheme(
            primary = Signal.Accent, onPrimary = Signal.OnAccent,
            background = Signal.Background, onBackground = Signal.Text,
            surface = Signal.Surface, onSurface = Signal.Text,
            surfaceVariant = Signal.Raised, onSurfaceVariant = Signal.Secondary,
            outline = Signal.Border, error = Signal.Error, onError = Signal.Background,
            secondary = Signal.Mint,
        ),
        typography = Typography(
            headlineLarge = TextStyle(fontSize = 29.sp, fontWeight = FontWeight.Normal, lineHeight = 38.sp),
            titleMedium = TextStyle(fontSize = 15.sp, fontWeight = FontWeight.Medium, lineHeight = 22.sp),
            bodyLarge = TextStyle(fontSize = 14.sp, lineHeight = 22.sp),
            bodyMedium = TextStyle(fontSize = 12.sp, lineHeight = 19.sp),
            labelMedium = TextStyle(fontSize = 11.sp, fontWeight = FontWeight.Medium),
        ),
        content = content,
    )
}
