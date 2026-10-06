#!/bin/sh
# Copyright (C) 2026 Matt Comeione
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Renders docs/user-manual.md to a PDF: pandoc turns it into HTML, and
# Playwright's bundled Chromium prints that to Letter-size pages.
#
#   scripts/render-manual.sh <version> <out.pdf>
#
# Refuses to run unless the manual's "Version" line matches <version>, so a
# release can't ship last version's manual.
#
# Needs pandoc and node. Playwright is installed into build/manual-tools, pinned
# to a version whose Chromium is already in ~/Library/Caches/ms-playwright, so
# no browser is downloaded. If that build is missing, raise or lower
# PLAYWRIGHT_VERSION until `require('playwright').chromium.executablePath()`
# names a file that exists.
set -eu

cd "$(dirname "$0")/.."
root="$(pwd)"
version="$1"
case "$2" in
    /*) out="$2" ;;
    *) out="$root/$2" ;;
esac
manual=docs/user-manual.md
tools=build/manual-tools
: "${PLAYWRIGHT_VERSION:=1.60.0}"

if ! grep -qx "Version $version" "$manual"; then
    echo "error: $manual does not say \"Version $version\"; update it for this release" >&2
    exit 1
fi

if [ ! -d "$tools/node_modules/playwright" ]; then
    mkdir -p "$tools"
    (cd "$tools" && npm init -y >/dev/null &&
        PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 npm install --silent "playwright@$PLAYWRIGHT_VERSION")
fi
(cd "$tools" && node -e "
const path = require('playwright').chromium.executablePath();
if (!require('fs').existsSync(path)) { console.error('error: no Chromium at ' + path); process.exit(1); }")

html="$root/$tools/user-manual.html"
pandoc -f gfm -t html5 -s --metadata pagetitle="fauxtoe User Manual" \
    --css scripts/manual/manual.css --embed-resources "$manual" -o "$html"
mkdir -p "$(dirname "$out")"
NODE_PATH="$root/$tools/node_modules" node scripts/manual/render.js "$html" "$out" "$version"
echo "Rendered $out"
