#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

xcodebuild \
  -workspace "$ROOT_DIR/SenovativeOffice.xcworkspace" \
  -scheme SenovativeWrite \
  -configuration Release \
  -arch arm64 \
  -derivedDataPath "$ROOT_DIR/build" \
  build
