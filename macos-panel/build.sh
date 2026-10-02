#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h}"
APP="$ROOT/dist/QuotaDash.app"
CONTENTS="$APP/Contents"

rm -rf "$APP"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"

swiftc -parse-as-library \
  "$ROOT/QuotaDashPanel.swift" \
  -o "$CONTENTS/MacOS/QuotaDashPanel" \
  -framework AppKit \
  -framework Foundation \
  -framework Security \
  -framework SwiftUI \
  -framework Combine

cp "$ROOT/Info.plist" "$CONTENTS/Info.plist"
codesign --force --deep --sign - "$APP" >/dev/null
echo "Built $APP"
