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
xcodegen generate
