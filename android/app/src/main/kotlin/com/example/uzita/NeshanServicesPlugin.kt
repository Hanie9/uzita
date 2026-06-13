package com.example.uzita

import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.neshan.common.model.LatLng
import org.neshan.servicessdk.direction.NeshanDirection
import org.neshan.servicessdk.direction.model.DirectionResultLeg
import org.neshan.servicessdk.direction.model.DirectionStep
import org.neshan.servicessdk.direction.model.NeshanDirectionResult
import org.neshan.servicessdk.search.NeshanSearch
import org.neshan.servicessdk.search.model.NeshanSearchResult
import retrofit2.Call
import retrofit2.Callback
import retrofit2.Response
import java.util.ArrayList

/// Neshan routing via Android services-sdk (v4/direction with live traffic).
class NeshanServicesPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var channel: MethodChannel
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "com.example.uzita/neshan_services")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "geocodeAddress" -> geocodeAddress(call, result)
            "getRoute" -> getRoute(call, result)
            else -> result.notImplemented()
        }
    }

    private fun geocodeAddress(call: MethodCall, result: MethodChannel.Result) {
        val address = call.argument<String>("address")?.trim().orEmpty()
        if (address.isEmpty()) {
            result.error("invalid_argument", "address is required", null)
            return
        }

        // NeshanSearch requires a non-null location (SDK NPE otherwise).
        val centerLat = call.argument<Double>("centerLat") ?: 35.6892
        val centerLng = call.argument<Double>("centerLng") ?: 51.3890

        val search = NeshanSearch.Builder(address)
            .setLocation(LatLng(centerLat, centerLng))
            .build()
        search.call(object : Callback<NeshanSearchResult> {
            override fun onResponse(
                call: Call<NeshanSearchResult>,
                response: Response<NeshanSearchResult>,
            ) {
                mainHandler.post {
                    if (!response.isSuccessful) {
                        result.error(
                            "neshan_error",
                            "Geocoding failed (${response.code()})",
                            null,
                        )
                        return@post
                    }

                    val items = response.body()?.items
                    if (items.isNullOrEmpty()) {
                        result.error("not_found", "No location found for address", null)
                        return@post
                    }

                    val first = items.first()
                    val location = first.location
                    if (location == null) {
                        result.error("invalid_response", "Invalid geocoding location", null)
                        return@post
                    }

                    result.success(
                        mapOf(
                            "latitude" to location.latitude,
                            "longitude" to location.longitude,
                            "title" to (first.title ?: ""),
                            "address" to (first.address ?: ""),
                        ),
                    )
                }
            }

            override fun onFailure(call: Call<NeshanSearchResult>, t: Throwable) {
                mainHandler.post {
                    result.error("neshan_error", t.message ?: "Geocoding failed", null)
                }
            }
        })
    }

    private fun getRoute(call: MethodCall, result: MethodChannel.Result) {
        val apiKey = call.argument<String>("apiKey")?.trim().orEmpty()
        if (apiKey.isEmpty()) {
            result.error("invalid_argument", "apiKey is required", null)
            return
        }

        val originLat = call.argument<Double>("originLat")
        val originLng = call.argument<Double>("originLng")
        val destLat = call.argument<Double>("destinationLat")
        val destLng = call.argument<Double>("destinationLng")
        val alternative = call.argument<Boolean>("alternative") ?: false
        val avoidTrafficZone = call.argument<Boolean>("avoidTrafficZone") ?: false
        val avoidOddEvenZone = call.argument<Boolean>("avoidOddEvenZone") ?: false

        if (originLat == null || originLng == null || destLat == null || destLng == null) {
            result.error("invalid_argument", "origin and destination are required", null)
            return
        }

        val origin = LatLng(originLat, originLng)
        val destination = LatLng(destLat, destLng)

        val direction = NeshanDirection.Builder(apiKey, origin, destination)
            .setAlternative(alternative)
            .setAvoidTrafficZone(avoidTrafficZone)
            .setAvoidOddEvenZone(avoidOddEvenZone)
            .build()

        val waypointsRaw = call.argument<List<Map<String, Double>>>("waypoints")
        if (!waypointsRaw.isNullOrEmpty()) {
            val waypoints = waypointsRaw.mapNotNull { point ->
                val lat = point["lat"]
                val lng = point["lng"]
                if (lat != null && lng != null) LatLng(lat, lng) else null
            }
            if (waypoints.isNotEmpty()) {
                direction.setWaypoints(ArrayList(waypoints))
            }
        }

        direction.call(object : Callback<NeshanDirectionResult> {
            override fun onResponse(
                call: Call<NeshanDirectionResult>,
                response: Response<NeshanDirectionResult>,
            ) {
                mainHandler.post {
                    if (!response.isSuccessful) {
                        result.error(
                            "neshan_error",
                            "Routing failed (${response.code()})",
                            null,
                        )
                        return@post
                    }

                    val routes = response.body()?.routes
                    if (routes.isNullOrEmpty()) {
                        result.error("not_found", "No route found", null)
                        return@post
                    }

                    val route = routes.first()
                    val legs = route.legs?.map { leg -> legToMap(leg) } ?: emptyList()

                    result.success(
                        mapOf(
                            "overviewPolyline" to (route.overviewPolyline?.encodedPolyline ?: ""),
                            "legs" to legs,
                        ),
                    )
                }
            }

            override fun onFailure(call: Call<NeshanDirectionResult>, t: Throwable) {
                mainHandler.post {
                    result.error("neshan_error", t.message ?: "Routing failed", null)
                }
            }
        })
    }

    private fun legToMap(leg: DirectionResultLeg): Map<String, Any?> {
        val steps = leg.directionSteps?.map { step -> stepToMap(step) } ?: emptyList()
        return mapOf(
            "summary" to (leg.summary ?: ""),
            "distanceText" to (leg.distance?.text ?: ""),
            "distanceMeters" to (leg.distance?.value ?: 0),
            "durationText" to (leg.duration?.text ?: ""),
            "durationSeconds" to (leg.duration?.value ?: 0),
            "steps" to steps,
        )
    }

    private fun stepToMap(step: DirectionStep): Map<String, Any?> {
        val maneuver = step.maneuver
        return mapOf(
            "instruction" to (step.instruction ?: ""),
            "name" to (step.name ?: ""),
            "distanceText" to (step.distance?.text ?: ""),
            "durationText" to (step.duration?.text ?: ""),
            "distanceMeters" to (step.distance?.value ?: 0),
            "durationSeconds" to (step.duration?.value ?: 0),
            "type" to (maneuver?.name ?: ""),
            "polyline" to (step.encodedPolyline ?: ""),
            "startLat" to step.startLocation?.latitude,
            "startLng" to step.startLocation?.longitude,
        )
    }
}
