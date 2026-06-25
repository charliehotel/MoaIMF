#!/bin/zsh
set -euo pipefail

root_dir=${0:A:h:h}
cd "$root_dir"
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
mkdir -p "$module_cache_dir" "$swiftpm_cache_dir" "$swiftpm_config_dir" "$swiftpm_security_dir"
export CLANG_MODULE_CACHE_PATH="$module_cache_dir"
export SWIFTPM_MODULECACHE_OVERRIDE="$module_cache_dir"
xcrun swift-format lint --strict --recursive Sources Tests Package.swift
swift test "${swiftpm_arguments[@]}"
swift build "${swiftpm_arguments[@]}"
scripts/build-app.sh
