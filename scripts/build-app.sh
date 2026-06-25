#!/bin/zsh
set -euo pipefail

root_dir=${0:A:h:h}
configuration=${CONFIGURATION:-release}
app_dir="$root_dir/.build/MoaIMF.app"
contents_dir="$app_dir/Contents"
icon_source="$root_dir/Assets.xcassets/MoaIMF_icon.png"
iconset_dir="$root_dir/.build/MoaIMF.iconset"
module_cache_dir="$root_dir/.build/ModuleCache"
swiftpm_cache_dir="$root_dir/.build/SwiftPM/cache"
swiftpm_config_dir="$root_dir/.build/SwiftPM/config"
swiftpm_security_dir="$root_dir/.build/SwiftPM/security"
swiftpm_arguments=(
  --disable-sandbox
  --cache-path "$swiftpm_cache_dir"
  --config-path "$swiftpm_config_dir"
  --security-path "$swiftpm_security_dir"
)

cd "$root_dir"
mkdir -p "$module_cache_dir" "$swiftpm_cache_dir" "$swiftpm_config_dir" "$swiftpm_security_dir"
export CLANG_MODULE_CACHE_PATH="$module_cache_dir"
export SWIFTPM_MODULECACHE_OVERRIDE="$module_cache_dir"
swift build "${swiftpm_arguments[@]}" -c "$configuration" --product MoaIMF
rm -rf "$app_dir"
mkdir -p "$contents_dir/MacOS" "$contents_dir/Resources"
cp ".build/$configuration/MoaIMF" "$contents_dir/MacOS/MoaIMF"
cp Packaging/Info.plist "$contents_dir/Info.plist"
mkdir -p "$contents_dir/Resources/Assets.xcassets"
cp -X Assets.xcassets/*.png "$contents_dir/Resources/Assets.xcassets"
cp -X "$icon_source" "$contents_dir/Resources/MoaIMF_icon.png"
rm -rf "$iconset_dir"
mkdir -p "$iconset_dir"
sips -z 16 16 "$icon_source" --out "$iconset_dir/icon_16x16.png" >/dev/null
sips -z 32 32 "$icon_source" --out "$iconset_dir/icon_32x32.png" >/dev/null
sips -z 64 64 "$icon_source" --out "$iconset_dir/icon_64x64.png" >/dev/null
sips -z 128 128 "$icon_source" --out "$iconset_dir/icon_128x128.png" >/dev/null
sips -z 256 256 "$icon_source" --out "$iconset_dir/icon_256x256.png" >/dev/null
sips -z 512 512 "$icon_source" --out "$iconset_dir/icon_512x512.png" >/dev/null
sips -z 1024 1024 "$icon_source" --out "$iconset_dir/icon_1024x1024.png" >/dev/null
python3 - "$iconset_dir" "$contents_dir/Resources/MoaIMF.icns" <<'PY'
import struct
import sys
from pathlib import Path

iconset = Path(sys.argv[1])
output = Path(sys.argv[2])
entries = [
    ("icp4", "icon_16x16.png"),
    ("icp5", "icon_32x32.png"),
    ("icp6", "icon_64x64.png"),
    ("ic07", "icon_128x128.png"),
    ("ic08", "icon_256x256.png"),
    ("ic09", "icon_512x512.png"),
    ("ic10", "icon_1024x1024.png"),
]

payload = bytearray()
for icon_type, filename in entries:
    data = (iconset / filename).read_bytes()
    payload.extend(icon_type.encode("ascii"))
    payload.extend(struct.pack(">I", len(data) + 8))
    payload.extend(data)

output.write_bytes(b"icns" + struct.pack(">I", len(payload) + 8) + payload)
PY
rm -rf "$iconset_dir"
for resource_bundle in .build/$configuration/MoaIMF_*.bundle(N); do
  ditto "$resource_bundle" "$contents_dir/Resources/${resource_bundle:t}"
done
test -d "$contents_dir/Resources/MoaIMF_MoaIMFUI.bundle"
codesign --force --sign "${CODE_SIGN_IDENTITY:--}" \
  --entitlements Packaging/MoaIMF.entitlements "$app_dir"
codesign --verify --deep --strict "$app_dir"
print -r -- "$app_dir"
