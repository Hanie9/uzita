package com.example.uzita

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.LinearGradient
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.Path
import android.graphics.Shader

/// Cyan navigation puck bitmap (Neshan-style), tip points to top of image.
internal object NavArrowBitmap {
    private const val SIZE_PX = 112

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

        // Ground shadow
        val shadow = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = 0x47000000
            style = Paint.Style.FILL
        }
        canvas.drawOval(cx - w * 0.28f, h * 0.86f, cx + w * 0.28f, h * 0.96f, shadow)

        val body = Path().apply {
            moveTo(cx, h * 0.06f)
            lineTo(cx + w * 0.40f, h * 0.70f)
            lineTo(cx + w * 0.12f, h * 0.64f)
            lineTo(cx + w * 0.12f, h * 0.84f)
            lineTo(cx - w * 0.12f, h * 0.84f)
            lineTo(cx - w * 0.12f, h * 0.64f)
            lineTo(cx - w * 0.40f, h * 0.70f)
            close()
        }

        val fill = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            shader = LinearGradient(
                cx, h * 0.06f, cx, h * 0.86f,
                intArrayOf(0xFF7DD3FC.toInt(), 0xFF38BDF8.toInt(), 0xFF0284C7.toInt()),
                floatArrayOf(0f, 0.45f, 1f),
                Shader.TileMode.CLAMP,
            )
            style = Paint.Style.FILL
        }
        canvas.drawPath(body, fill)

        val stroke = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = 0xFFFFFFFF.toInt()
            style = Paint.Style.STROKE
            strokeWidth = 3f
            strokeJoin = Paint.Join.ROUND
        }
        canvas.drawPath(body, stroke)

        return bitmap
    }
}
