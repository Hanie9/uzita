package com.example.uzita

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.view.MotionEvent
import android.view.View
import android.widget.FrameLayout
import com.carto.core.ScreenBounds
import com.carto.core.ScreenPos
import com.carto.styles.BillboardOrientation
import com.carto.styles.LineEndType
import com.carto.styles.LineJoinType
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
import org.neshan.common.model.LatLngBounds
import org.neshan.mapsdk.MapView
import org.neshan.mapsdk.model.Marker
import org.neshan.mapsdk.model.Polyline
import org.neshan.mapsdk.style.NeshanMapStyle
import java.util.concurrent.ConcurrentHashMap

private const val ROUTE_CYAN = 0xFF00D4FF.toInt()
private const val ROUTE_PURPLE = 0xFF7C3AED.toInt()
private const val TRAFFIC_RED = 0xFFDC2626.toInt()
private const val TRAFFIC_ORANGE = 0xFFEA580C.toInt()
private const val TRAVELED_GREY = 0xFF9CA3AF.toInt()
private const val ORIGIN_GREEN = 0xFF16A34A.toInt()
private const val DESTINATION_ORANGE = 0xFFEA580C.toInt()

// Matches the Neshan Navigator framing: zoomed in close enough to read street
// names and see a few blocks of the road ahead, with the puck in the lower third.
private const val NAV_ZOOM = 17.5f
// Carto/Neshan tilt: 0 = horizon (strong 3D), 90 = top-down (flat).
// Keep enough tilt for a chase view, but not so low that the upper screen
// becomes empty night-sky behind the navigation instruction cards.
private const val NAV_TILT = 56f
// Fraction of the view height to drop the driver puck below centre so the road
// ahead fills the upper screen. A negative ScreenPos Y keeps the focus point
// (and the driver puck) inside the lower portion of the screen on this SDK.
private const val NAV_FOCUS_OFFSET = 0.16f
/// Top-down (tilt 90) overview so the Mercator fit reliably frames the WHOLE
/// route on any screen size and route length (perspective would clip long
/// routes off the top of the screen).
private const val OVERVIEW_TILT = 90f
private const val NAV_MARKER_SIZE = 42f
private const val OVERVIEW_MARKER_SIZE = 34f
private const val DRIVER_DOT_SIZE = 22f
private const val NAV_TOUCH_SLOP_SQ = 64f

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
            "beginNavigationCamera" -> {
                val lat = call.argument<Double>("lat") ?: 0.0
                val lng = call.argument<Double>("lng") ?: 0.0
                val bearing = call.argument<Double>("bearing")?.toFloat() ?: 0f
                val mapDark = call.argument<Boolean>("mapDark") ?: false
                mapView.beginNavigationCamera(LatLng(lat, lng), bearing, mapDark)
                result.success(null)
            }
            "updateNavigationCamera" -> {
                val lat = call.argument<Double>("lat") ?: 0.0
                val lng = call.argument<Double>("lng") ?: 0.0
                val bearing = call.argument<Double>("bearing")?.toFloat() ?: 0f
                mapView.updateNavigationCamera(LatLng(lat, lng), bearing)
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
                val bottomInsetRatio =
                    call.argument<Double>("bottomInsetRatio")?.toFloat() ?: 0.20f
                val points = raw.mapNotNull { p ->
                    val la = p["lat"] ?: return@mapNotNull null
                    val ln = p["lng"] ?: return@mapNotNull null
                    LatLng(la, ln)
                }
                try {
                    mapView.fitBounds(points, overview, bottomInsetRatio)
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
        applyOverviewCameraSettings()
        NeshanMapRegistry.put(viewId, this)
        mapView.post {
            mapView.moveCamera(LatLng(35.6892, 51.3890), 0f)
            mapView.setZoom(11f, 0f)
            mapView.setBearing(0f, 0f)
            mapView.setTilt(OVERVIEW_TILT, 0f)
            mapView.invalidate()
        }
    }

    private fun applyOverviewCameraSettings() {
        mapView.getSettings().setMapRotationEnabled(false)
        mapView.getSettings().setMinTiltAngle(30f)
        mapView.getSettings().setMaxTiltAngle(90f)
    }

    private fun applyNavigationCameraSettings() {
        mapView.getSettings().setMapRotationEnabled(true)
        mapView.getSettings().setMinTiltAngle(30f)
        mapView.getSettings().setMaxTiltAngle(90f)
    }

    private fun enforceOverviewCamera() {
        if (suppressGestureEvents || navigationFollowEnabled) return
        val bearing = mapView.getBearing()
        val tilt = mapView.getTilt()
        if (kotlin.math.abs(bearing) > 0.5f || kotlin.math.abs(tilt - OVERVIEW_TILT) > 2f) {
            suppressGestureEvents = true
            mapView.setBearing(0f, 0f)
            mapView.setTilt(OVERVIEW_TILT, 0f)
            mapView.postDelayed({ suppressGestureEvents = false }, 120)
        }
    }

    // True while the user's finger is on the map (incl. a short tail to catch
    // fling-driven camera moves). Lets us distinguish user pans from our own
    // programmatic follow moves.
    private var userIsTouching = false
    private var navTouchStartX = 0f
    private var navTouchStartY = 0f
    private var navTouchDetached = false

    private fun setupCameraListeners() {
        mapView.setOnCameraMoveListener {
            if (!navigationFollowEnabled && overviewGesturesEnabled) {
                enforceOverviewCamera()
            }
        }

        // Camera moved: only treat it as a user gesture when the user is
        // actually touching the map. Programmatic follow moves happen without a
        // touch, so they never detach the camera.
        mapView.setOnCameraMoveStartListener { _ ->
            if (!userIsTouching) return@setOnCameraMoveStartListener
            if (navigationFollowEnabled) {
                notifyUserDetachedFromRoute()
                navigationFollowEnabled = false
            } else if (overviewGesturesEnabled) {
                notifyOverviewGesture()
            }
        }

        mapView.setOnTouchListener { _, event ->
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN,
                MotionEvent.ACTION_POINTER_DOWN,
                -> {
                    userIsTouching = true
                    navTouchDetached = false
                    navTouchStartX = event.x
                    navTouchStartY = event.y
                }
                MotionEvent.ACTION_MOVE,
                -> {
                    if (navigationFollowEnabled && !navTouchDetached) {
                        val dx = event.x - navTouchStartX
                        val dy = event.y - navTouchStartY
                        if ((dx * dx + dy * dy) >= NAV_TOUCH_SLOP_SQ) {
                            navTouchDetached = true
                            notifyUserDetachedFromRoute()
                            navigationFollowEnabled = false
                        }
                    }
                }
                MotionEvent.ACTION_UP,
                MotionEvent.ACTION_CANCEL,
                -> {
                    // Keep the flag briefly so a fling's trailing camera move
                    // still counts as a user gesture.
                    mapView.postDelayed({ userIsTouching = false }, 350)
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
        if (userGestureNotified) return
        userGestureNotified = true
        NeshanMapRegistry.emitEvent(
            mapOf(
                "type" to "userCameraGesture",
                "viewId" to viewId,
            ),
        )
    }

    fun updateNavigationCamera(position: LatLng, bearing: Float) {
        if (!navigationFollowEnabled) return

        val apply = {
            suppressGestureEvents = true
            val viewHeight = mapView.height.coerceAtLeast(1)
            // Drop the driver into the lower third of the screen so the road
            // ahead fills the view (Neshan-style). Bearing + tilt are applied
            // instantly (duration 0) so concurrent animations never drop them.
            mapView.setMapFocusPointOffset(ScreenPos(0f, -viewHeight * NAV_FOCUS_OFFSET))
            mapView.setTilt(NAV_TILT, 0f)
            mapView.setBearing(bearing, 0f)
            mapView.setZoom(NAV_ZOOM, 0f)
            mapView.moveCamera(position, 0.25f)
            mapView.invalidate()
            mapView.postDelayed({ suppressGestureEvents = false }, 250)
        }

        if (mapView.height <= 0) {
            mapView.post { apply() }
        } else {
            apply()
        }
    }

    fun beginNavigationCamera(position: LatLng, bearing: Float, mapDark: Boolean = false) {
        navigationFollowEnabled = true
        overviewGesturesEnabled = false
        userGestureNotified = false
        userIsTouching = false
        navTouchDetached = false
        if (mapDark && !this.mapDark) {
            applyMapStyle(true)
        }
        applyNavigationCameraSettings()
        suppressGestureEvents = true

        val apply = {
            val viewHeight = mapView.height.coerceAtLeast(1)
            // Establish the 3D follow camera instantly so tilt/bearing reliably
            // stick (animated multi-property camera moves can drop tilt/bearing).
            mapView.setMapFocusPointOffset(ScreenPos(0f, -viewHeight * NAV_FOCUS_OFFSET))
            mapView.setTilt(NAV_TILT, 0f)
            mapView.setBearing(bearing, 0f)
            mapView.setZoom(NAV_ZOOM, 0f)
            mapView.moveCamera(position, 0f)
            mapView.invalidate()
            mapView.postDelayed({ suppressGestureEvents = false }, 600)
        }

        if (mapView.height <= 0) {
            mapView.post { apply() }
        } else {
            apply()
        }
    }

    fun setNavigationFollowEnabled(enabled: Boolean) {
        if (enabled == navigationFollowEnabled) return
        navigationFollowEnabled = enabled
        if (enabled) {
            userGestureNotified = false
            applyNavigationCameraSettings()
        } else if (!overviewGesturesEnabled) {
            applyOverviewCameraSettings()
        }
    }

    fun setOverviewGesturesEnabled(enabled: Boolean) {
        overviewGesturesEnabled = enabled
        if (enabled) {
            applyOverviewCameraSettings()
            mapView.setBearing(0f, 0f)
            mapView.setTilt(OVERVIEW_TILT, 0f)
        }
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
        val applyMove = {
            suppressGestureEvents = true
            if (navigation) {
                val viewHeight = mapView.height.coerceAtLeast(1)
                mapView.setMapFocusPointOffset(ScreenPos(0f, -viewHeight * NAV_FOCUS_OFFSET))
                mapView.setTilt(tilt ?: NAV_TILT, 0f)
                mapView.setBearing(bearing ?: 0f, 0f)
                mapView.setZoom(zoom, 0f)
                mapView.moveCamera(position, 0.25f)
            } else {
                mapView.setMapFocusPointOffset(ScreenPos(0f, 0f))
                mapView.moveCamera(position, 0.22f)
                mapView.setZoom(zoom, 0.22f)
                mapView.setBearing(0f, 0.22f)
                mapView.setTilt(OVERVIEW_TILT, 0.22f)
            }
            mapView.invalidate()
            mapView.postDelayed({ suppressGestureEvents = false }, 900)
        }

        if (mapView.height <= 0) {
            mapView.post { applyMove() }
        } else {
            applyMove()
        }
    }

    fun fitBounds(
        points: List<LatLng>,
        overview: Boolean = false,
        bottomInsetRatio: Float = 0.20f,
    ) {
        if (points.isEmpty() || navigationFollowEnabled) return

        val minLat = points.minOf { it.latitude }
        val maxLat = points.maxOf { it.latitude }
        val minLng = points.minOf { it.longitude }
        val maxLng = points.maxOf { it.longitude }
        val padFactor = if (overview) 0.30 else 0.18
        val minPad = if (overview) 0.012 else 0.004
        val latPad = maxOf((maxLat - minLat) * padFactor, minPad)
        val lngPad = maxOf((maxLng - minLng) * padFactor, minPad)

        suppressGestureEvents = true
        if (overview) {
            applyOverviewCameraSettings()
        }
        mapView.setBearing(0f, 0f)
        mapView.setTilt(OVERVIEW_TILT, 0f)

        // Centre the route (no focus offset) so it is framed with an even margin
        // on every screen size; the bottom panel is already excluded from the
        // native map height, so we must not reserve extra bottom space here.
        mapView.setMapFocusPointOffset(ScreenPos(0f, 0f))

        if (points.size == 1) {
            mapView.post {
                if (navigationFollowEnabled) {
                    suppressGestureEvents = false
                    return@post
                }
                mapView.moveCamera(points.first(), 0.22f)
                mapView.setZoom(if (overview) 10.2f else 14f, 0.22f)
                mapView.setBearing(0f, 0f)
                mapView.setTilt(OVERVIEW_TILT, 0f)
                mapView.postDelayed({ suppressGestureEvents = false }, 350)
            }
            return
        }

        mapView.post {
            fitBoundsWhenReady(
                minLat,
                maxLat,
                minLng,
                maxLng,
                latPad,
                lngPad,
                overview,
                bottomInsetRatio,
                attempt = 0,
            )
        }
    }

    /// Fits the camera to bounds, but waits for the map to be laid out first.
    /// Before the MapView is measured its width/height are 0, which would make
    /// the bounds-fit collapse to a tiny area instead of the whole route. We
    /// retry until the view dimensions are valid.
    private fun fitBoundsWhenReady(
        minLat: Double,
        maxLat: Double,
        minLng: Double,
        maxLng: Double,
        latPad: Double,
        lngPad: Double,
        overview: Boolean,
        bottomInsetRatio: Float,
        attempt: Int,
    ) {
        if (navigationFollowEnabled) {
            suppressGestureEvents = false
            return
        }
        if ((mapView.width <= 0 || mapView.height <= 0) && attempt < 10) {
            mapView.postDelayed({
                fitBoundsWhenReady(
                    minLat,
                    maxLat,
                    minLng,
                    maxLng,
                    latPad,
                    lngPad,
                    overview,
                    bottomInsetRatio,
                    attempt + 1,
                )
            }, 120)
            return
        }
        moveCameraToSpan(
            minLat,
            maxLat,
            minLng,
            maxLng,
            latPad,
            lngPad,
            overview,
            bottomInsetRatio,
        )
        resetCameraGestureState()
        mapView.postDelayed({ suppressGestureEvents = false }, 350)
    }

    private fun moveCameraToSpan(
        minLat: Double,
        maxLat: Double,
        minLng: Double,
        maxLng: Double,
        latPad: Double,
        lngPad: Double,
        overview: Boolean = false,
        bottomInsetRatio: Float = 0.20f,
    ) {
        // Use Neshan's native bounds-fit, which frames the geographic box inside
        // a screen rectangle using the real map projection. This guarantees the
        // entire route fits on any screen size, regardless of zoom convention.
        if (overview) {
            mapView.setBearing(0f, 0f)
            mapView.setTilt(OVERVIEW_TILT, 0f)
        }

        val ne = LatLng(maxLat + latPad, maxLng + lngPad)
        val sw = LatLng(minLat - latPad, minLng - lngPad)
        val bounds = LatLngBounds(ne, sw)

        val w = mapView.width.coerceAtLeast(1).toFloat()
        val h = mapView.height.coerceAtLeast(1).toFloat()

        // Side/top/bottom insets so the route never touches the edges and clears
        // the floating header card at the top of the map area.
        val sideInset = w * 0.07f
        val topInset = if (overview) h * 0.14f else h * 0.10f
        val bottomInset = h * (bottomInsetRatio.coerceIn(0.04f, 0.45f))

        val screenBounds = ScreenBounds(
            ScreenPos(sideInset, topInset),
            ScreenPos(w - sideInset, h - bottomInset),
        )

        mapView.moveToCameraBounds(bounds, screenBounds, false, 0.4f)

        if (overview) {
            mapView.setBearing(0f, 0f)
            mapView.setTilt(OVERVIEW_TILT, 0f)
        }
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
        val isOverview = !navigationMode && (
            overviewMode || (driver?.get("overviewMode") as? Boolean ?: true)
        )

        for (segment in segments) {
            @Suppress("UNCHECKED_CAST")
            val rawPoints = segment["points"] as? List<Map<String, Double>> ?: continue
            val trafficLevel = segment["trafficLevel"] as? String
            val congested = segment["congested"] as? Boolean ?: false
            val points = toLatLngList(rawPoints)
            if (points.size < 2) continue

            val color = when (trafficLevel) {
                "heavy" -> TRAFFIC_RED
                "moderate" -> TRAFFIC_ORANGE
                "clear" -> ROUTE_PURPLE
                else -> if (congested) TRAFFIC_RED else ROUTE_PURPLE
            }
            val lineWidth = if (navigationMode) 7f else 5f
            val style = LineStyleBuilder().apply {
                setColor(com.carto.graphics.Color(color))
                setWidth(lineWidth)
                setLineJoinType(LineJoinType.LINE_JOIN_TYPE_ROUND)
                setLineEndType(LineEndType.LINE_END_TYPE_ROUND)
            }.buildStyle()
            val polyline = Polyline(points, style)
            routePolylines.add(polyline)
            mapView.addPolyline(polyline)
        }

        val traveledPoints = toLatLngList(traveled)
        if (traveledPoints.size >= 2) {
            val style = LineStyleBuilder().apply {
                setColor(com.carto.graphics.Color(TRAVELED_GREY))
                setWidth(5f)
                setLineJoinType(LineJoinType.LINE_JOIN_TYPE_ROUND)
                setLineEndType(LineEndType.LINE_END_TYPE_ROUND)
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
            // Carto anchor range is [-1, 1]; (0, 0) centres the arrow exactly on
            // the GPS coordinate (default (0, -1) would place it above the point).
            setAnchorPointX(0f)
            setAnchorPointY(0f)
            // Screen-facing so the chevron always points "up" = travel
            // direction (the map itself is rotated heading-up).
            setOrientationMode(BillboardOrientation.BILLBOARD_ORIENTATION_FACE_CAMERA)
        }.buildStyle()

        return Marker(LatLng(lat, lng), style)
    }

    private fun createMarker(lat: Double, lng: Double, color: Int, size: Float): Marker {
        val style = MarkerStyleBuilder().apply {
            setColor(com.carto.graphics.Color(color))
            setSize(size)
            // Carto anchor range is [-1, 1]; (0, 0) centres the dot exactly on
            // the GPS coordinate (default is (0, -1) = bottom centre, which
            // makes the marker sit above its real position).
            setAnchorPointX(0f)
            setAnchorPointY(0f)
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
