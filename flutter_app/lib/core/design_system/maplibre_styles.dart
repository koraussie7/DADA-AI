// lib/core/design_system/maplibre_styles.dart
/// MapLibre GL style definitions — custom vector tile styles for DADA-AI.
///
/// Provides built‑in dark/light styles that match the DADA-AI design system
/// and helpers to load custom vector style JSON at runtime.
library;

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

// ──────────────────────────────────────────────
// 1.  OpenFreeMap – free vector tiles, no key
// ──────────────────────────────────────────────

/// OpenFreeMap Liberty style (bright, OSM‑based).
const String kStyleOpenFreeMap = 'https://tiles.openfreemap.org/styles/liberty';

/// OpenFreeMap Dark style (experimental).
const String kStyleOpenFreeMapDark = 'https://tiles.openfreemap.org/styles/dark';

/// MapTiler Streets (requires a free API key from https://cloud.maptiler.com).
/// Replace `YOUR_KEY` with your actual key.
const String kStyleMapTilerStreets =
    'https://api.maptiler.com/maps/streets-v2/style.json?key=YOUR_KEY';

/// MapTiler Dark (requires API key).
const String kStyleMapTilerDark =
    'https://api.maptiler.com/maps/dark/style.json?key=YOUR_KEY';

/// Default map style used by the app (OpenFreeMap Liberty).
const String kDefaultStyleUrl = kStyleOpenFreeMap;

// ──────────────────────────────────────────────
// 2.  Custom DADA-AI Dark Style JSON (embedded)
// ──────────────────────────────────────────────

/// Custom vector style JSON that matches DADA-AI's dark design system.
///
/// Colors:
///   background   #020617  (scaffold background)
///   surface      #0F172A  (card / surface)
///   primary      #F02C56  (accent red)
///   text muted   #64748B
///
/// Uses OpenFreeMap vector tile source (no API key required).
const String kDadaDarkStyleRaw = '''
{
  "version": 8,
  "name": "DADA Dark Custom",
  "sources": {
    "osm": {
      "type": "vector",
      "url": "https://tiles.openfreemap.org/tiles/tiles.json"
    }
  },
  "glyphs": "https://fonts.openmaptiles.org/{fontstack}/{range}.pbf",
  "layers": [
    { "id": "background", "type": "background", "paint": { "background-color": "#020617" } },
    {
      "id": "landuse",
      "type": "fill",
      "source": "osm",
      "source-layer": "landuse",
      "paint": { "fill-color": "#0F172A" },
      "filter": ["!=", ["get", "class"], "wood"]
    },
    {
      "id": "landuse-wood",
      "type": "fill",
      "source": "osm",
      "source-layer": "landuse",
      "paint": { "fill-color": "#0A0F1E" },
      "filter": ["==", ["get", "class"], "wood"]
    },
    {
      "id": "water",
      "type": "fill",
      "source": "osm",
      "source-layer": "water",
      "paint": { "fill-color": "#1E293B" }
    },
    {
      "id": "water-name",
      "type": "symbol",
      "source": "osm",
      "source-layer": "water_name",
      "paint": { "text-color": "#64748B" },
      "layout": {
        "text-field": "{name:latin}\\n{name:nonlatin}",
        "text-font": ["Noto Sans Regular"],
        "text-size": 10
      }
    },
    {
      "id": "building",
      "type": "fill",
      "source": "osm",
      "source-layer": "building",
      "paint": {
        "fill-color": "#1E293B",
        "fill-opacity": 0.6
      }
    },
    {
      "id": "road-secondary-tertiary",
      "type": "line",
      "source": "osm",
      "source-layer": "transportation",
      "paint": {
        "line-color": "#334155",
        "line-width": 1.5
      },
      "filter": ["in", ["get", "class"], "secondary", "tertiary"]
    },
    {
      "id": "road-primary",
      "type": "line",
      "source": "osm",
      "source-layer": "transportation",
      "paint": {
        "line-color": "#475569",
        "line-width": 2
      },
      "filter": ["==", ["get", "class"], "primary"]
    },
    {
      "id": "road-motorway",
      "type": "line",
      "source": "osm",
      "source-layer": "transportation",
      "paint": {
        "line-color": "#F02C56",
        "line-width": 2,
        "line-opacity": 0.5
      },
      "filter": ["==", ["get", "class"], "motorway"]
    },
    {
      "id": "road-street",
      "type": "line",
      "source": "osm",
      "source-layer": "transportation",
      "paint": {
        "line-color": "#1E293B",
        "line-width": 1
      },
      "filter": ["==", ["get", "class"], "street"]
    },
    {
      "id": "road-path",
      "type": "line",
      "source": "osm",
      "source-layer": "transportation",
      "paint": {
        "line-color": "#1E293B",
        "line-width": 0.8,
        "line-dasharray": [1, 2]
      },
      "filter": ["==", ["get", "class"], "path"]
    },
    {
      "id": "place-label",
      "type": "symbol",
      "source": "osm",
      "source-layer": "place",
      "paint": {
        "text-color": "#94A3B8",
        "text-halo-color": "#020617",
        "text-halo-width": 1
      },
      "layout": {
        "text-field": "{name:latin}\\n{name:nonlatin}",
        "text-font": ["Noto Sans Regular"],
        "text-size": 12
      }
    },
    {
      "id": "poi-label",
      "type": "symbol",
      "source": "osm",
      "source-layer": "poi",
      "paint": {
        "text-color": "#64748B",
        "text-halo-color": "#020617",
        "text-halo-width": 1
      },
      "layout": {
        "text-field": "{name:latin}",
        "text-font": ["Noto Sans Regular"],
        "text-size": 10
      }
    }
  ]
}
''';

/// Custom vector style JSON matching DADA-AI's light theme.
const String kDadaLightStyleRaw = '''
{
  "version": 8,
  "name": "DADA Light Custom",
  "sources": {
    "osm": {
      "type": "vector",
      "url": "https://tiles.openfreemap.org/tiles/tiles.json"
    }
  },
  "glyphs": "https://fonts.openmaptiles.org/{fontstack}/{range}.pbf",
  "layers": [
    { "id": "background", "type": "background", "paint": { "background-color": "#F8F9FA" } },
    {
      "id": "landuse",
      "type": "fill",
      "source": "osm",
      "source-layer": "landuse",
      "paint": { "fill-color": "#E8ECEF" }
    },
    {
      "id": "water",
      "type": "fill",
      "source": "osm",
      "source-layer": "water",
      "paint": { "fill-color": "#CDD6E4" }
    },
    {
      "id": "building",
      "type": "fill",
      "source": "osm",
      "source-layer": "building",
      "paint": { "fill-color": "#D1D5DB" }
    },
    {
      "id": "road-secondary-tertiary",
      "type": "line",
      "source": "osm",
      "source-layer": "transportation",
      "paint": { "line-color": "#FFFFFF", "line-width": 1.5 },
      "filter": ["in", ["get", "class"], "secondary", "tertiary"]
    },
    {
      "id": "road-primary",
      "type": "line",
      "source": "osm",
      "source-layer": "transportation",
      "paint": { "line-color": "#F1F5F9", "line-width": 2 },
      "filter": ["==", ["get", "class"], "primary"]
    },
    {
      "id": "road-motorway",
      "type": "line",
      "source": "osm",
      "source-layer": "transportation",
      "paint": { "line-color": "#F02C56", "line-width": 2, "line-opacity": 0.4 },
      "filter": ["==", ["get", "class"], "motorway"]
    },
    {
      "id": "place-label",
      "type": "symbol",
      "source": "osm",
      "source-layer": "place",
      "paint": { "text-color": "#334155", "text-halo-color": "#F8F9FA", "text-halo-width": 1 },
      "layout": {
        "text-field": "{name:latin}\\n{name:nonlatin}",
        "text-font": ["Noto Sans Regular"],
        "text-size": 12
      }
    }
  ]
}
''';

// ──────────────────────────────────────────────
// 3.  Helpers
// ──────────────────────────────────────────────

/// Predefined style configurations.
enum MapLibreStyle {
  /// OpenFreeMap Liberty (bright, default).
  openFreeMap,

  /// OpenFreeMap Dark.
  openFreeMapDark,

  /// Custom DADA-AI dark vector style (embedded JSON).
  dadaDark,

  /// Custom DADA-AI light vector style (embedded JSON).
  dadaLight,
}

/// Returns the style URL or file URI for a given [style].
String styleUri(MapLibreStyle style) {
  switch (style) {
    case MapLibreStyle.openFreeMap:
      return kStyleOpenFreeMap;
    case MapLibreStyle.openFreeMapDark:
      return kStyleOpenFreeMapDark;
    case MapLibreStyle.dadaDark:
      return kDadaDarkStyleRaw;
    case MapLibreStyle.dadaLight:
      return kDadaLightStyleRaw;
  }
}

/// Writes a raw style JSON string to a temporary file inside the app's
/// documents directory and returns the `file://` URI.
///
/// This is necessary because `maplibre_gl` cannot load a raw JSON string
/// directly; it requires a URL or file path.
Future<String> writeStyleToFile(String rawJson, {String filename = 'dada_style.json'}) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$filename');
  // Pretty-print for debugging
  final encoder = const JsonEncoder.withIndent('  ');
  final pretty = encoder.convert(jsonDecode(rawJson));
  await file.writeAsString(pretty);
  debugPrint('[MapLibreStyle] wrote style to ${file.path}');
  return 'file://${file.path}';
}

/// Convenience: resolves a [MapLibreStyle] to a loadable URI.
/// Embedded JSON styles are written to a temp file; URL styles returned as-is.
Future<String> resolveStyleUri(MapLibreStyle style) async {
  final uri = styleUri(style);
  if (uri.startsWith('http://') || uri.startsWith('https://') || uri.startsWith('file://')) {
    return uri;
  }
  // Assume it's raw JSON → write to file
  return writeStyleToFile(uri);
}
