"""Add these paths to your Django urlpatterns (under /api/)."""

from django.urls import path

from .neshan_proxy_views import neshan_geocode, neshan_route, neshan_search, neshan_static_arc

urlpatterns = [
    path("transport/neshan/geocode", neshan_geocode, name="neshan-geocode"),
    path("transport/neshan/search", neshan_search, name="neshan-search"),
    path("transport/neshan/route", neshan_route, name="neshan-route"),
    path("transport/neshan/static-arc", neshan_static_arc, name="neshan-static-arc"),
]
