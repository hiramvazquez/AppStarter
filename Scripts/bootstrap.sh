#!/bin/bash
# Bootstraps AppStarter locally: regenerates AppStarter.xcodeproj (never versioned) from
# project.yml with xcodegen. Run this after cloning, and again any time project.yml or a
# target's file layout changes.
set -euo pipefail

cd "$(dirname "$0")/.."

if ! command -v xcodegen >/dev/null 2>&1; then
    echo "xcodegen no está instalado. Instálalo con: brew install xcodegen" >&2
    exit 1
fi

echo "==> xcodegen generate"
xcodegen generate

echo "==> AppStarter.xcodeproj generado. Abre AppStarter.xcodeproj o ejecuta:"
echo "    xcodebuild test -scheme AppStarter -destination 'platform=iOS Simulator,name=iPhone 17 Pro'"
