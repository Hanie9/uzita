package org.neshan.mapsdk

import com.carto.core.ScreenPos
import com.carto.ui.MapView as CartoMapView
import org.neshan.common.model.LatLng

private fun normalizeBearing(degrees: Float): Float {
    var value = degrees % 360f
    if (value < 0f) value += 360f
    return value
}

private fun bearingDeltaDegrees(a: Float, b: Float): Float {
    var delta = kotlin.math.abs(normalizeBearing(a) - normalizeBearing(b))
    if (delta > 180f) delta = 360f - delta
    return delta
}

private var cartoMapViewField: java.lang.reflect.Field? = null
private var lastLockedBearing: Float? = null

private fun MapView.cartoMapViewOrNull(): CartoMapView? {
    cartoMapViewField?.let { field ->
        return runCatching { field.get(this) as? CartoMapView }.getOrNull()
    }

    for (name in listOf("map_view", "carto_map", "map")) {
        val carto = runCatching {
            val field = javaClass.getDeclaredField(name)
            if (!CartoMapView::class.java.isAssignableFrom(field.type)) return@runCatching null
            field.isAccessible = true
            cartoMapViewField = field
            field.get(this) as? CartoMapView
        }.getOrNull()
        if (carto != null) return carto
    }

    var clazz: Class<*>? = javaClass
    while (clazz != null) {
        for (field in clazz.declaredFields) {
            if (!CartoMapView::class.java.isAssignableFrom(field.type)) continue
            field.isAccessible = true
            cartoMapViewField = field
            return runCatching { field.get(this) as? CartoMapView }.getOrNull()
        }
        clazz = clazz.superclass
    }
    return null
}

private fun MapView.invokeNeshanMapRotation(bearing: Float, animateMs: Float) {
    var clazz: Class<*>? = javaClass
    while (clazz != null) {
        try {
            val method = clazz.getDeclaredMethod(
                "setMapRotation",
                Float::class.javaPrimitiveType,
                Float::class.javaPrimitiveType,
            )
            method.isAccessible = true
            method.invoke(this, bearing, animateMs)
            return
        } catch (_: Throwable) {
            clazz = clazz.superclass
        }
    }
}

private fun compassToCartoRotation(compassBearing: Float): Float {
    var rotation = -normalizeBearing(compassBearing)
    while (rotation > 180f) rotation -= 360f
    while (rotation <= -180f) rotation += 360f
    return rotation
}

private fun MapView.lockNavigationBearing(
    compassBearing: Float,
    adjustTiltZoom: Boolean,
    tilt: Float,
    zoom: Float,
) {
    val normalized = normalizeBearing(compassBearing)
    if (lastLockedBearing != null &&
        bearingDeltaDegrees(lastLockedBearing!!, normalized) < 0.5f
    ) {
        return
    }
    lastLockedBearing = normalized

    settings.setMapRotationEnabled(true)
    if (adjustTiltZoom) {
        setTilt(tilt, 0f)
        setZoom(zoom, 0f)
    }
    setBearing(normalized, 0f)
    invokeNeshanMapRotation(normalized, 0f)

    cartoMapViewOrNull()?.let { carto ->
        carto.options.isRotatable = true
        carto.setMapRotation(compassToCartoRotation(normalized), 0f)
    }
}

internal fun MapView.readNavigationBearing(): Float =
    normalizeBearing(getBearing())

internal fun MapView.clearNavigationBearingLock() {
    lastLockedBearing = null
}

internal fun MapView.resetNavigationViewRotation() {
    rotation = 0f
    lastLockedBearing = null
    setBearing(0f, 0f)
    invokeNeshanMapRotation(0f, 0f)
    cartoMapViewOrNull()?.setMapRotation(0f, 0f)
}

/// Move the follow camera without touching bearing (prevents jitter on GPS ticks).
internal fun MapView.applyNavigationPosition(
    position: LatLng,
    focusOffsetRatio: Float,
    animatePositionMs: Float,
) {
    val animate = animatePositionMs.coerceAtLeast(0f)
    val viewHeight = height.coerceAtLeast(1).toFloat()
    setMapFocusPointOffset(ScreenPos(0f, -viewHeight * focusOffsetRatio))
    moveCamera(position, animate)
    invalidate()
}

/// Full heading-up navigation camera (bearing + position).
internal fun MapView.applyNavigationCamera(
    position: LatLng,
    bearing: Float,
    zoom: Float,
    tilt: Float,
    focusOffsetRatio: Float,
    animatePositionMs: Float,
) {
    rotation = 0f
    val normalized = normalizeBearing(bearing)
    val animate = animatePositionMs.coerceAtLeast(0f)
    settings.setMapRotationEnabled(true)

    val viewHeight = height.coerceAtLeast(1).toFloat()
    setMapFocusPointOffset(ScreenPos(0f, -viewHeight * focusOffsetRatio))

    setTilt(tilt, 0f)
    setZoom(zoom, 0f)
    setBearing(normalized, 0f)
    moveCamera(position, animate)
    lockNavigationBearing(
        compassBearing = normalized,
        adjustTiltZoom = false,
        tilt = tilt,
        zoom = zoom,
    )
    invalidate()
}

internal fun MapView.applyNavigationBearing(
    bearing: Float,
    tilt: Float,
    zoom: Float,
) {
    lockNavigationBearing(
        compassBearing = bearing,
        adjustTiltZoom = false,
        tilt = tilt,
        zoom = zoom,
    )
    invalidate()
}

internal fun MapView.updateNavigationCamera(
    position: LatLng,
    bearing: Float,
    zoom: Float,
    tilt: Float,
    focusOffsetRatio: Float,
    animatePositionMs: Float,
) {
    val normalized = normalizeBearing(bearing)
    val bearingChanged = lastLockedBearing == null ||
        bearingDeltaDegrees(lastLockedBearing!!, normalized) >= 10f

    if (bearingChanged) {
        applyNavigationPosition(position, focusOffsetRatio, animatePositionMs)
        applyNavigationBearing(normalized, tilt, zoom)
    } else {
        applyNavigationPosition(position, focusOffsetRatio, animatePositionMs)
    }
}
