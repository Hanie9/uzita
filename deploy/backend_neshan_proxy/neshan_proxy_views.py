"""
Django REST proxy for Neshan APIs — add to device-control backend.

Why: service.* keys are scoped to server IP/domain or Android bundle. Mobile apps
should not call api.neshan.org directly; this proxy keeps the key on the server.

Setup:
1. Copy views into your transport app (or import this module).
2. Add URL routes from neshan_proxy_urls.py.
3. Set Liara env: NESHAN_API_KEY=service.xxx
4. In Neshan panel whitelist: device-control.liara.run (and/or server outbound IP).
"""

from __future__ import annotations

import json
import os
from typing import Any

import requests
from django.http import HttpResponse
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated

NESHAN_API_KEY = os.environ.get("NESHAN_API_KEY", "").strip()
# Neshan service keys validate whitelisted domain via Referer on server-side calls.
NESHAN_REFERER = os.environ.get(
    "NESHAN_REFERER", "https://device-control.liara.run/"
).strip()
GEOCODING_URL = "https://api.neshan.org/geocoding/v1/plus"
DIRECTION_URL = "https://api.neshan.org/v4/direction"
DIRECTION_NO_TRAFFIC_URL = "https://api.neshan.org/v4/direction/no-traffic"
DIRECTION_TYPICAL_URL = "https://api.neshan.org/v4/direction/typical"
STATIC_ARC_URL = "https://api.neshan.org/v4/static/arc"
TIMEOUT = 30


def _neshan_headers() -> dict[str, str]:
    headers = {
        "Api-Key": NESHAN_API_KEY,
        "Content-Type": "application/json",
    }
    if NESHAN_REFERER:
        headers["Referer"] = NESHAN_REFERER
    return headers


def _proxy_response(upstream: requests.Response) -> HttpResponse:
    content_type = upstream.headers.get("Content-Type", "application/json")
    return HttpResponse(
        upstream.content,
        status=upstream.status_code,
        content_type=content_type,
    )


def _require_key() -> HttpResponse | None:
    if not NESHAN_API_KEY:
        return HttpResponse(
            json.dumps(
                {
                    "error": "NESHAN_API_KEY is not configured on the server.",
                }
            ),
            status=503,
            content_type="application/json",
        )
    return None


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def neshan_geocode(request) -> HttpResponse:
    missing = _require_key()
    if missing is not None:
        return missing

    raw_json = (request.GET.get("json") or "").strip()
    if raw_json:
        try:
            payload = json.loads(raw_json)
        except json.JSONDecodeError:
            return HttpResponse(
                json.dumps({"error": "invalid json parameter"}),
                status=400,
                content_type="application/json",
            )
    else:
        address = (request.GET.get("address") or "").strip()
        if not address:
            return HttpResponse(
                json.dumps({"error": "address is required"}),
                status=400,
                content_type="application/json",
            )

        payload: dict[str, Any] = {"address": address}
        city = (request.GET.get("city") or "").strip()
        province = (request.GET.get("province") or "").strip()
        if city:
            payload["city"] = city
        if province:
            payload["province"] = province

    if not isinstance(payload, dict) or not (payload.get("address") or "").strip():
        return HttpResponse(
            json.dumps({"error": "address is required"}),
            status=400,
            content_type="application/json",
        )

    params = {"json": json.dumps(payload, ensure_ascii=False)}
    upstream = requests.get(
        GEOCODING_URL,
        params=params,
        headers=_neshan_headers(),
        timeout=TIMEOUT,
    )
    return _proxy_response(upstream)


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def neshan_route(request) -> HttpResponse:
    missing = _require_key()
    if missing is not None:
        return missing

    origin = (request.GET.get("origin") or "").strip()
    destination = (request.GET.get("destination") or "").strip()
    if not origin or not destination:
        return HttpResponse(
            json.dumps({"error": "origin and destination are required"}),
            status=400,
            content_type="application/json",
        )

    params: dict[str, str] = {
        "type": (request.GET.get("type") or "car").strip(),
        "origin": origin,
        "destination": destination,
        "alternative": (request.GET.get("alternative") or "false").strip(),
        "avoidTrafficZone": (request.GET.get("avoidTrafficZone") or "false").strip(),
        "avoidOddEvenZone": (request.GET.get("avoidOddEvenZone") or "false").strip(),
    }

    waypoints = (request.GET.get("waypoints") or "").strip()
    if waypoints:
        params["waypoints"] = waypoints

    bearing = (request.GET.get("bearing") or "").strip()
    if bearing:
        params["bearing"] = bearing

    traffic = (request.GET.get("traffic") or "live").strip().lower()
    if traffic == "none":
        direction_url = DIRECTION_NO_TRAFFIC_URL
    elif traffic == "typical":
        direction_url = DIRECTION_TYPICAL_URL
    else:
        direction_url = DIRECTION_URL

    upstream = requests.get(
        direction_url,
        params=params,
        headers=_neshan_headers(),
        timeout=TIMEOUT,
    )
    return _proxy_response(upstream)


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def neshan_static_arc(request) -> HttpResponse:
    missing = _require_key()
    if missing is not None:
        return missing

    required = ("from", "to", "width", "height")
    query = {k: (request.GET.get(k) or "").strip() for k in required}
    if any(not query[k] for k in required):
        return HttpResponse(
            json.dumps({"error": "from, to, width, height are required"}),
            status=400,
            content_type="application/json",
        )

    params = {
        "key": NESHAN_API_KEY,
        "type": (request.GET.get("map_type") or "dreamy").strip(),
        "from": query["from"],
        "to": query["to"],
        "width": query["width"],
        "height": query["height"],
        "dashed": (request.GET.get("dashed") or "false").strip(),
        "color": (request.GET.get("color") or "%231E3A8A").strip(),
    }
    upstream = requests.get(
        STATIC_ARC_URL,
        params=params,
        headers=_neshan_headers(),
        timeout=TIMEOUT,
    )
    return _proxy_response(upstream)
