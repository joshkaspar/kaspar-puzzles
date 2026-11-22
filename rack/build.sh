#!/bin/sh
# Regenerates the daily patches and the page at site/rack/index.html, which
# puzzle-docker copies to /rack/ in the served site.
# Usage: rack/build.sh [--from=YYYY-MM-DD] [--days=N]   (a few minutes for 365 days)
#        rack/build.sh --page-only    reuse build/rack_daily.json, rebuild engine and page
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
dart run bin/page.dart build/engine.js build/rack_daily.json ../site/rack/index.html
echo "wrote site/rack/index.html"
