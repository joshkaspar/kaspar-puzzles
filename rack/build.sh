#!/bin/sh
# Regenerates the daily patches and the page at web/rack/index.html, which
# Flutter's web build copies to /rack/ in the served site.
# Usage: tools/rack/build.sh [--from=YYYY-MM-DD] [--days=N]   (a few minutes for 365 days)
#        tools/rack/build.sh --page-only    reuse build/rack_daily.json, rebuild engine and page
set -eu
cd "$(dirname "$0")"
mkdir -p build
dart pub get >/dev/null
(cd engine && dart test)
if [ "${1:-}" = "--page-only" ]; then
  [ -f build/rack_daily.json ] || { echo "no build/rack_daily.json yet; run without --page-only" >&2; exit 1; }
else
  dart run bin/pregen.dart --days=365 "$@"
fi
dart compile js -O2 --no-source-maps -o build/engine.js page/main.dart >/dev/null
dart run bin/page.dart build/engine.js build/rack_daily.json ../../web/rack/index.html
echo "wrote web/rack/index.html"
