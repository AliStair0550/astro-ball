#!/usr/bin/env bash
#
# Astro Ball to the phone in one command.
#
#   ./tools/deploy.sh              export, build, install, launch
#   ./tools/deploy.sh --build      stop after building, do not install
#   ./tools/deploy.sh --release    release configuration
#
# Three things this refuses to do quietly, because each of them cost an
# afternoon once:
#
#   - Run while the Godot editor is open. The editor owns project.godot
#     and export_presets.cfg while it lives, and writes its own memory
#     over anything changed on disk underneath it. Without a warning.
#   - Start a build with no room for it. Xcode fills a disk and then
#     fails in ways that read like code problems.
#   - Report success when the install step never ran.

set -uo pipefail

GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD="$ROOT/build/ios"
DERIVED="$BUILD/DerivedData"
SCHEME="AstroBall"
CONFIG="Debug"
EXPORT_MODE="--export-debug"
INSTALL=1
MIN_FREE_GB="${MIN_FREE_GB:-4}"

for arg in "$@"; do
  case "$arg" in
    --release) CONFIG="Release"; EXPORT_MODE="--export-release" ;;
    --build) INSTALL=0 ;;
    -h|--help) sed -n '2,20p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) echo "unknown option: $arg"; exit 2 ;;
  esac
done

step() { printf '\n\033[1m==> %s\033[0m\n' "$1"; }
fail() { printf '\033[31m%s\033[0m\n' "$1" >&2; exit 1; }

# --- 0. The two things that make everything else lie ------------------

# Only a real editor counts. The same binary runs the test suite, and
# matching that too made this refuse to build because of its own tests.
if pgrep -lf "Godot.app/Contents/MacOS/Godot" 2>/dev/null | grep -qv -- "--headless"; then
  fail "The Godot editor is open. Close it with Cmd-Q first: while it runs it
owns project.godot and export_presets.cfg, and it will write its own
copy over anything this script changes, without saying so."
fi

# The editor rewrites both files from memory when it closes, so the
# settings that make the launch seamless can be gone without anyone
# touching them. Cheaper to check here than to see the engine's logo on
# a phone.
grep -q '^boot_splash/show_image=false' "$ROOT/project.godot" \
  || fail "project.godot has the engine boot logo back on. The Godot editor
rewrites this file from memory when it closes. Put it back:
  boot_splash/show_image=false
  boot_splash/bg_color=Color(0.027451, 0.027451, 0.047059, 1)"
grep -q '^storyboard/use_custom_bg_color=true' "$ROOT/export_presets.cfg" \
  || fail "export_presets.cfg has lost the iOS launch screen colour. Put back:
  storyboard/use_custom_bg_color=true
  storyboard/custom_bg_color=Color(0.027451, 0.027451, 0.047059, 1)"
# An empty custom image is not no image: the exporter puts the engine's
# own splash in the storyboard, robot and all.
grep -q 'storyboard/custom_image@2x=".*launch_blank.png"' "$ROOT/export_presets.cfg" \
  || fail "export_presets.cfg has lost the blank launch image, so the iOS
launch screen will carry the Godot logo again. Put back:
  storyboard/custom_image@2x=\"res://assets/icons/launch_blank.png\"
  storyboard/custom_image@3x=\"res://assets/icons/launch_blank.png\""

# Xcode cannot resolve a device destination without the iOS platform,
# and in Xcode 16 that platform is the same component as the simulator
# runtime. Deleting the runtimes to free disk space — which looks
# harmless when the simulator is never used — takes device builds down
# with them. The SDK stays behind, so -showsdks still lists iOS and the
# failure looks like something else entirely.
if ! xcrun simctl list runtimes 2>/dev/null | grep -qi "iOS "; then
  fail "The iOS platform is not installed, so Xcode cannot build for a device.
It is the same component as the simulator runtimes: deleting those to
free space takes this with them. Get it back with

  xcodebuild -downloadPlatform iOS

or Xcode > Settings > Components. It is several gigabytes."
fi

FREE_GB=$(df -g "$ROOT" | awk 'NR==2 {print $4}')
if [ "${FREE_GB:-0}" -lt "$MIN_FREE_GB" ]; then
  fail "Only ${FREE_GB} GB free and a build needs about ${MIN_FREE_GB}. Free some up:
  rm -rf ~/Library/Developer/Xcode/DerivedData/*
  rm -rf ~/Library/Developer/Xcode/iOS\\ DeviceSupport/*
The second one is symbols for every iOS version this phone has ever run.
Xcode fetches what it needs again next time."
fi

[ -x "$GODOT" ] || fail "Godot not found at $GODOT. Set GODOT=/path/to/Godot."

# --- 1. Export --------------------------------------------------------

step "Exporting from Godot ($CONFIG)"
rm -rf "$BUILD"
mkdir -p "$BUILD"
if ! "$GODOT" --headless --path "$ROOT" "$EXPORT_MODE" "iOS" "$BUILD/$SCHEME.xcodeproj" 2>&1 \
    | grep -vE '^\[|^$|^Godot Engine'; then
  true
fi
[ -d "$BUILD/$SCHEME.xcodeproj" ] || fail "The export produced no Xcode project.
If Godot printed 'configuration errors:' with nothing after it, open
Project -> Export in the editor: the dialog shows the reason in red."

# --- 2. Build ---------------------------------------------------------

# The identifier is picked out by shape rather than by column, because
# both the state and the model are two words wide and the columns move.
# A phone paired over the network reports "available (paired)", not
# "connected", and installs perfectly well: only "unavailable" is out.
UUID_RE='[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}'

find_device() {
  local rows
  rows="$(xcrun devicectl list devices 2>/dev/null | grep -E 'iPhone|iPad' | grep -v 'unavailable')"
  # A tethered phone wins over one that is merely reachable.
  printf '%s\n' "$rows" | grep -m1 'connected' | grep -m1 -oE "$UUID_RE" && return 0
  printf '%s\n' "$rows" | grep -m1 -oE "$UUID_RE"
}

step "Building with Xcode ($CONFIG)"
DEST="generic/platform=iOS"
if [ "$INSTALL" = "1" ]; then
  DEVICE_ID="$(find_device)"
  [ -n "${DEVICE_ID:-}" ] && DEST="id=$DEVICE_ID"
fi

# Godot writes CODE_SIGN_IDENTITY="Apple Distribution" into the release
# configuration, and the project is signed automatically for development.
# Xcode calls that a conflict and refuses before it compiles anything.
#
# So: if there is a distribution certificate on this machine, the release
# configuration is left alone and the build is a real one. If there is
# not, it falls back to the development certificate and says so. That
# build proves the code compiles and packs with optimisation on; it is
# not something that can be uploaded.
# Expanded below as ${SIGN_ARGS[@]+"${SIGN_ARGS[@]}"}, which is the only
# way to pass a possibly-empty array under set -u in the bash macOS
# ships. "${SIGN_ARGS[@]}" on its own is an unbound variable there, and
# it took the debug build down with it.
SIGN_ARGS=()
if [ "$CONFIG" = "Release" ]; then
  if security find-identity -v -p codesigning 2>/dev/null | grep -q "Apple Distribution"; then
    printf '    signing with the distribution certificate\n'
  else
    printf '\033[33m    No Apple Distribution certificate here, so this build is signed for\n    development: it checks the code, it cannot be uploaded. Make one with\n    Xcode > Settings > Accounts > Manage Certificates > + > Apple Distribution\033[0m\n'
    SIGN_ARGS=(CODE_SIGN_IDENTITY="Apple Development" CODE_SIGN_STYLE=Automatic)
  fi
fi

xcodebuild \
  -project "$BUILD/$SCHEME.xcodeproj" \
  -scheme "$SCHEME" \
  -configuration "$CONFIG" \
  -destination "$DEST" \
  -derivedDataPath "$DERIVED" \
  -allowProvisioningUpdates \
  ${SIGN_ARGS[@]+"${SIGN_ARGS[@]}"} \
  build 2>&1 | tail -25
[ "${PIPESTATUS[0]}" -eq 0 ] || fail "The build failed. The lines above are Xcode's, not ours."

APP=$(find "$DERIVED/Build/Products" -maxdepth 2 -name "$SCHEME.app" -type d 2>/dev/null | head -1)
[ -n "$APP" ] || fail "Built, but no $SCHEME.app came out of it."
step "Built: $APP"

[ "$INSTALL" = "1" ] || { echo "Stopping before install, as asked."; exit 0; }

# --- 3. Install and launch -------------------------------------------

if [ -z "${DEVICE_ID:-}" ]; then
  fail "No connected iPhone found. Plug it in, unlock it, answer Trust, then
run this again. Or use --build to stop after building."
fi

step "Installing on $DEVICE_ID"
xcrun devicectl device install app --device "$DEVICE_ID" "$APP" || \
  fail "Install failed. If the phone says the developer is untrusted:
Settings -> General -> VPN & Device Management -> your profile -> Trust."

BUNDLE=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$APP/Info.plist" 2>/dev/null)
step "Launching $BUNDLE"
xcrun devicectl device process launch --device "$DEVICE_ID" "$BUNDLE" \
  || echo "Installed, but could not launch it from here. Open it on the phone."

printf '\n\033[32mOn the phone.\033[0m\n'
