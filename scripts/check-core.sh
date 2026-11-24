#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
build_dir="$(mktemp -d)"
trap 'rm -rf "$build_dir"' EXIT

swiftc \
  Sources/Core/Theme/ThemeProfile.swift \
  Sources/Core/Media/VoiceWaveform.swift \
  Tests/CoreChecks.swift \
  -o "$build_dir/whogram-core-checks"
"$build_dir/whogram-core-checks"
