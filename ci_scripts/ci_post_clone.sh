#!/bin/sh
#
# Xcode Cloud runs this right after cloning, before it resolves the project.
#
# The .xcodeproj is generated from project.yml rather than committed, so a fresh clone has no
# project for Xcode Cloud to build — hence "Project DavidLedger.xcodeproj does not exist at the
# root of the repository". Generating it here gives the build the same project a local
# `xcodegen generate` produces.
set -e

# Homebrew is on the image but not always on PATH for this script's shell, and it sits in a
# different place on Apple silicon than on Intel. Failing here reads as "brew: command not found",
# which says nothing about which of the two is missing.
if ! command -v brew >/dev/null 2>&1; then
  for prefix in /opt/homebrew /usr/local; do
    if [ -x "$prefix/bin/brew" ]; then
      eval "$("$prefix/bin/brew" shellenv)"
      break
    fi
  done
fi

if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew를 찾지 못했습니다. xcodegen 없이는 .xcodeproj를 만들 수 없습니다." >&2
  exit 1
fi

# Auto-update refreshes every formula in the tap before installing one, which on a cold CI image is
# the slowest part of this script by a wide margin and changes nothing about what gets installed.
export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_INSTALL_CLEANUP=1

brew install --quiet xcodegen

cd "$CI_PRIMARY_REPOSITORY_PATH"
xcodegen generate

# Named rather than assumed. When a build fails later with a missing scheme, the question is always
# whether this step ran at all, and the answer belongs in the log where it happened.
echo "생성됨: $(pwd)/DavidLedger.xcodeproj"
xcodebuild -version
xcrun --sdk iphoneos --show-sdk-version
xcrun --sdk iphoneos --show-sdk-build-version
