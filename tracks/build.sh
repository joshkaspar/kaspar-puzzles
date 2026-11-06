#!/bin/sh
# Regenerates the daily puzzles and the playtest page at web/tracks/index.html,
# which Flutter's web build copies to /tracks/ in the served site.
# Usage: tools/tracks/build.sh [--from=YYYY-MM-DD] [--days=N]   (about 3 min per 180 days)
set -eu
cd "$(dirname "$0")"
mkdir -p build
dart run bin/pregen.dart --days=365 "$@"
dart run bin/export.dart build/tracks_daily.json build/playtest_data.json
dart run bin/playtest.dart build/playtest_data.json ../../web/tracks/index.html
echo "wrote web/tracks/index.html"
