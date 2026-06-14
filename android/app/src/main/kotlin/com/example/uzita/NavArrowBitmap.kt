package com.example.uzita

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.LinearGradient
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RadialGradient
import android.graphics.Shader

/// Compact Neshan navigation puck for map markers (bitmap is small; marker size ~30).
internal object NavArrowBitmap {
    private const val SIZE_PX = 72

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
        val h = size.toFloat()
        val w = size.toFloat()

        canvas.drawOval(
            cx - w * 0.30f,
            h * 0.88f,
            cx + w * 0.30f,
            h * 0.98f,
            Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = 0x44000000
                style = Paint.Style.FILL
            },
        )

        canvas.drawOval(
            cx - w * 0.26f,
            h * 0.70f,
            cx + w * 0.26f,
            h * 0.86f,
            Paint(Paint.ANTI_ALIAS_FLAG).apply {
                shader = RadialGradient(
                    cx, h * 0.76f,
                    w * 0.26f,
                    intArrayOf(0xFFFFFFFF.toInt(), 0xFFE8EDF2.toInt()),
                    floatArrayOf(0f, 1f),
                    Shader.TileMode.CLAMP,
                )
            },
        )

        val body = Path().apply {
            moveTo(cx, h * 0.06f)
            lineTo(cx + w * 0.30f, h * 0.68f)
            lineTo(cx - w * 0.30f, h * 0.68f)
            close()
        }

        canvas.drawPath(
            body,
            Paint(Paint.ANTI_ALIAS_FLAG).apply {
                shader = LinearGradient(
                    cx, h * 0.06f, cx, h * 0.70f,
                    intArrayOf(0xFF80F0FF.toInt(), 0xFF00D4FF.toInt(), 0xFF0096D6.toInt()),
                    floatArrayOf(0f, 0.5f, 1f),
                    Shader.TileMode.CLAMP,
                )
                style = Paint.Style.FILL
            },
        )

        canvas.drawPath(
            body,
            Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = 0xFFFFFFFF.toInt()
                style = Paint.Style.STROKE
                strokeWidth = 2f
                strokeJoin = Paint.Join.ROUND
            },
        )

        return bitmap
    }
}
