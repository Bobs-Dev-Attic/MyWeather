#!/usr/bin/env bash
# Builds the Flutter web release on Vercel (or any Linux CI).
#
# Installs a full stable Flutter SDK (full clone so the version resolves and
# `git` doesn't complain), then builds to build/web.
set -euo pipefail

FLUTTER_HOME="$PWD/_flutter"

if [ ! -x "$FLUTTER_HOME/bin/flutter" ]; then
  echo "==> Cloning Flutter (stable channel)…"
  git clone https://github.com/flutter/flutter.git -b stable "$FLUTTER_HOME"
fi

# Flutter runs git against its own SDK to determine the version; on CI the
# checkout can be owned by a different uid, which trips git's ownership guard.
git config --global --add safe.directory "$FLUTTER_HOME" || true

export PATH="$FLUTTER_HOME/bin:$PATH"

echo "==> Flutter toolchain"
flutter --version

echo "==> Enabling web support and fetching packages"
flutter config --no-analytics --enable-web
flutter pub get

echo "==> Building web release"
flutter build web --release --no-tree-shake-icons

echo "==> Done. Output:"
ls -la build/web
