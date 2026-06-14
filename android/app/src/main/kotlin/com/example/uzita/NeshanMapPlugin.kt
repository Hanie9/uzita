package com.example.uzita

import android.content.Context
import android.view.View
import android.widget.FrameLayout
import com.carto.styles.BillboardOrientation
import com.carto.styles.LineStyleBuilder
import com.carto.styles.MarkerStyleBuilder
import com.carto.utils.BitmapUtils
import io.flutter.embedding.engine.plugins.FlutterPlugin
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

private const val ROUTE_BLUE = 0xFF2563EB.toInt()
private const val TRAFFIC_RED = 0xFFDC2626.toInt()
private const val TRAVELED_GREY = 0xFF9CA3AF.toInt()
private const val ORIGIN_GREEN = 0xFF16A34A.toInt()
private const val DESTINATION_ORANGE = 0xFFEA580C.toInt()

/// Neshan [MapView] per [platform.neshan.org SDK docs](https://platform.neshan.org/docs/sdk/android/installation).
class NeshanMapPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var channel: MethodChannel

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "com.example.uzita/neshan_map")
        channel.setMethodCallHandler(this)

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
                mapView.moveCamera(LatLng(lat, lng), zoom)
                if (bearing != null) {
                    mapView.setBearing(bearing, 0.3f)
                }
                result.success(null)
            }
            "fitBounds" -> {
                @Suppress("UNCHECKED_CAST")
                val raw = call.argument<List<Map<String, Double>>>("points") ?: emptyList()
                val points = raw.mapNotNull { p ->
                    val la = p["lat"] ?: return@mapNotNull null
                    val ln = p["lng"] ?: return@mapNotNull null
                    LatLng(la, ln)
                }
                try {
                    mapView.fitBounds(points)
                    result.success(null)
                } catch (_: Throwable) {
                    // Never crash the Flutter channel; manual fallback runs inside fitBounds.
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
                mapView.updateRouteOverlay(segments, traveled, origin, destination, driver)
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

    fun put(id: Int, view: NeshanMapPlatformView) {
        views[id] = view
    }

    fun remove(id: Int) {
        views.remove(id)
    }

    fun get(id: Int): NeshanMapPlatformView? = views[id]

    fun clear() {
        views.clear()
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

    init {
        val style = if (isDark) NeshanMapStyle.NESHAN_NIGHT else NeshanMapStyle.NESHAN
        mapView.setMapStyle(style)
        mapView.setTrafficEnabled(true)
        container.addView(
            mapView,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT,
            ),
        )
        NeshanMapRegistry.put(viewId, this)
    }

    fun moveCamera(position: LatLng, zoom: Float) {
        mapView.moveCamera(position, zoom)
    }

    fun setBearing(bearing: Float, duration: Float = 0.3f) {
        mapView.setBearing(bearing, duration)
    }

    fun fitBounds(points: List<LatLng>) {
        if (points.isEmpty()) return

        val minLat = points.minOf { it.latitude }
        val maxLat = points.maxOf { it.latitude }
        val minLng = points.minOf { it.longitude }
        val maxLng = points.maxOf { it.longitude }
        val latPad = maxOf((maxLat - minLat) * 0.15, 0.003)
        val lngPad = maxOf((maxLng - minLng) * 0.15, 0.003)

        if (points.size == 1) {
            mapView.post { mapView.moveCamera(points.first(), 14f) }
            return
        }

        // SDK moveToCameraBounds crashes on some devices (null ScreenBounds in native JNI).
        mapView.post {
            moveCameraToSpan(minLat, maxLat, minLng, maxLng, latPad, lngPad)
        }
    }

    private fun moveCameraToSpan(
        minLat: Double,
        maxLat: Double,
        minLng: Double,
        maxLng: Double,
        latPad: Double,
        lngPad: Double,
    ) {
        val centerLat = (minLat + maxLat) / 2.0
        val centerLng = (minLng + maxLng) / 2.0
        val span = maxOf(
            maxLat - minLat + latPad * 2,
            maxLng - minLng + lngPad * 2,
        )
        mapView.moveCamera(LatLng(centerLat, centerLng), zoomForSpan(span))
    }

    private fun zoomForSpan(span: Double): Float = when {
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

    fun updateRouteOverlay(
        segments: List<Map<String, Any>>,
        traveled: List<Map<String, Double>>,
        origin: Map<String, Double>?,
        destination: Map<String, Double>?,
        driver: Map<String, Any>?,
    ) {
        routePolylines.forEach { mapView.removePolyline(it) }
        routePolylines.clear()
        traveledPolyline?.let { mapView.removePolyline(it) }
        originMarker?.let { mapView.removeMarker(it) }
        destinationMarker?.let { mapView.removeMarker(it) }
        driverMarker?.let { mapView.removeMarker(it) }

        for (segment in segments) {
            @Suppress("UNCHECKED_CAST")
            val rawPoints = segment["points"] as? List<Map<String, Double>> ?: continue
            val congested = segment["congested"] as? Boolean ?: false
            val points = toLatLngList(rawPoints)
            if (points.size < 2) continue

            val color = if (congested) TRAFFIC_RED else ROUTE_BLUE
            val style = LineStyleBuilder().apply {
                setColor(com.carto.graphics.Color(color))
                setWidth(10f)
            }.buildStyle()
            val polyline = Polyline(points, style)
            routePolylines.add(polyline)
            mapView.addPolyline(polyline)
        }

        val traveledPoints = toLatLngList(traveled)
        if (traveledPoints.size >= 2) {
            val style = LineStyleBuilder().apply {
                setColor(com.carto.graphics.Color(TRAVELED_GREY))
                setWidth(7f)
            }.buildStyle()
            traveledPolyline = Polyline(traveledPoints, style)
            mapView.addPolyline(traveledPolyline!!)
        } else {
            traveledPolyline = null
        }

        origin?.let {
            val lat = it["lat"] ?: return@let
            val lng = it["lng"] ?: return@let
            originMarker = createMarker(lat, lng, ORIGIN_GREEN, 34f)
            mapView.addMarker(originMarker!!)
        }

        destination?.let {
            val lat = it["lat"] ?: return@let
            val lng = it["lng"] ?: return@let
            destinationMarker = createMarker(lat, lng, DESTINATION_ORANGE, 38f)
            mapView.addMarker(destinationMarker!!)
        }

        driver?.let {
            val lat = (it["lat"] as? Number)?.toDouble() ?: return@let
            val lng = (it["lng"] as? Number)?.toDouble() ?: return@let
            val bearing = (it["bearing"] as? Number)?.toFloat()
            val navigationMode = it["navigationMode"] as? Boolean ?: false
            driverMarker = createDriverArrowMarker(
                lat = lat,
                lng = lng,
                bearing = bearing,
                navigationMode = navigationMode,
            )
            mapView.addMarker(driverMarker!!)
        }
    }

    private fun createDriverArrowMarker(
        lat: Double,
        lng: Double,
        bearing: Float?,
        navigationMode: Boolean,
    ): Marker {
        // When map camera rotates with bearing, puck points up (0°). Otherwise rotate puck.
        val bitmapBearing = if (navigationMode) 0f else (bearing ?: 0f)
        val androidBitmap = NavArrowBitmap.create(bitmapBearing)
        val cartoBitmap = BitmapUtils.createBitmapFromAndroidBitmap(androidBitmap)
        val markerSize = if (navigationMode) 58f else 48f

        val style = MarkerStyleBuilder().apply {
            setBitmap(cartoBitmap)
            setSize(markerSize)
            setAnchorPointX(0.5f)
            setAnchorPointY(0.82f)
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
