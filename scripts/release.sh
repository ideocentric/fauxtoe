#!/bin/sh
# Copyright (C) 2026 Matt Comeione
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Builds a Developer ID signed release of fauxtoe into build/release/: a zip of
# the app, and a disk image holding the app beside a link to /Applications.
#
# Day-to-day builds sign with the project's own team. This script overrides the
# team and identity so the release is signed with "Developer ID Application"
# from team 3722A5T4AG, which needs that certificate and its private key in the
# login keychain.
#
# With NOTARY_PROFILE set to a notarytool keychain profile, the app and then the
# disk image are sent to Apple for notarization and their tickets are stapled.
# Without it, both are only signed, and Gatekeeper will block them on other Macs.
# Create a profile once with:
#   xcrun notarytool store-credentials <profile> --apple-id <id> --team-id 3722A5T4AG
set -eu

cd "$(dirname "$0")/.."
: "${DEVELOPER_DIR:=/Applications/Xcode.app/Contents/Developer}"
export DEVELOPER_DIR

team=3722A5T4AG
identity="Developer ID Application"
out=build/release
archive="$out/fauxtoe.xcarchive"
app="$out/fauxtoe.app"

notarize() {
    xcrun notarytool submit "$1" --keychain-profile "$NOTARY_PROFILE" --wait
}

rm -rf "$out"
mkdir -p "$out"

xcodebuild -quiet -project fauxtoe.xcodeproj -scheme fauxtoe -configuration Release \
    -archivePath "$archive" archive \
    DEVELOPMENT_TEAM="$team" CODE_SIGN_STYLE=Manual \
    CODE_SIGN_IDENTITY="$identity" OTHER_CODE_SIGN_FLAGS=--timestamp

xcodebuild -quiet -exportArchive -archivePath "$archive" -exportPath "$out" \
    -exportOptionsPlist scripts/ExportOptions.plist

codesign --verify --deep --strict "$app"
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")"
zip="$out/fauxtoe-$version.zip"
dmg="$out/fauxtoe-$version.dmg"

# The app is notarized and stapled before it goes into the zip and the disk
# image, so the copy a user drags out opens without a network check.
if [ -n "${NOTARY_PROFILE:-}" ]; then
    ditto -c -k --keepParent "$app" "$out/upload.zip"
    notarize "$out/upload.zip"
    rm "$out/upload.zip"
    xcrun stapler staple "$app"
fi
ditto -c -k --keepParent "$app" "$zip"

staging="$out/dmg"
mkdir "$staging"
ditto "$app" "$staging/fauxtoe.app"
ln -s /Applications "$staging/Applications"
hdiutil create -quiet -volname fauxtoe -srcfolder "$staging" -fs HFS+ \
    -format UDZO -ov "$dmg"
rm -rf "$staging"
codesign --sign "$identity: Matthew Comeione ($team)" --timestamp "$dmg"

if [ -z "${NOTARY_PROFILE:-}" ]; then
    echo "Signed, not notarized: $zip, $dmg"
    exit 0
fi

notarize "$dmg"
xcrun stapler staple "$dmg"
spctl --assess --type execute --verbose=2 "$app"
spctl --assess --type open --context context:primary-signature --verbose=2 "$dmg"
echo "Signed and notarized: $zip, $dmg"
