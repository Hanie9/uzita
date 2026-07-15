/**
 * Neshan Mapbox GL bridge for Flutter web — mirrors Android NeshanMapPlugin.
 */
(function () {
  'use strict';

  const ROUTE_NESHAN = '#250ECD';
  const TRAFFIC_ORANGE_SMOOTH = '#FF9800';
  const TRAFFIC_RED_HEAVY = '#B71C1C';
  const TRAFFIC_RED_MODERATE = '#F44336';
  const ROUTE_CASING = '#FFFFFF';
  const TRAVELED_GREY = '#9CA3AF';
  const ORIGIN_GREEN = '#16A34A';
  const DESTINATION_ORANGE = '#EA580C';
  const DRIVER_DOT = '#2563EB';

  const NAV_ZOOM = 17.5;
  const NAV_PITCH = 50;
  const NAV_FOCUS_OFFSET = 0.30;
  const OVERVIEW_PITCH = 0;

  const maps = {};
  let eventCallback = null;

  function normalizeBearing(degrees) {
    let value = degrees % 360;
    if (value < 0) value += 360;
    return value;
  }

  function bearingDelta(a, b) {
    let delta = Math.abs(normalizeBearing(a) - normalizeBearing(b));
    if (delta > 180) delta = 360 - delta;
    return delta;
  }

  function trafficColor(level, congested) {
    switch (level) {
      case 'heavy': return TRAFFIC_RED_HEAVY;
      case 'moderate': return TRAFFIC_RED_MODERATE;
      case 'smooth': return TRAFFIC_ORANGE_SMOOTH;
      case 'clear': return ROUTE_NESHAN;
      default: return congested ? TRAFFIC_RED_HEAVY : ROUTE_NESHAN;
    }
  }

  function getSdk() {
    return window.nmp_mapboxgl || window.mapboxgl;
  }

  function ensureSdk() {
    const sdk = getSdk();
    if (!sdk) throw new Error('Neshan map SDK not loaded');
    return sdk;
  }

  function emitEvent(payload) {
    if (typeof eventCallback === 'function') {
      try { eventCallback(payload); } catch (_) {}
    }
  }

  function createDotMarker(color, size) {
    const el = document.createElement('div');
    el.style.width = size + 'px';
    el.style.height = size + 'px';
    el.style.borderRadius = '50%';
    el.style.backgroundColor = color;
    el.style.border = '2px solid white';
    el.style.boxShadow = '0 1px 4px rgba(0,0,0,0.35)';
    return el;
  }

  function createArrowMarker(rotationDeg) {
    const size = 42;
    const el = document.createElement('div');
    el.style.width = size + 'px';
    el.style.height = size + 'px';
    el.style.transform = 'rotate(' + rotationDeg + 'deg)';
    el.innerHTML =
      '<svg viewBox="0 0 48 56" width="' + size + '" height="' + size + '" xmlns="http://www.w3.org/2000/svg">' +
      '<ellipse cx="24" cy="50" rx="14" ry="4" fill="rgba(0,0,0,0.25)"/>' +
      '<ellipse cx="24" cy="44" rx="12" ry="5" fill="#E2E8F0"/>' +
      '<path d="M24 4 L40 40 L8 40 Z" fill="#00D4FF" stroke="white" stroke-width="2.5" stroke-linejoin="round"/>' +
      '</svg>';
    return el;
  }

  function clearRouteLayers(state) {
    const map = state.map;
    if (!map) return;
    (state.layerIds || []).forEach(function (id) {
      if (map.getLayer(id)) map.removeLayer(id);
    });
    (state.sourceIds || []).forEach(function (id) {
      if (map.getSource(id)) map.removeSource(id);
    });
    state.layerIds = [];
    state.sourceIds = [];
  }

  function addLine(map, state, id, coords, color, width) {
    const sourceId = 'uzita-src-' + id;
    const layerId = 'uzita-layer-' + id;
    map.addSource(sourceId, {
      type: 'geojson',
      data: {
        type: 'Feature',
        geometry: { type: 'LineString', coordinates: coords },
      },
    });
    map.addLayer({
      id: layerId,
      type: 'line',
      source: sourceId,
      layout: { 'line-join': 'round', 'line-cap': 'round' },
      paint: { 'line-color': color, 'line-width': width },
    });
    state.sourceIds.push(sourceId);
    state.layerIds.push(layerId);
  }

  function removeDriverMarker(state) {
    if (state.driverMarker) {
      try { state.driverMarker.remove(); } catch (_) {}
      state.driverMarker = null;
    }
  }

  function removeStaticMarkers(state) {
    (state.staticMarkers || []).forEach(function (m) {
      try { m.remove(); } catch (_) {}
    });
    state.staticMarkers = [];
  }

  function setNavPadding(map) {
    const h = map.getContainer().clientHeight || 400;
    map.setPadding({
      top: 0,
      bottom: Math.round(h * NAV_FOCUS_OFFSET),
      left: 0,
      right: 0,
    });
  }

  function clearNavPadding(map) {
    map.setPadding({ top: 0, bottom: 0, left: 0, right: 0 });
  }

  function setupGestureHandlers(state) {
    const map = state.map;
    if (!map || state.gesturesBound) return;
    state.gesturesBound = true;
    state.userGestureNotified = false;

    function onGesture() {
      if (state.suppressGestureEvents) return;
      if (state.navigationFollowEnabled) {
        if (!state.userGestureNotified) {
          state.userGestureNotified = true;
          emitEvent({ type: 'userCameraGesture', viewId: state.viewId });
        }
        state.navigationFollowEnabled = false;
      } else if (state.overviewGesturesEnabled) {
        emitEvent({ type: 'overviewCameraGesture', viewId: state.viewId });
      }
    }

    map.on('dragstart', onGesture);
    map.on('zoomstart', function (e) { if (e.originalEvent) onGesture(); });
    map.on('rotatestart', function (e) { if (e.originalEvent) onGesture(); });
    map.on('pitchstart', function (e) { if (e.originalEvent) onGesture(); });
  }

  window.UzitaNeshanMap = {
    setEventCallback: function (cb) {
      eventCallback = cb;
    },

    createMap: function (viewId, containerId, mapKey, isDark) {
      const sdk = ensureSdk();
      const container = document.getElementById(containerId);
      if (!container) throw new Error('Map container not found: ' + containerId);

      const mapTypes = sdk.Map.mapTypes || {};
      const mapType = isDark
        ? (mapTypes.neshanVectorNight || mapTypes.neshanNight || mapTypes.neshanVector)
        : (mapTypes.neshanVector || mapTypes.standard);

      const map = new sdk.Map({
        container: containerId,
        mapKey: mapKey,
        mapType: mapType,
        zoom: 11,
        pitch: OVERVIEW_PITCH,
        center: [51.389, 35.6892],
        minZoom: 5,
        maxZoom: 21,
        trackResize: true,
        poi: false,
        traffic: true,
      });

      const state = {
        viewId: viewId,
        map: map,
        mapKey: mapKey,
        mapDark: !!isDark,
        navigationFollowEnabled: false,
        overviewGesturesEnabled: false,
        suppressGestureEvents: false,
        lastNavPosition: null,
        lastNavBearing: null,
        lastLockedBearing: null,
        layerIds: [],
        sourceIds: [],
        staticMarkers: [],
        driverMarker: null,
        gesturesBound: false,
        userGestureNotified: false,
      };
      maps[viewId] = state;

      map.on('load', function () {
        setupGestureHandlers(state);
      });

      return true;
    },

    destroyMap: function (viewId) {
      const state = maps[viewId];
      if (!state) return;
      removeDriverMarker(state);
      removeStaticMarkers(state);
      clearRouteLayers(state);
      try { state.map.remove(); } catch (_) {}
      delete maps[viewId];
    },

    moveCamera: function (viewId, params) {
      const state = maps[viewId];
      if (!state || !state.map) return;
      const map = state.map;
      const lat = params.lat || 0;
      const lng = params.lng || 0;
      const zoom = params.zoom || 14;
      const navigation = !!params.navigation;
      const bearing = params.bearing != null ? params.bearing : 0;
      const tilt = params.tilt;

      state.suppressGestureEvents = true;
      if (navigation) {
        state.navigationFollowEnabled = true;
        setNavPadding(map);
        map.easeTo({
          center: [lng, lat],
          zoom: NAV_ZOOM,
          bearing: normalizeBearing(bearing),
          pitch: tilt != null ? (90 - tilt) : NAV_PITCH,
          duration: 0,
        });
      } else {
        clearNavPadding(map);
        map.easeTo({
          center: [lng, lat],
          zoom: zoom,
          bearing: 0,
          pitch: OVERVIEW_PITCH,
          duration: 220,
        });
      }
      setTimeout(function () { state.suppressGestureEvents = false; }, navigation ? 250 : 900);
    },

    beginNavigationCamera: function (viewId, params) {
      const state = maps[viewId];
      if (!state || !state.map) return;
      const map = state.map;
      const lat = params.lat || 0;
      const lng = params.lng || 0;
      const bearing = normalizeBearing(params.bearing || 0);
      const mapDark = !!params.mapDark;

      if (mapDark && !state.mapDark) {
        window.UzitaNeshanMap.setMapStyle(viewId, true);
      }

      state.navigationFollowEnabled = true;
      state.overviewGesturesEnabled = false;
      state.userGestureNotified = false;
      state.lastNavPosition = { lat: lat, lng: lng };
      state.lastNavBearing = bearing;
      state.lastLockedBearing = bearing;
      state.suppressGestureEvents = true;

      setNavPadding(map);
      map.easeTo({
        center: [lng, lat],
        zoom: NAV_ZOOM,
        bearing: bearing,
        pitch: NAV_PITCH,
        duration: 0,
      });
      setTimeout(function () { state.suppressGestureEvents = false; }, 600);
    },

    updateNavigationCamera: function (viewId, params) {
      const state = maps[viewId];
      if (!state || !state.map || !state.navigationFollowEnabled) return;
      const map = state.map;
      const lat = params.lat || 0;
      const lng = params.lng || 0;
      const bearing = normalizeBearing(params.bearing || 0);

      const bearingChanged = state.lastLockedBearing == null ||
        bearingDelta(state.lastLockedBearing, bearing) >= 10;

      state.lastNavPosition = { lat: lat, lng: lng };
      state.lastNavBearing = bearing;
      state.suppressGestureEvents = true;

      const opts = {
        center: [lng, lat],
        zoom: NAV_ZOOM,
        pitch: NAV_PITCH,
        duration: 0,
      };
      if (bearingChanged) {
        opts.bearing = bearing;
        state.lastLockedBearing = bearing;
      }
      map.easeTo(opts);
      setTimeout(function () { state.suppressGestureEvents = false; }, 250);
    },

    setNavigationFollow: function (viewId, enabled) {
      const state = maps[viewId];
      if (!state) return;
      state.navigationFollowEnabled = !!enabled;
      if (enabled) {
        state.userGestureNotified = false;
        const pos = state.lastNavPosition;
        const bearing = state.lastNavBearing;
        if (pos && bearing != null) {
          window.UzitaNeshanMap.updateNavigationCamera(viewId, {
            lat: pos.lat,
            lng: pos.lng,
            bearing: bearing,
          });
        }
      }
    },

    setOverviewGestures: function (viewId, enabled) {
      const state = maps[viewId];
      if (!state || !state.map) return;
      state.overviewGesturesEnabled = !!enabled;
      if (enabled) {
        state.userGestureNotified = false;
        clearNavPadding(state.map);
        state.map.easeTo({ bearing: 0, pitch: OVERVIEW_PITCH, duration: 0 });
      }
    },

    fitBounds: function (viewId, params) {
      const state = maps[viewId];
      if (!state || !state.map || state.navigationFollowEnabled) return;
      const map = state.map;
      const points = params.points || [];
      if (!points.length) return;

      const sdk = ensureSdk();
      const bounds = new sdk.LngLatBounds();
      points.forEach(function (p) {
        bounds.extend([p.lng, p.lat]);
      });

      const overview = !!params.overview;
      const bottomRatio = params.bottomInsetRatio != null ? params.bottomInsetRatio : 0.12;
      const w = map.getContainer().clientWidth || 400;
      const h = map.getContainer().clientHeight || 400;

      state.suppressGestureEvents = true;
      clearNavPadding(map);
      map.fitBounds(bounds, {
        padding: {
          top: overview ? h * 0.14 : h * 0.10,
          bottom: h * bottomRatio,
          left: w * 0.07,
          right: w * 0.07,
        },
        bearing: 0,
        pitch: OVERVIEW_PITCH,
        duration: 400,
        maxZoom: overview ? 14 : 16,
      });
      setTimeout(function () { state.suppressGestureEvents = false; }, 350);
    },

    updateRoute: function (viewId, params) {
      const state = maps[viewId];
      if (!state || !state.map) return;
      const map = state.map;

      const mapDark = !!params.mapDark;
      if (mapDark !== state.mapDark) {
        window.UzitaNeshanMap.setMapStyle(viewId, mapDark);
      }

      clearRouteLayers(state);
      removeStaticMarkers(state);
      removeDriverMarker(state);

      const segments = params.segments || [];
      const traveled = params.traveled || [];
      const navigationMode = params.driver && params.driver.navigationMode;
      const overviewMode = !!params.overviewMode;
      const pickupLeg = !!params.pickupLeg;
      const isOverview = !navigationMode && overviewMode;

      segments.forEach(function (segment, i) {
        const rawPoints = segment.points || [];
        if (rawPoints.length < 2) return;
        const coords = rawPoints.map(function (p) { return [p.lng, p.lat]; });
        const color = trafficColor(segment.trafficLevel, segment.congested);
        const lineWidth = navigationMode ? 12 : 9;
        const casingWidth = lineWidth + 4;
        addLine(map, state, 'casing-' + i, coords, ROUTE_CASING, casingWidth);
        addLine(map, state, 'route-' + i, coords, color, lineWidth);
      });

      if (traveled.length >= 2) {
        const coords = traveled.map(function (p) { return [p.lng, p.lat]; });
        addLine(map, state, 'traveled', coords, TRAVELED_GREY, 7);
      }

      const sdk = ensureSdk();

      if (isOverview) {
        if (!pickupLeg && params.origin) {
          const el = createDotMarker(ORIGIN_GREEN, 34);
          const m = new sdk.Marker({ element: el, anchor: 'center' })
            .setLngLat([params.origin.lng, params.origin.lat])
            .addTo(map);
          state.staticMarkers.push(m);
        }
        if (params.destination) {
          const color = pickupLeg ? ORIGIN_GREEN : DESTINATION_ORANGE;
          const el = createDotMarker(color, 34);
          const m = new sdk.Marker({ element: el, anchor: 'center' })
            .setLngLat([params.destination.lng, params.destination.lat])
            .addTo(map);
          state.staticMarkers.push(m);
        }
      } else if (navigationMode && params.destination) {
        const color = pickupLeg ? ORIGIN_GREEN : DESTINATION_ORANGE;
        const el = createDotMarker(color, 34);
        const m = new sdk.Marker({ element: el, anchor: 'center' })
          .setLngLat([params.destination.lng, params.destination.lat])
          .addTo(map);
        state.staticMarkers.push(m);
      }

      if (params.driver) {
        window.UzitaNeshanMap.updateDriverMarker(viewId, {
          lat: params.driver.lat,
          lng: params.driver.lng,
          bearing: params.driver.bearing,
          navigationMode: navigationMode,
        });
      }
    },

    updateDriverMarker: function (viewId, params) {
      const state = maps[viewId];
      if (!state || !state.map) return;
      const map = state.map;
      const lat = params.lat || 0;
      const lng = params.lng || 0;
      const bearing = params.bearing;
      const navigationMode = !!params.navigationMode;

      if (navigationMode) {
        state.lastNavPosition = { lat: lat, lng: lng };
        if (bearing != null) state.lastNavBearing = bearing;
      }

      removeDriverMarker(state);

      const sdk = ensureSdk();
      let marker;
      if (navigationMode) {
        const mapBearing = map.getBearing();
        const rotation = state.navigationFollowEnabled
          ? 0
          : normalizeBearing((bearing || 0) - mapBearing);
        const el = createArrowMarker(rotation);
        marker = new sdk.Marker({ element: el, anchor: 'center' })
          .setLngLat([lng, lat])
          .addTo(map);
      } else {
        const el = createDotMarker(DRIVER_DOT, 22);
        marker = new sdk.Marker({ element: el, anchor: 'center' })
          .setLngLat([lng, lat])
          .addTo(map);
      }
      state.driverMarker = marker;
    },

    setMapStyle: function (viewId, isDark) {
      const state = maps[viewId];
      if (!state || !state.map) return;
      const sdk = ensureSdk();
      const mapTypes = sdk.Map.mapTypes || {};
      const mapType = isDark
        ? (mapTypes.neshanVectorNight || mapTypes.neshanNight || mapTypes.neshanVector)
        : (mapTypes.neshanVector || mapTypes.standard);
      try {
        if (typeof state.map.setMapType === 'function') {
          state.map.setMapType(mapType);
        } else if (typeof state.map.switchMapType === 'function') {
          state.map.switchMapType(mapType);
        }
      } catch (_) {}
      state.mapDark = !!isDark;
    },
  };
})();
