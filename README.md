# MyWeather 🌦️

A Flutter mobile weather app that aggregates **multiple free weather sources**,
finds you by GPS or by **searching any place name / address**, and renders rich
**animated weather graphics**, hourly/daily **forecast charts**, and
**historical weather** trends. Every data service is independently tunable —
polling interval, rate limits, priority and more.

---

## ✨ Features

### Multiple free weather sources
| Source | API key | Forecast | Historical | Notes |
| --- | --- | --- | --- | --- |
| **Open-Meteo** | ❌ none | ✅ | ✅ (ERA5 archive) | Default primary source, works out of the box |
| **MET Norway (met.no)** | ❌ none | ✅ | — | High quality global model |
| **OpenWeatherMap** | ✅ free key | ✅ | — | 1,000 calls/day free tier |
| **WeatherAPI.com** | ✅ free key | ✅ | ✅ (7 days) | 1M calls/month free tier |

The app runs immediately with no setup using the two key-less sources, and you
can add your own API keys for the others in **Settings → Weather sources**.

Results from all enabled sources are shown side-by-side so you can compare what
each provider predicts, and you choose which one drives the headline values.

### Location
- **GPS** current location (with reverse geocoding to a place name).
- **Search by name or address** using the free Open-Meteo geocoding API.
- Save, reorder and switch between multiple locations.

### Graphics & animations
Fully custom-painted (no heavy assets), reacting to the live condition:
- ☀️ Sun with rotating rays / 🌙 moon + twinkling stars at night
- ☁️ Drifting clouds, 🌫️ rolling fog
- 🌧️ Falling rain, ❄️ swaying snow, ⛈️ lightning flashes
- Sky gradient that matches the weather and day/night

Charts (via `fl_chart`):
- Hourly temperature line + precipitation-probability bars
- Daily forecast with proportional hi/lo range bars
- Historical temperature (max/min/mean) and precipitation totals

### Extensive per-service options
For **each** source independently:
- Enable / disable
- API key (stored locally only)
- **Update interval** (cache freshness window)
- **Max calls per hour** and **per day** (rolling-window rate limits, enforced
  and persisted across restarts)
- **Priority** (which source wins for headline values)
- **Request timeout**
- Live usage counters + reset

Global options: units (temperature, wind, precipitation, pressure), theme
(light/dark/system), animations + reduced-motion, 24-hour clock, primary
source, default history range, automatic refresh.

---

## 🚀 Getting started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) 3.19 or newer.

### 1. Generate the native platform folders
This repository contains the full Dart application (`lib/`), tests and
configuration. Generate the platform-specific projects (Android/iOS/etc.) with
Flutter's tooling — it will **not** overwrite `lib/`, `pubspec.yaml` or `test/`:

```bash
flutter create .
flutter pub get
```

### 2. Add the required permissions

**Android** — in `android/app/src/main/AndroidManifest.xml`, add inside the
`<manifest>` element (above `<application>`):

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
```

**iOS** — in `ios/Runner/Info.plist`, add:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>MyWeather uses your location to show local weather.</string>
```

(A convenience script that performs steps 1–2 lives at `tool/setup.sh`.)

### 3. Run

```bash
flutter run
```

### 4. Test

```bash
flutter test
```

---

## 🏗️ Architecture

```
lib/
├── main.dart                  # Bootstrap: prefs, DI via provider
├── app.dart                   # MaterialApp + theming
├── models/                    # Plain data models + unit conversions
│   ├── weather_condition.dart # WMO / OWM / WeatherAPI code → common condition
│   ├── weather_data.dart      # Current / hourly / daily / historical
│   ├── geo_location.dart
│   ├── units.dart
│   ├── source_config.dart     # Per-source tunables
│   └── app_settings.dart
├── services/
│   ├── weather_source.dart    # Abstract source interface
│   ├── sources/               # One file per provider
│   ├── source_registry.dart
│   ├── weather_repository.dart# Aggregation, caching, rate-limit orchestration
│   ├── rate_limiter.dart      # Persisted rolling-window limiter
│   ├── geocoding_service.dart # Forward + reverse geocoding
│   ├── location_service.dart  # GPS + permissions
│   └── storage_service.dart   # SharedPreferences persistence
├── state/                     # ChangeNotifier controllers
│   ├── settings_controller.dart
│   ├── locations_controller.dart
│   └── weather_controller.dart
├── theme/weather_theme.dart   # Condition → gradient mapping + ThemeData
├── widgets/                   # Reusable UI incl. custom-painted animations
│   ├── weather_animations.dart
│   └── charts/
└── screens/                   # Home, search, locations, historical, settings
```

**Data flow:** UI (screens) → controllers (`provider`) → `WeatherRepository`
→ individual `WeatherSource`s. The repository applies per-source enable flags,
serves from an in-memory cache while data is within the update interval, skips
sources that hit their rate limits or lack an API key, fetches the rest in
parallel, and merges results. All temperatures are stored canonically in
Celsius (and wind in km/h, etc.) and converted only at display time.

---

## 🙏 Attribution
Weather data © [Open-Meteo](https://open-meteo.com) (CC BY 4.0),
[MET Norway](https://met.no) (CC BY 4.0),
[OpenWeatherMap](https://openweathermap.org), and
[WeatherAPI.com](https://www.weatherapi.com). Reverse geocoding by BigDataCloud.

## License
MIT
