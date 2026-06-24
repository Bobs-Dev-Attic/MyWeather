#!/usr/bin/env bash
# Generates the native platform projects and wires up the permissions MyWeather
# needs (location + internet). Safe to re-run; it will not touch lib/ or tests.
set -euo pipefail

cd "$(dirname "$0")/.."

echo "==> Generating platform folders (flutter create .)"
flutter create .

echo "==> Fetching packages"
flutter pub get

MANIFEST="android/app/src/main/AndroidManifest.xml"
if [[ -f "$MANIFEST" ]] && ! grep -q "ACCESS_FINE_LOCATION" "$MANIFEST"; then
  echo "==> Adding Android permissions to $MANIFEST"
  # Insert permissions right after the opening <manifest ...> tag.
  perl -0pi -e 's/(<manifest[^>]*>)/$1\n    <uses-permission android:name="android.permission.INTERNET"\/>\n    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"\/>\n    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"\/>/' "$MANIFEST"
fi

PLIST="ios/Runner/Info.plist"
if [[ -f "$PLIST" ]] && ! grep -q "NSLocationWhenInUseUsageDescription" "$PLIST"; then
  echo "==> Adding iOS location usage description to $PLIST"
  perl -0pi -e 's/(<dict>)/$1\n\t<key>NSLocationWhenInUseUsageDescription<\/key>\n\t<string>MyWeather uses your location to show local weather.<\/string>/' "$PLIST"
fi

echo "==> Done. Run 'flutter run' to launch the app."
