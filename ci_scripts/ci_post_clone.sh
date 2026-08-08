#!/bin/sh
#
# Xcode Cloud runs this right after cloning, before it resolves the project.
#
# The .xcodeproj is generated from project.yml rather than committed, so a fresh clone has no
# project for Xcode Cloud to build — hence "Project DavidLedger.xcodeproj does not exist at the
# root of the repository". Generating it here gives the build the same project a local
# `xcodegen generate` produces.
set -e

brew install xcodegen

cd "$CI_PRIMARY_REPOSITORY_PATH"

# App Store Connect refuses a build number it has already accepted, and project.yml carries a
# constant "1" — the number 1.0.0 went up with. Nothing here replaces it the way the fastlane beta
# lane substitutes a timestamp, so every Xcode Cloud run re-uploads build 1 and dies at "Preparing
# build for App Store Connect", after the archive has already succeeded.
#
# CI_BUILD_NUMBER would be the obvious source, but it counts workflow runs from 1 and would collide
# with what is already up there. A UTC timestamp is always larger than the last one, needs nothing
# checked in, and matches what the lane does — the two paths produce comparable numbers.
#
# project.yml is rewritten rather than the generated project, because the project does not exist
# yet; xcodegen runs on the file below.
build_number=$(date -u +%Y%m%d%H%M)
sed -e "s/^\([[:space:]]*CURRENT_PROJECT_VERSION:[[:space:]]*\).*/\1\"${build_number}\"/" \
    project.yml > project.yml.tmp
mv project.yml.tmp project.yml

# A silent no-op here would archive as build 1 again and fail the same way, so the substitution is
# checked rather than assumed.
if ! grep -q "CURRENT_PROJECT_VERSION: \"${build_number}\"" project.yml; then
    echo "error: could not set CURRENT_PROJECT_VERSION in project.yml — the key moved or changed shape" >&2
    exit 1
fi
echo "note: archiving as build ${build_number}"

xcodegen generate
