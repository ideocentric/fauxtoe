#!/bin/sh
# Copyright (C) 2026 Matt Comeione
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Builds the app and merges every user-facing string in the Swift sources into
# fauxtoe/Localizable.xcstrings. Xcode's editor does this on its own; xcodebuild
# does not, so run this after changing UI text from the command line.
set -eu

cd "$(dirname "$0")/.."
: "${DEVELOPER_DIR:=/Applications/Xcode.app/Contents/Developer}"
export DEVELOPER_DIR

derived="$(mktemp -d)"
trap 'rm -rf "$derived"' EXIT

xcodebuild -quiet -project fauxtoe.xcodeproj -scheme fauxtoe -configuration Debug \
    -derivedDataPath "$derived" build

set --
for file in "$derived"/Build/Intermediates.noindex/fauxtoe.build/Debug/fauxtoe.build/Objects-normal/*/*.stringsdata; do
    set -- "$@" --stringsdata "$file"
done
xcrun xcstringstool sync fauxtoe/Localizable.xcstrings "$@"
echo "Updated fauxtoe/Localizable.xcstrings"
