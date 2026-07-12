#!/usr/bin/env bash
# Bundle libz when the app binary links a non-system zlib install name.
#
# Usage: bundle_zlib_macos.sh <path-to-app-bundle> <main-binary-name>
#   e.g. bundle_zlib_macos.sh ./AAGS.app AAGS

set -euo pipefail

APP_PATH="${1:?usage: $0 <app-bundle> <main-binary-name>}"
APP_BIN_NAME="${2:?usage: $0 <app-bundle> <main-binary-name>}"

MAIN_BIN="$APP_PATH/Contents/MacOS/$APP_BIN_NAME"
FRAMEWORKS_DIR="$APP_PATH/Contents/Frameworks"
BUNDLED_ZLIB="$FRAMEWORKS_DIR/libz.1.dylib"
ZLIB_ID="@rpath/libz.1.dylib"

if [ ! -f "$MAIN_BIN" ]; then
    echo "bundle_zlib_macos: missing app binary at $MAIN_BIN"
    exit 1
fi

zlib_dep="$(otool -L "$MAIN_BIN" | awk '
    NR > 1 {
        dep=$1
        if (dep ~ /(^|\/)libz\.1\.dylib$/) {
            print dep
            exit
        }
    }')"

if [ -z "$zlib_dep" ]; then
    echo "bundle_zlib_macos: app does not link libz.1.dylib, skipping"
    exit 0
fi

if [[ "$zlib_dep" == /usr/lib/* || "$zlib_dep" == /System/* ]]; then
    echo "bundle_zlib_macos: using system zlib ($zlib_dep), skipping"
    exit 0
fi

zlib_candidates=()

if [ -n "${QGC_ZLIB_DYLIB:-}" ]; then
    zlib_candidates+=("$QGC_ZLIB_DYLIB")
fi

if [[ "$zlib_dep" == /* ]]; then
    zlib_candidates+=("$zlib_dep")
fi

if command -v brew >/dev/null 2>&1; then
    brew_zlib_prefix="$(brew --prefix zlib 2>/dev/null || true)"
    if [ -n "$brew_zlib_prefix" ]; then
        zlib_candidates+=("$brew_zlib_prefix/lib/libz.1.dylib")
    fi
fi

zlib_candidates+=(
    "/opt/homebrew/opt/zlib/lib/libz.1.dylib"
    "/usr/local/opt/zlib/lib/libz.1.dylib"
)

zlib_source=""
for candidate in "${zlib_candidates[@]}"; do
    if [ -n "$candidate" ] && [ -f "$candidate" ]; then
        zlib_source="$candidate"
        break
    fi
done

if [ -z "$zlib_source" ]; then
    echo "bundle_zlib_macos: unable to locate libz.1.dylib for $zlib_dep"
    echo "bundle_zlib_macos: set QGC_ZLIB_DYLIB to the full libz.1.dylib path if zlib is installed outside Homebrew"
    exit 1
fi

mkdir -p "$FRAMEWORKS_DIR"
cp -f "$zlib_source" "$BUNDLED_ZLIB"
chmod u+w "$BUNDLED_ZLIB"
install_name_tool -id "$ZLIB_ID" "$BUNDLED_ZLIB"

if [ "$zlib_dep" != "$ZLIB_ID" ]; then
    install_name_tool -change "$zlib_dep" "$ZLIB_ID" "$MAIN_BIN"
fi

# Ad-hoc sign only the dylib we modified. Avoid --deep re-signing the whole app.
codesign --force --sign - --preserve-metadata=entitlements,requirements,flags,runtime "$BUNDLED_ZLIB" 2>/dev/null \
    || codesign --force --sign - "$BUNDLED_ZLIB" 2>/dev/null \
    || true

echo "bundle_zlib_macos: bundled $zlib_source"
