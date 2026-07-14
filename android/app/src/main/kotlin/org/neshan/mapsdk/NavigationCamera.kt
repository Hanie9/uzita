package org.neshan.mapsdk

import com.carto.core.ScreenPos
import com.carto.ui.MapView as CartoMapView
import org.neshan.common.model.LatLng

private fun normalizeBearing(degrees: Float): Float {
    var value = degrees % 360f
    if (value < 0f) value += 360f
    return value
}

private var cartoMapViewField: java.lang.reflect.Field? = null

private fun MapView.cartoMapViewOrNull(): CartoMapView? {
    cartoMapViewField?.let { field ->
        return runCatching { field.get(this) as? CartoMapView }.getOrNull()
    }

    runCatching {
        val field = javaClass.getDeclaredField("map")
        field.isAccessible = true
        cartoMapViewField = field
        return field.get(this) as? CartoMapView
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

private fun MapView.invokePrivateMapRotation(bearing: Float, animateMs: Float) {
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

internal fun MapView.readNavigationBearing(): Float {
    cartoMapViewOrNull()?.let { return normalizeBearing(it.mapRotation) }
    return normalizeBearing(getBearing())
}

private fun MapView.applyCartoNavigationState(
    carto: CartoMapView,
    position: LatLng,
    bearing: Float,
    zoom: Float,
    tilt: Float,
    animateMs: Float,
) {
    val normalized = normalizeBearing(bearing)
    val projection = carto.options.baseProjection
    val focusPos = projection.fromLatLong(position.latitude, position.longitude)

    carto.options.isRotatable = true
    carto.setZoom(zoom, animateMs)
    carto.setTilt(tilt, animateMs)
    carto.setMapRotation(normalized, animateMs)
    carto.setFocusPos(focusPos, animateMs)
}

internal fun MapView.applyNavigationRotation(bearing: Float, animateMs: Float = 0f) {
    val normalized = normalizeBearing(bearing)
    settings.setMapRotationEnabled(true)

    cartoMapViewOrNull()?.let { carto ->
        carto.options.isRotatable = true
        carto.setMapRotation(normalized, animateMs)
    }

    invokePrivateMapRotation(normalized, animateMs)
    setBearing(normalized, animateMs)
}

internal fun MapView.applyNavigationFocusOffset(offsetRatio: Float) {
    val viewHeight = height.coerceAtLeast(1).toFloat()
    setMapFocusPointOffset(ScreenPos(0f, -viewHeight * offsetRatio))
}

internal fun MapView.moveNavigationCamera(
    position: LatLng,
    bearing: Float,
    zoom: Float,
    tilt: Float,
    focusOffsetRatio: Float,
    animatePositionMs: Float,
) {
    val normalized = normalizeBearing(bearing)
    val carto = cartoMapViewOrNull()

    applyNavigationFocusOffset(focusOffsetRatio)

    if (carto != null) {
        applyCartoNavigationState(
            carto,
            position,
            normalized,
            zoom,
            tilt,
            animatePositionMs,
        )
        applyNavigationRotation(normalized, 0f)
        setZoom(zoom, 0f)
        setTilt(tilt, 0f)
    } else {
        applyNavigationRotation(normalized, 0f)
        setZoom(zoom, 0f)
        setTilt(tilt, 0f)
        moveCamera(position, animatePositionMs)
    }

    invalidate()

    postDelayed({
        applyNavigationFocusOffset(focusOffsetRatio)
        if (carto != null) {
            applyCartoNavigationState(carto, position, normalized, zoom, tilt, 0f)
        }
        applyNavigationRotation(normalized, 0f)
        setZoom(zoom, 0f)
        setTilt(tilt, 0f)
        invalidate()
    }, 180)
}

internal fun MapView.navigationArrowRotation(routeBearing: Float): Float {
    return normalizeBearing(routeBearing)
}
