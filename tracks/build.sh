#!/bin/sh
# Regenerates the daily puzzles and the playtest page at site/tracks/index.html,
# which puzzle-docker copies to /tracks/ in the served site.
# Usage: tracks/build.sh [--from=YYYY-MM-DD] [--days=N]   (a few minutes for 365 days)
set -eu
cd "$(dirname "$0")"
mkdir -p build
dart run bin/pregen.dart --days=365 "$@"
dart run bin/export.dart build/tracks_daily.json build/playtest_data.json
dart run bin/playtest.dart build/playtest_data.json ../site/tracks/index.html
echo "wrote site/tracks/index.html"
