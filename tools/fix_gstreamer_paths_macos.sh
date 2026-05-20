#!/usr/bin/env bash
# Rewrite every /Library/Frameworks/GStreamer.framework/... reference inside a
# QGroundControl-style macOS .app bundle to @executable_path/../Frameworks/...
# so customers don't need a system-wide GStreamer install.
#
# The existing install step rsyncs GStreamer.framework into the bundle but only
# rewrites the one direct reference in the main app binary. Transitive deps
# (libz, libavcodec, etc. and every internal cross-reference inside the bundled
# GStreamer dylibs) still point at the build-machine path. This script walks
# the bundled framework and rewrites them all, then ad-hoc-signs each modified
# binary so it remains loadable on macOS 11+.
#
# Usage: fix_gstreamer_paths_macos.sh <path-to-app-bundle> <main-binary-name>
#   e.g. fix_gstreamer_paths_macos.sh ./AAGS.app AAGS

set -euo pipefail

APP_PATH="${1:?usage: $0 <app-bundle> <main-binary-name>}"
APP_BIN_NAME="${2:?usage: $0 <app-bundle> <main-binary-name>}"

OLD="/Library/Frameworks/GStreamer.framework"
NEW="@executable_path/../Frameworks/GStreamer.framework"
GST_DIR="$APP_PATH/Contents/Frameworks/GStreamer.framework"
MAIN_BIN="$APP_PATH/Contents/MacOS/$APP_BIN_NAME"

if [ ! -d "$GST_DIR" ]; then
    echo "fix_gstreamer_paths_macos: no bundled GStreamer.framework at $GST_DIR — skipping"
    exit 0
fi

fixed=0

rewrite_binary() {
    local bin="$1"
    # Skip non-Mach-O (plists, .h files, gst presets, etc).
    if ! file -b "$bin" 2>/dev/null | grep -q 'Mach-O'; then
        return
    fi
    local changed=0

    # Fix install_name (id) if it points at the system path.
    local cur_id
    cur_id=$(otool -D "$bin" 2>/dev/null | tail -n +2 | head -n1 || true)
    if [ -n "$cur_id" ] && [ "${cur_id#$OLD}" != "$cur_id" ]; then
        install_name_tool -id "${NEW}${cur_id#$OLD}" "$bin"
        changed=1
    fi

    # Fix every dependency reference at the system path.
    local deps
    deps=$(otool -L "$bin" 2>/dev/null | awk -v old="$OLD" '
        NR > 1 {
            sub(/^[ \t]+/, "", $0)
            sub(/ \(compatibility.*$/, "", $0)
            if (index($0, old) == 1) print $0
        }')
    if [ -n "$deps" ]; then
        while IFS= read -r dep; do
            [ -z "$dep" ] && continue
            install_name_tool -change "$dep" "${NEW}${dep#$OLD}" "$bin"
            changed=1
        done <<<"$deps"
    fi

    if [ "$changed" -eq 1 ]; then
        # Ad-hoc re-sign so the modified binary remains loadable on macOS 11+.
        codesign --force --sign - --preserve-metadata=entitlements,requirements,flags,runtime "$bin" 2>/dev/null \
            || codesign --force --sign - "$bin" 2>/dev/null \
            || true
        fixed=$((fixed + 1))
    fi
}

# Walk every regular file in the bundled framework. Symlinks have no own
# install_name and inherit their target's load commands, so skip them.
while IFS= read -r -d '' f; do
    rewrite_binary "$f"
done < <(find "$GST_DIR" -type f -print0)

# Main app binary picks up libz et al as direct deps — fix it too.
if [ -f "$MAIN_BIN" ]; then
    rewrite_binary "$MAIN_BIN"
fi

echo "fix_gstreamer_paths_macos: rewrote $fixed binaries"
