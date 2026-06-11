package com.example.uzita

import android.content.Context
import android.graphics.Color as AndroidColor
import android.view.View
import android.widget.FrameLayout
import com.carto.styles.LineStyleBuilder
import com.carto.styles.MarkerStyleBuilder
import io.flutter.embedding.engine.plugins.FlutterPlugin
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
                mapView.fitBounds(points)
                result.success(null)
            }
            "updateRoute" -> {
                @Suppress("UNCHECKED_CAST")
                val remaining = call.argument<List<Map<String, Double>>>("remaining") ?: emptyList()
                @Suppress("UNCHECKED_CAST")
                val traveled = call.argument<List<Map<String, Double>>>("traveled") ?: emptyList()
                val origin = call.argument<Map<String, Double>>("origin")
                val destination = call.argument<Map<String, Double>>("destination")
                val driver = call.argument<Map<String, Double>>("driver")
                mapView.updateRouteOverlay(remaining, traveled, origin, destination, driver)
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
    private var routePolyline: Polyline? = null
    private var traveledPolyline: Polyline? = null
    private var originMarker: Marker? = null
    private var destinationMarker: Marker? = null
    private var driverMarker: Marker? = null

    init {
        val style = if (isDark) NeshanMapStyle.NESHAN_NIGHT else NeshanMapStyle.STANDARD_DAY
        mapView.setMapStyle(style)
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
        if (points.size < 2) {
            if (points.size == 1) {
                mapView.moveCamera(points.first(), 14f)
            }
            return
        }
        var minLat = points.first().latitude
        var maxLat = minLat
        var minLng = points.first().longitude
        var maxLng = minLng
        for (p in points.drop(1)) {
            minLat = minOf(minLat, p.latitude)
            maxLat = maxOf(maxLat, p.latitude)
            minLng = minOf(minLng, p.longitude)
            maxLng = maxOf(maxLng, p.longitude)
        }
        val bounds = LatLngBounds(
            LatLng(maxLat, maxLng),
            LatLng(minLat, minLng),
        )
        mapView.moveToCameraBounds(bounds, null, true, 0.4f)
    }

    fun updateRouteOverlay(
        remaining: List<Map<String, Double>>,
        traveled: List<Map<String, Double>>,
        origin: Map<String, Double>?,
        destination: Map<String, Double>?,
        driver: Map<String, Double>?,
    ) {
        routePolyline?.let { mapView.removePolyline(it) }
        traveledPolyline?.let { mapView.removePolyline(it) }
        originMarker?.let { mapView.removeMarker(it) }
        destinationMarker?.let { mapView.removeMarker(it) }
        driverMarker?.let { mapView.removeMarker(it) }

        val remainingPoints = toLatLngList(remaining)
        if (remainingPoints.size >= 2) {
            val style = LineStyleBuilder().apply {
                setColor(com.carto.graphics.Color(0xFF1E3A8A.toInt()))
                setWidth(8f)
            }.buildStyle()
            routePolyline = Polyline(remainingPoints, style)
            mapView.addPolyline(routePolyline!!)
        } else {
            routePolyline = null
        }

        val traveledPoints = toLatLngList(traveled)
        if (traveledPoints.size >= 2) {
            val style = LineStyleBuilder().apply {
                setColor(com.carto.graphics.Color(0xFF9CA3AF.toInt()))
                setWidth(6f)
            }.buildStyle()
            traveledPolyline = Polyline(traveledPoints, style)
            mapView.addPolyline(traveledPolyline!!)
        } else {
            traveledPolyline = null
        }

        origin?.let {
            val lat = it["lat"] ?: return@let
            val lng = it["lng"] ?: return@let
            originMarker = createMarker(lat, lng, AndroidColor.GREEN)
            mapView.addMarker(originMarker!!)
        }

        destination?.let {
            val lat = it["lat"] ?: return@let
            val lng = it["lng"] ?: return@let
            destinationMarker = createMarker(lat, lng, AndroidColor.RED)
            mapView.addMarker(destinationMarker!!)
        }

        driver?.let {
            val lat = it["lat"] ?: return@let
            val lng = it["lng"] ?: return@let
            driverMarker = createMarker(lat, lng, AndroidColor.BLUE)
            mapView.addMarker(driverMarker!!)
        }
    }

    private fun createMarker(lat: Double, lng: Double, color: Int): Marker {
        val style = MarkerStyleBuilder().apply {
            setColor(com.carto.graphics.Color(color))
            setSize(28f)
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
