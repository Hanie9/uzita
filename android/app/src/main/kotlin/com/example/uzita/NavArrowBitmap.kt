package com.example.uzita

import android.graphics.Bitmap
import android.graphics.BlurMaskFilter
import android.graphics.Canvas
import android.graphics.CornerPathEffect
import android.graphics.LinearGradient
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.Path
import android.graphics.Shader

/// Neshan-style navigation puck: a rounded blue arrowhead with a white border
/// and a soft drop shadow, matching the Neshan Navigator driver marker.
internal object NavArrowBitmap {
    private const val SIZE_PX = 120

    private var baseArrow: Bitmap? = null

    fun create(bearingDegrees: Float): Bitmap {
        val base = baseArrow ?: drawArrow().also { baseArrow = it }
        if (bearingDegrees == 0f) return base

        val matrix = Matrix()
        matrix.postRotate(bearingDegrees, base.width / 2f, base.height / 2f)
        return Bitmap.createBitmap(base, 0, 0, base.width, base.height, matrix, true)
    }

    private fun drawArrow(): Bitmap {
        val size = SIZE_PX
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val cx = size / 2f
        val w = size.toFloat()
        val h = size.toFloat()

        // Soft drop shadow beneath the arrow.
        canvas.drawOval(
            cx - w * 0.24f,
            h * 0.80f,
            cx + w * 0.24f,
            h * 0.95f,
            Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = 0x40000000
                maskFilter = BlurMaskFilter(8f, BlurMaskFilter.Blur.NORMAL)
            },
        )

        // Rounded triangle pointing up (Neshan-style puck).
        val body = Path().apply {
            moveTo(cx, h * 0.14f)
            lineTo(cx + w * 0.28f, h * 0.76f)
            lineTo(cx - w * 0.28f, h * 0.76f)
            close()
        }
        val rounded = CornerPathEffect(16f)

        canvas.drawPath(
            body,
            Paint(Paint.ANTI_ALIAS_FLAG).apply {
                shader = LinearGradient(
                    cx, h * 0.12f, cx, h * 0.78f,
                    intArrayOf(0xFF5AB0F7.toInt(), 0xFF2F86EE.toInt(), 0xFF1E68D8.toInt()),
                    floatArrayOf(0f, 0.55f, 1f),
                    Shader.TileMode.CLAMP,
                )
                style = Paint.Style.FILL
                pathEffect = rounded
            },
        )

        canvas.drawPath(
            body,
            Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = 0xFFFFFFFF.toInt()
                style = Paint.Style.STROKE
                strokeWidth = 6f
                strokeJoin = Paint.Join.ROUND
                pathEffect = rounded
            },
        )

        return bitmap
    }
}
