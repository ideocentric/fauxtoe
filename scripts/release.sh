#!/bin/sh
# Copyright (C) 2026 Matt Comeione
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Builds a Developer ID signed release of fauxtoe into build/release/.
#
# Day-to-day builds sign with the project's own team. This script overrides the
# team and identity so the release is signed with "Developer ID Application"
# from team 3722A5T4AG, which needs that certificate and its private key in the
# login keychain.
#
# With NOTARY_PROFILE set to a notarytool keychain profile, the app is also
# sent to Apple for notarization and the ticket is stapled. Without it, the
# script stops after signing, and Gatekeeper will block the app on other Macs.
# Create a profile once with:
#   xcrun notarytool store-credentials <profile> --apple-id <id> --team-id 3722A5T4AG
set -eu

cd "$(dirname "$0")/.."
: "${DEVELOPER_DIR:=/Applications/Xcode.app/Contents/Developer}"
export DEVELOPER_DIR

team=3722A5T4AG
out=build/release
archive="$out/fauxtoe.xcarchive"
app="$out/fauxtoe.app"

rm -rf "$out"
mkdir -p "$out"

xcodebuild -quiet -project fauxtoe.xcodeproj -scheme fauxtoe -configuration Release \
    -archivePath "$archive" archive \
    DEVELOPMENT_TEAM="$team" CODE_SIGN_STYLE=Manual \
    CODE_SIGN_IDENTITY="Developer ID Application" OTHER_CODE_SIGN_FLAGS=--timestamp

xcodebuild -quiet -exportArchive -archivePath "$archive" -exportPath "$out" \
    -exportOptionsPlist scripts/ExportOptions.plist

codesign --verify --deep --strict "$app"
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")"
zip="$out/fauxtoe-$version.zip"

if [ -z "${NOTARY_PROFILE:-}" ]; then
    ditto -c -k --keepParent "$app" "$zip"
    echo "Signed, not notarized: $zip"
    exit 0
fi

ditto -c -k --keepParent "$app" "$out/upload.zip"
xcrun notarytool submit "$out/upload.zip" --keychain-profile "$NOTARY_PROFILE" --wait
rm "$out/upload.zip"
xcrun stapler staple "$app"
spctl --assess --type execute --verbose=2 "$app"
ditto -c -k --keepParent "$app" "$zip"
echo "Signed and notarized: $zip"
