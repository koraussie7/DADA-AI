"""OSM Location Services — Nominatim Geocoding & Overpass POI proxy.

No API key required. Uses OpenStreetMap data.
"""

import os
import logging
from typing import Optional

import httpx
from fastapi import APIRouter, HTTPException, Query
from pydantic import BaseModel

logger = logging.getLogger("location_osm")

router = APIRouter(tags=["location_osm"])

NOMINATIM_BASE = "https://nominatim.openstreetmap.org"
OVERPAY_BASE = "https://overpass-api.de/api/interpreter"
USER_AGENT = "DADA-AI/1.0"


class GeocodeResult(BaseModel):
    lat: float
    lng: float
    display_name: str
    osm_id: int
    osm_type: str


class PlaceResult(BaseModel):
    osm_id: int
    name: str
    address: str
    lat: float
    lng: float
    type: str
    category: str
    distance: float


# ── Geocode (Nominatim) ──

@router.get("/osm/geocode")
async def geocode(
    q: str = Query(..., description="Address or place name to geocode"),
    limit: int = Query(5, ge=1, le=20),
):
    """Geocode an address or place name using Nominatim."""
    async with httpx.AsyncClient() as client:
        resp = await client.get(
            f"{NOMINATIM_BASE}/search",
            params={"q": q, "format": "json", "limit": limit, "addressdetails": 1},
            headers={"User-Agent": USER_AGENT},
            timeout=10,
        )
        resp.raise_for_status()
        data = resp.json()
        return [
            GeocodeResult(
                lat=float(item["lat"]),
                lng=float(item["lon"]),
                display_name=item["display_name"],
                osm_id=item["osm_id"],
                osm_type=item.get("osm_type", ""),
            )
            for item in data
        ]


@router.get("/osm/reverse")
async def reverse_geocode(
    lat: float = Query(..., description="Latitude"),
    lng: float = Query(..., description="Longitude"),
):
    """Reverse geocode coordinates to an address using Nominatim."""
    async with httpx.AsyncClient() as client:
        resp = await client.get(
            f"{NOMINATIM_BASE}/reverse",
            params={"lat": lat, "lon": lng, "format": "json", "addressdetails": 1},
            headers={"User-Agent": USER_AGENT},
            timeout=10,
        )
        resp.raise_for_status()
        data = resp.json()
        return GeocodeResult(
            lat=float(data["lat"]),
            lng=float(data["lon"]),
            display_name=data.get("display_name", ""),
            osm_id=data.get("osm_id", 0),
            osm_type=data.get("osm_type", ""),
        )


@router.get("/osm/nearby")
async def nearby_places(
    lat: float = Query(..., description="Latitude"),
    lng: float = Query(..., description="Longitude"),
    radius: float = Query(1000, ge=100, le=50000, description="Search radius in meters"),
    types: Optional[str] = Query(None, description="Comma-separated OSM tags (e.g. restaurant,cafe,bar)"),
):
    """Find nearby places using Overpass API."""
    radius_deg = radius / 111000.0  # approximate

    tag_filter = ""
    if types:
        tags = [t.strip() for t in types.split(",") if t.strip()]
        tag_parts = []
        for t in tags:
            tag_parts.append(f'(node["amenity"="{t}"](around:{radius},{lat},{lng});)')
            tag_parts.append(f'(way["amenity"="{t}"](around:{radius},{lat},{lng});)')
        tag_filter = "(\n" + "\n".join(tag_parts) + "\n);"

    overpass_query = f"""
    [out:json][timeout:25];
    (
      node(around:{radius},{lat},{lng})["amenity"];
      way(around:{radius},{lat},{lng})["amenity"];
      {tag_filter}
    );
    out body;
    >;
    out skel qt;
    """

    async with httpx.AsyncClient() as client:
        resp = await client.post(
            OVERPAY_BASE,
            data={"data": overpass_query},
            headers={"User-Agent": USER_AGENT},
            timeout=30,
        )
        resp.raise_for_status()
        data = resp.json()

    results = []
    for elem in data.get("elements", []):
        tags = elem.get("tags", {})
        name = tags.get("name", tags.get("amenity", "Unknown"))
        address = ", ".join(
            filter(None, [
                tags.get("addr:street", ""),
                tags.get("addr:city", ""),
                tags.get("addr:country", ""),
            ])
        )
        results.append(PlaceResult(
            osm_id=elem.get("id", 0),
            name=name,
            address=address or tags.get("display_name", ""),
            lat=elem.get("lat", elem.get("center", {}).get("lat", 0)),
            lng=elem.get("lon", elem.get("center", {}).get("lon", 0)),
            type=tags.get("amenity", ""),
            category=tags.get("shop", tags.get("leisure", "")),
            distance=0.0,
        ))

    return results[:50]


# ── Flutter-compatible POST endpoints ──
# These match the API paths expected by OsmLocationService & LocationSearchWidget.

from pydantic import BaseModel as PydanticBase

class SearchRequest(PydanticBase):
    query: str
    limit: int = 5

class GeocodeRequest(PydanticBase):
    address: str

class ReverseGeocodeRequest(PydanticBase):
    lat: float
    lng: float

class NearbyRequest(PydanticBase):
    lat: float
    lng: float
    radius: int = 1500
    type: str = "restaurant"

class SearchResult(PydanticBase):
    osm_id: int
    display_name: str
    lat: float
    lng: float
    place_id: str = ""
    main_text: str = ""
    secondary_text: str = ""

class NearbyResponse(PydanticBase):
    results: list[PlaceResult]


@router.post("/api/location-osm/search")
async def osm_search(req: SearchRequest):
    """Text search via Nominatim (POST version for Flutter)."""
    async with httpx.AsyncClient() as client:
        resp = await client.get(
            f"{NOMINATIM_BASE}/search",
            params={"q": req.query, "format": "json", "limit": req.limit, "addressdetails": 1},
            headers={"User-Agent": USER_AGENT},
            timeout=10,
        )
        resp.raise_for_status()
        data = resp.json()
        return {
            "predictions": [
                {
                    "osm_id": item["osm_id"],
                    "display_name": item["display_name"],
                    "lat": float(item["lat"]),
                    "lng": float(item["lon"]),
                    "place_id": str(item["osm_id"]),
                    "main_text": item.get("address", {}).get("road", "")
                                 or item.get("address", {}).get("city", "")
                                 or item["display_name"].split(",")[0],
                    "secondary_text": ", ".join(
                        filter(None, [
                            item.get("address", {}).get("city", ""),
                            item.get("address", {}).get("country", ""),
                        ])
                    ) or item["display_name"],
                }
                for item in data
            ]
        }


@router.post("/api/location-osm/geocode")
async def osm_geocode(req: GeocodeRequest):
    """Geocode via Nominatim (POST version for Flutter)."""
    async with httpx.AsyncClient() as client:
        resp = await client.get(
            f"{NOMINATIM_BASE}/search",
            params={"q": req.address, "format": "json", "limit": 1, "addressdetails": 1},
            headers={"User-Agent": USER_AGENT},
            timeout=10,
        )
        resp.raise_for_status()
        data = resp.json()
        if not data:
            raise HTTPException(status_code=404, detail="Address not found")
        item = data[0]
        return {
            "formatted_address": item["display_name"],
            "lat": float(item["lat"]),
            "lng": float(item["lon"]),
            "place_id": str(item["osm_id"]),
        }


@router.post("/api/location-osm/reverse")
async def osm_reverse_geocode(req: ReverseGeocodeRequest):
    """Reverse geocode via Nominatim (POST version for Flutter)."""
    async with httpx.AsyncClient() as client:
        resp = await client.get(
            f"{NOMINATIM_BASE}/reverse",
            params={"lat": req.lat, "lon": req.lng, "format": "json", "addressdetails": 1},
            headers={"User-Agent": USER_AGENT},
            timeout=10,
        )
        resp.raise_for_status()
        data = resp.json()
        return {
            "formatted_address": data.get("display_name", ""),
            "lat": float(data["lat"]),
            "lng": float(data["lon"]),
            "place_id": str(data.get("osm_id", 0)),
        }


@router.post("/api/location-osm/nearby")
async def osm_nearby(req: NearbyRequest):
    """Nearby places via Overpass (POST version for Flutter OsmLocationService)."""
    # Map Flutter type to OSM amenity tag
    type_map = {
        "restaurant": "restaurant|fast_food|food_court",
        "hotel": "hotel|hostel|motel|guest_house",
        "spa": "spa",
        "cafe": "cafe",
        "bar": "bar|pub|nightclub",
        "gym": "fitness_centre|gym",
        "hospital": "hospital|clinic|doctors",
        "park": "park|garden",
        "pharmacy": "pharmacy",
    }
    osm_amenity = type_map.get(req.type, req.type)

    overpass_query = f"""
    [out:json][timeout:25];
    (
      node["amenity"~"{osm_amenity}"](around:{req.radius},{req.lat},{req.lng});
      way["amenity"~"{osm_amenity}"](around:{req.radius},{req.lat},{req.lng});
    );
    out center 25;
    """

    async with httpx.AsyncClient() as client:
        resp = await client.post(
            OVERPAY_BASE,
            data={"data": overpass_query},
            headers={"User-Agent": USER_AGENT},
            timeout=30,
        )
        resp.raise_for_status()
        data = resp.json()

    results = []
    for elem in data.get("elements", []):
        tags = elem.get("tags", {})
        name = tags.get("name", tags.get("amenity", "Unknown"))
        address_parts = list(filter(None, [
            tags.get("addr:street", ""),
            tags.get("addr:housenumber", ""),
            tags.get("addr:city", ""),
        ]))
        el_lat = elem.get("lat") or elem.get("center", {}).get("lat", 0)
        el_lon = elem.get("lon") or elem.get("center", {}).get("lon", 0)
        results.append({
            "osm_id": elem.get("id", 0),
            "name": name,
            "address": ", ".join(address_parts),
            "lat": float(el_lat) if el_lat else 0.0,
            "lng": float(el_lon) if el_lon else 0.0,
            "type": elem.get("type", "node"),
            "category": tags.get("amenity", ""),
            "distance": 0.0,
        })

    return {"results": results[:40]}
