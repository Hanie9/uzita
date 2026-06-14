package com.example.uzita

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.view.MotionEvent
import android.view.View
import android.widget.FrameLayout
import com.carto.core.ScreenPos
import com.carto.styles.BillboardOrientation
import com.carto.styles.LineStyleBuilder
import com.carto.styles.MarkerStyleBuilder
import com.carto.utils.BitmapUtils
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import org.neshan.common.model.LatLng
import org.neshan.mapsdk.MapView
import org.neshan.mapsdk.model.Marker
import org.neshan.mapsdk.model.Polyline
import org.neshan.mapsdk.style.NeshanMapStyle
import java.util.concurrent.ConcurrentHashMap

private const val ROUTE_CYAN = 0xFF00D4FF.toInt()
private const val ROUTE_PURPLE = 0xFF7C3AED.toInt()
private const val TRAFFIC_RED = 0xFFDC2626.toInt()
private const val TRAVELED_GREY = 0xFF9CA3AF.toInt()
private const val ORIGIN_GREEN = 0xFF16A34A.toInt()
private const val DESTINATION_ORANGE = 0xFFEA580C.toInt()

private const val NAV_ZOOM = 19f
private const val NAV_TILT = 62f
private const val NAV_MARKER_SIZE = 34f
private const val OVERVIEW_MARKER_SIZE = 34f
private const val DRIVER_DOT_SIZE = 22f

/// Neshan [MapView] per [platform.neshan.org SDK docs](https://platform.neshan.org/docs/sdk/android/installation).
class NeshanMapPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var channel: MethodChannel

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "com.example.uzita/neshan_map")
        channel.setMethodCallHandler(this)

        EventChannel(binding.binaryMessenger, "com.example.uzita/neshan_map_events")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    NeshanMapRegistry.eventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    NeshanMapRegistry.eventSink = null
                }
            })

        binding.platformViewRegistry.registerViewFactory(
            VIEW_TYPE,
            NeshanMapViewFactory(),
        )
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        NeshanMapRegistry.clear()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val viewId = call.argument<Int>("viewId") ?: run {
            result.error("invalid_argument", "viewId is required", null)
            return
        }
        val mapView = NeshanMapRegistry.get(viewId) ?: run {
            result.error("not_found", "Map view $viewId not found", null)
            return
        }

        when (call.method) {
            "moveCamera" -> {
                val lat = call.argument<Double>("lat") ?: 0.0
                val lng = call.argument<Double>("lng") ?: 0.0
                val zoom = call.argument<Double>("zoom")?.toFloat() ?: 14f
                val bearing = call.argument<Double>("bearing")?.toFloat()
                val navigation = call.argument<Boolean>("navigation") ?: false
                val tilt = call.argument<Double>("tilt")?.toFloat()
                mapView.moveCamera(
                    position = LatLng(lat, lng),
                    zoom = zoom,
                    bearing = bearing,
                    navigation = navigation,
                    tilt = tilt,
                )
                result.success(null)
            }
            "setNavigationFollow" -> {
                val enabled = call.argument<Boolean>("enabled") ?: false
                mapView.setNavigationFollowEnabled(enabled)
                result.success(null)
            }
            "setOverviewGestures" -> {
                val enabled = call.argument<Boolean>("enabled") ?: false
                mapView.setOverviewGesturesEnabled(enabled)
                result.success(null)
            }
            "fitBounds" -> {
                @Suppress("UNCHECKED_CAST")
                val raw = call.argument<List<Map<String, Double>>>("points") ?: emptyList()
                val overview = call.argument<Boolean>("overview") ?: false
                val points = raw.mapNotNull { p ->
                    val la = p["lat"] ?: return@mapNotNull null
                    val ln = p["lng"] ?: return@mapNotNull null
                    LatLng(la, ln)
                }
                try {
                    mapView.fitBounds(points, overview)
                    result.success(null)
                } catch (_: Throwable) {
                    result.success(null)
                }
            }
            "updateRoute" -> {
                @Suppress("UNCHECKED_CAST")
                val segments = call.argument<List<Map<String, Any>>>("segments") ?: emptyList()
                @Suppress("UNCHECKED_CAST")
                val traveled = call.argument<List<Map<String, Double>>>("traveled") ?: emptyList()
                val origin = call.argument<Map<String, Double>>("origin")
                val destination = call.argument<Map<String, Double>>("destination")
                val driver = call.argument<Map<String, Any>>("driver")
                val mapDark = call.argument<Boolean>("mapDark") ?: false
                val overviewMode = call.argument<Boolean>("overviewMode") ?: false
                val pickupLeg = call.argument<Boolean>("pickupLeg") ?: false
                mapView.updateRouteOverlay(
                    segments,
                    traveled,
                    origin,
                    destination,
                    driver,
                    mapDark,
                    overviewMode,
                    pickupLeg,
                )
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    companion object {
        const val VIEW_TYPE = "com.example.uzita/neshan_map_view"
    }
}

private object NeshanMapRegistry {
    private val views = ConcurrentHashMap<Int, NeshanMapPlatformView>()
    var eventSink: EventChannel.EventSink? = null

    fun put(id: Int, view: NeshanMapPlatformView) {
        views[id] = view
    }

    fun remove(id: Int) {
        views.remove(id)
    }

    fun get(id: Int): NeshanMapPlatformView? = views[id]

    fun emitEvent(payload: Map<String, Any>) {
        Handler(Looper.getMainLooper()).post {
            eventSink?.success(payload)
        }
    }

    fun clear() {
        views.clear()
        eventSink = null
    }
}

private class NeshanMapViewFactory : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val params = args as? Map<*, *>
        val isDark = params?.get("isDark") as? Boolean ?: false
        return NeshanMapPlatformView(context, viewId, isDark)
    }
}

private class NeshanMapPlatformView(
    context: Context,
    private val viewId: Int,
    isDark: Boolean,
) : PlatformView {
    private val container = FrameLayout(context)
    private val mapView = MapView(context)
    private val routePolylines = mutableListOf<Polyline>()
    private var traveledPolyline: Polyline? = null
    private var originMarker: Marker? = null
    private var destinationMarker: Marker? = null
    private var driverMarker: Marker? = null
    private var navigationFollowEnabled = false
    private var overviewGesturesEnabled = false
    private var suppressGestureEvents = false
    private var userGestureNotified = false
    private var mapDark = isDark

    init {
        applyMapStyle(isDark)
        mapView.setTrafficEnabled(true)
        container.setBackgroundColor(android.graphics.Color.TRANSPARENT)
        mapView.setBackgroundColor(android.graphics.Color.TRANSPARENT)
        container.addView(
            mapView,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT,
            ),
        )
        setupCameraListeners()
        NeshanMapRegistry.put(viewId, this)
        mapView.post {
            mapView.moveCamera(LatLng(35.6892, 51.3890), 0f)
            mapView.setZoom(11f, 0f)
            mapView.invalidate()
        }
    }

    private fun setupCameraListeners() {
        mapView.setOnCameraMoveStartListener { _ ->
            if (suppressGestureEvents) return@setOnCameraMoveStartListener
            when {
                navigationFollowEnabled -> notifyUserDetachedFromRoute()
                overviewGesturesEnabled -> notifyOverviewGesture()
            }
        }

        mapView.setOnTouchListener { _, event ->
            if (suppressGestureEvents) return@setOnTouchListener false
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN,
                MotionEvent.ACTION_MOVE,
                MotionEvent.ACTION_POINTER_DOWN,
                -> when {
                    navigationFollowEnabled -> notifyUserDetachedFromRoute()
                    overviewGesturesEnabled -> notifyOverviewGesture()
                }
            }
            false
        }
    }

    private fun notifyOverviewGesture() {
        if (userGestureNotified || !overviewGesturesEnabled) return
        userGestureNotified = true
        NeshanMapRegistry.emitEvent(
            mapOf(
                "type" to "overviewCameraGesture",
                "viewId" to viewId,
            ),
        )
    }

    private fun notifyUserDetachedFromRoute() {
        if (userGestureNotified || !navigationFollowEnabled) return
        userGestureNotified = true
        navigationFollowEnabled = false
        NeshanMapRegistry.emitEvent(
            mapOf(
                "type" to "userCameraGesture",
                "viewId" to viewId,
            ),
        )
    }

    fun setNavigationFollowEnabled(enabled: Boolean) {
        navigationFollowEnabled = enabled
        if (enabled) {
            userGestureNotified = false
        }
    }

    fun setOverviewGesturesEnabled(enabled: Boolean) {
        overviewGesturesEnabled = enabled
        if (!enabled) {
            userGestureNotified = false
        }
    }

    fun resetCameraGestureState() {
        userGestureNotified = false
    }

    private fun applyMapStyle(dark: Boolean) {
        mapDark = dark
        mapView.setMapStyle(if (dark) NeshanMapStyle.NESHAN_NIGHT else NeshanMapStyle.NESHAN)
    }

    fun moveCamera(
        position: LatLng,
        zoom: Float,
        bearing: Float?,
        navigation: Boolean,
        tilt: Float?,
    ) {
        suppressGestureEvents = true
        if (navigation) {
            val focusOffsetY = mapView.height * 0.38f
            mapView.setMapFocusPointOffset(ScreenPos(0f, focusOffsetY))
            mapView.moveCamera(position, 0.18f)
            mapView.setZoom(zoom, 0.18f)
            bearing?.let { mapView.setBearing(it, 0.18f) }
            mapView.setTilt(tilt ?: NAV_TILT, 0.18f)
        } else {
            mapView.setMapFocusPointOffset(ScreenPos(0f, 0f))
            mapView.moveCamera(position, 0.22f)
            mapView.setZoom(zoom, 0.22f)
            bearing?.let { mapView.setBearing(it, 0.22f) }
            mapView.setTilt(0f, 0.22f)
        }
        mapView.postDelayed({ suppressGestureEvents = false }, 350)
    }

    fun fitBounds(points: List<LatLng>, overview: Boolean = false) {
        if (points.isEmpty()) return

        val minLat = points.minOf { it.latitude }
        val maxLat = points.maxOf { it.latitude }
        val minLng = points.minOf { it.longitude }
        val maxLng = points.maxOf { it.longitude }
        val padFactor = if (overview) 0.45 else 0.18
        val minPad = if (overview) 0.012 else 0.004
        val latPad = maxOf((maxLat - minLat) * padFactor, minPad)
        val lngPad = maxOf((maxLng - minLng) * padFactor, minPad)

        suppressGestureEvents = true
        mapView.setBearing(0f, 0.15f)
        mapView.setTilt(0f, 0.2f)

        if (overview && mapView.height > 0) {
            // Shift visible area above the bottom overview panel.
            mapView.setMapFocusPointOffset(ScreenPos(0f, mapView.height * 0.20f))
        } else {
            mapView.setMapFocusPointOffset(ScreenPos(0f, 0f))
        }

        if (points.size == 1) {
            mapView.post {
                mapView.moveCamera(points.first(), 0.22f)
                mapView.setZoom(if (overview) 13f else 14f, 0.22f)
                mapView.postDelayed({ suppressGestureEvents = false }, 350)
            }
            return
        }

        mapView.post {
            moveCameraToSpan(minLat, maxLat, minLng, maxLng, latPad, lngPad, overview)
            resetCameraGestureState()
            mapView.postDelayed({ suppressGestureEvents = false }, 350)
        }
    }

    private fun moveCameraToSpan(
        minLat: Double,
        maxLat: Double,
        minLng: Double,
        maxLng: Double,
        latPad: Double,
        lngPad: Double,
        overview: Boolean = false,
    ) {
        val centerLat = (minLat + maxLat) / 2.0
        val centerLng = (minLng + maxLng) / 2.0
        val latSpan = maxLat - minLat + latPad * 2
        val lngSpan = maxLng - minLng + lngPad * 2
        val span = maxOf(latSpan, lngSpan)
        val zoom = zoomForSpan(span, overview)
        val adjustedZoom = if (overview) (zoom - 0.6f).coerceAtLeast(5f) else zoom
        mapView.moveCamera(LatLng(centerLat, centerLng), 0.22f)
        mapView.setZoom(adjustedZoom, 0.22f)
    }

    private fun zoomForSpan(span: Double, overview: Boolean = false): Float {
        val base = when {
            span > 10.0 -> 6f
            span > 5.0 -> 8f
            span > 2.0 -> 10f
            span > 1.0 -> 11f
            span > 0.5 -> 12f
            span > 0.2 -> 13f
            span > 0.08 -> 14f
            span > 0.03 -> 15f
            else -> 16f
        }
        return if (overview) (base - 1.5f).coerceAtLeast(5f) else base
    }

    fun updateRouteOverlay(
        segments: List<Map<String, Any>>,
        traveled: List<Map<String, Double>>,
        origin: Map<String, Double>?,
        destination: Map<String, Double>?,
        driver: Map<String, Any>?,
        mapDark: Boolean = false,
        overviewMode: Boolean = false,
        pickupLeg: Boolean = false,
    ) {
        if (mapDark != this.mapDark) {
            applyMapStyle(mapDark)
        }
        routePolylines.forEach { mapView.removePolyline(it) }
        routePolylines.clear()
        traveledPolyline?.let { mapView.removePolyline(it) }
        originMarker?.let { mapView.removeMarker(it) }
        destinationMarker?.let { mapView.removeMarker(it) }
        driverMarker?.let { mapView.removeMarker(it) }

        val navigationMode = driver?.get("navigationMode") as? Boolean ?: false
        val isOverview = overviewMode ||
            (driver?.get("overviewMode") as? Boolean ?: !navigationMode)

        for (segment in segments) {
            @Suppress("UNCHECKED_CAST")
            val rawPoints = segment["points"] as? List<Map<String, Double>> ?: continue
            val congested = segment["congested"] as? Boolean ?: false
            val points = toLatLngList(rawPoints)
            if (points.size < 2) continue

            val color = when {
                congested -> TRAFFIC_RED
                navigationMode -> ROUTE_CYAN
                else -> ROUTE_CYAN
            }
            val lineWidth = if (navigationMode) 10f else 8f
            val style = LineStyleBuilder().apply {
                setColor(com.carto.graphics.Color(color))
                setWidth(lineWidth)
            }.buildStyle()
            val polyline = Polyline(points, style)
            routePolylines.add(polyline)
            mapView.addPolyline(polyline)
        }

        val traveledPoints = toLatLngList(traveled)
        if (traveledPoints.size >= 2) {
            val style = LineStyleBuilder().apply {
                setColor(com.carto.graphics.Color(TRAVELED_GREY))
                setWidth(8f)
            }.buildStyle()
            traveledPolyline = Polyline(traveledPoints, style)
            mapView.addPolyline(traveledPolyline!!)
        } else {
            traveledPolyline = null
        }

        if (isOverview) {
            if (!pickupLeg) {
                origin?.let {
                    val lat = it["lat"] ?: return@let
                    val lng = it["lng"] ?: return@let
                    originMarker = createMarker(lat, lng, ORIGIN_GREEN, OVERVIEW_MARKER_SIZE)
                    mapView.addMarker(originMarker!!)
                }
            }

            destination?.let {
                val lat = it["lat"] ?: return@let
                val lng = it["lng"] ?: return@let
                val color = if (pickupLeg) ORIGIN_GREEN else DESTINATION_ORANGE
                destinationMarker = createMarker(lat, lng, color, OVERVIEW_MARKER_SIZE)
                mapView.addMarker(destinationMarker!!)
            }
        }

        driver?.let {
            val lat = (it["lat"] as? Number)?.toDouble() ?: return@let
            val lng = (it["lng"] as? Number)?.toDouble() ?: return@let
            val bearing = (it["bearing"] as? Number)?.toFloat()
            driverMarker = if (navigationMode) {
                createDriverArrowMarker(lat, lng, bearing)
            } else {
                createMarker(lat, lng, 0xFF2563EB.toInt(), DRIVER_DOT_SIZE)
            }
            mapView.addMarker(driverMarker!!)
        }
    }

    private fun createDriverArrowMarker(
        lat: Double,
        lng: Double,
        bearing: Float?,
    ): Marker {
        val androidBitmap = NavArrowBitmap.create(0f)
        val cartoBitmap = BitmapUtils.createBitmapFromAndroidBitmap(androidBitmap)

        val style = MarkerStyleBuilder().apply {
            setBitmap(cartoBitmap)
            setSize(NAV_MARKER_SIZE)
            setAnchorPointX(0.5f)
            setAnchorPointY(0.78f)
            setOrientationMode(BillboardOrientation.BILLBOARD_ORIENTATION_GROUND)
        }.buildStyle()

        return Marker(LatLng(lat, lng), style)
    }

    private fun createMarker(lat: Double, lng: Double, color: Int, size: Float): Marker {
        val style = MarkerStyleBuilder().apply {
            setColor(com.carto.graphics.Color(color))
            setSize(size)
        }.buildStyle()
        return Marker(LatLng(lat, lng), style)
    }

    private fun toLatLngList(raw: List<Map<String, Double>>): ArrayList<LatLng> {
        val list = ArrayList<LatLng>(raw.size)
        raw.forEach { p ->
            val lat = p["lat"] ?: return@forEach
            val lng = p["lng"] ?: return@forEach
            list.add(LatLng(lat, lng))
        }
        return list
    }

    override fun getView(): View = container

    override fun dispose() {
        NeshanMapRegistry.remove(viewId)
        container.removeAllViews()
    }
}
