#!/usr/bin/env bash
# Build/stage every CarCalc target into one release folder.
#
# Usage:
#   ./stage_release.sh
#   RELEASE_DIR=/tmp/opencode/carcalc-release ./stage_release.sh
#   STAGE_CLEAN=1 ./stage_release.sh
#
# Every target is compiled from source. The script never uses git/GitHub,
# never commits or tags, and never uploads or publishes anything.
#
# Targets staged (one subdirectory each):
#   linux-x86           32-bit x86 Linux ELF
#   linux-x64           64-bit x86 Linux ELF
#   windows-x64         modern x86_64 Windows PE32+
#   windows-x86-legacy  Windows 2000+ PE32 (existing legacy builder)
#   windows-x64-legacy  legacy x86_64 Windows PE32+ (subsystem 5.02 / XP x64)
#   macos-x64-legacy    legacy x86_64 macOS (deployment target 10.9 by default)
#   linux-arm           Linux ARM; defaults to AArch64 (see LINUX_ARM_* below)
#   windows-arm64       Windows ARM64 PE32+
#
# A target whose cross toolchain is not installed is skipped with a clear
# message; the remaining targets are still built. Supply a matching toolchain
# through the overrides below to build the skipped targets.
#
# Available overrides:
#   RELEASE_DIR, STAGE_BUILD_ROOT, STAGE_CLEAN
#   LINUX_X86_CC/CXX/AR, LINUX_ARM_TRIPLE/CC/CXX/AR/PROCESSOR
#   MACOS_X64_CC/CXX/AR, MACOS_DEPLOYMENT_TARGET, MACOS_SDKROOT
#   WINDOWS_ARM64_TRIPLE
#
# Cross targets need matching MinGW/macOS/ARM toolchains and cross libraries.
# For curl on cross targets, set PKG_CONFIG_LIBDIR or CARCALC_EXTRA_CXXFLAGS /
# CARCALC_EXTRA_LDFLAGS before running the script.

set -euo pipefail
cd "$(dirname "$0")"
ROOT="$PWD"

RELEASE_DIR="${RELEASE_DIR:-$ROOT/release}"
BUILD_ROOT="${STAGE_BUILD_ROOT:-$ROOT/.stage-build}"

SKIPPED=()
CURRENT_TARGET=""

die() {
    echo "error: $*" >&2
    exit 1
}

missing_tools() {
    local tool result=""
    for tool in "$@"; do
        command -v "$tool" >/dev/null 2>&1 || result="${result:+$result }$tool"
    done
    printf '%s' "$result"
}

# Returns 2 when tools are missing so the caller can pass that through and
# let stage_target() mark the target as skipped instead of aborting the run.
require_tools() {
    local missing
    missing=$(missing_tools "$@")
    if [[ -n "$missing" ]]; then
        echo "==> SKIPPED $CURRENT_TARGET: missing tool(s): $missing" >&2
        SKIPPED+=("$CURRENT_TARGET: missing tool(s): $missing")
        return 2
    fi
    return 0
}

stage_assets() {
    local dir="$1"
    local name

    mkdir -p "$dir"
    for name in cars.db cars_en.db cars_pl.db THIRD_PARTY_LICENSES.md; do
        [[ -f "$name" ]] || die "missing release asset: $name"
        cp -f "$name" "$dir/$name"
    done

    rm -rf "$dir/translations" "$dir/licenses"
    [[ ! -d translations ]] || cp -a translations "$dir/translations"
    [[ ! -d licenses ]] || cp -a licenses "$dir/licenses"
}

stage_target() {
    local target="$1"
    local filename="$2"
    local builder="$3"
    local dir="$RELEASE_DIR/$target"
    local dest="$dir/$filename"
    local rc=0

    CURRENT_TARGET="$target"
    mkdir -p "$dir"
    "$builder" "$dest" || rc=$?
    if [[ "$rc" -eq 2 ]]; then
        rm -rf "$dir"
        return 0
    fi
    [[ "$rc" -eq 0 ]] || die "$builder failed for $target (exit $rc)"
    [[ -f "$dest" ]] || die "$builder did not produce $dest"
    case "$filename" in
        *.exe) ;;
        *) chmod +x "$dest" ;;
    esac
    stage_assets "$dir"
    echo "==> staged $dest"
}

write_linux_toolchain() {
    local name="$1"
    local triple="$2"
    local processor="$3"
    local cc="$4"
    local cxx="$5"
    local build_dir="$BUILD_ROOT/$name"
    local file="$build_dir/toolchain.cmake"

    mkdir -p "$build_dir"
    cat > "$file" <<EOF
set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR $processor)
set(CMAKE_C_COMPILER $cc)
set(CMAKE_CXX_COMPILER $cxx)
set(CMAKE_FIND_ROOT_PATH /usr/$triple)
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
EOF
    echo "$file"
}

build_linux_x64() {
    local dest="$1"
    require_tools "${CC:-gcc}" "${CXX:-g++}" "${AR:-ar}" cmake || return $?
    BUILD_DIR="$BUILD_ROOT/linux-x64" CLEAN=0 OUT="$dest" ./build_full.sh
}

build_linux_x86() {
    local dest="$1"
    local cc="${LINUX_X86_CC:-i686-linux-gnu-gcc}"
    local cxx="${LINUX_X86_CXX:-i686-linux-gnu-g++}"
    local ar="${LINUX_X86_AR:-i686-linux-gnu-ar}"
    local toolchain

    require_tools "$cc" "$cxx" "$ar" cmake || return $?
    toolchain=$(write_linux_toolchain linux-x86 i686-linux-gnu i686 "$cc" "$cxx")
    CARCALC_CMAKE_TOOLCHAIN_FILE="$toolchain" \
    BUILD_DIR="$BUILD_ROOT/linux-x86" CC="$cc" CXX="$cxx" AR="$ar" \
    CLEAN=0 OUT="$dest" ./build_full.sh
}

build_linux_arm() {
    local dest="$1"
    local triple="${LINUX_ARM_TRIPLE:-aarch64-linux-gnu}"
    local processor="${LINUX_ARM_PROCESSOR:-aarch64}"
    local cc="${LINUX_ARM_CC:-${triple}-gcc}"
    local cxx="${LINUX_ARM_CXX:-${triple}-g++}"
    local ar="${LINUX_ARM_AR:-${triple}-ar}"
    local toolchain

    require_tools "$cc" "$cxx" "$ar" cmake || return $?
    toolchain=$(write_linux_toolchain linux-arm "$triple" "$processor" "$cc" "$cxx")
    CARCALC_CMAKE_TOOLCHAIN_FILE="$toolchain" \
    BUILD_DIR="$BUILD_ROOT/linux-arm" CC="$cc" CXX="$cxx" AR="$ar" \
    CLEAN=0 OUT="$dest" ./build_full.sh
}

build_windows_x64() {
    local dest="$1"
    local triple="${WINDOWS_TRIPLE:-x86_64-w64-mingw32}"
    local cxx="${CXX:-${triple}-g++}"
    local cc="${CC:-${triple}-gcc}"
    local windres="${WINDRES:-${triple}-windres}"

    require_tools "$cxx" "$cc" "$windres" cmake || return $?
    CARCALC_DEPS="$BUILD_ROOT/windows-x64-deps" \
    OUT="$dest" ./compile_windows.sh
}

build_windows_x86_legacy() {
    local dest="$1"
    local cxx="${CXX:-i686-w64-mingw32-g++}"
    local cc="${CC:-i686-w64-mingw32-gcc}"
    local ar="${AR:-i686-w64-mingw32-ar}"
    local windres="${WINDRES:-i686-w64-mingw32-windres}"

    require_tools "$cxx" "$cc" "$ar" "$windres" cmake || return $?
    CARCALC_LEGACY_DEPS="$BUILD_ROOT/windows-x86-legacy-deps" \
    CARCALC_LEGACY_BUILD="$BUILD_ROOT/windows-x86-legacy-build" \
    OUT="$dest" ./compile_windows_legacy.sh
}

build_windows_x64_legacy() {
    local dest="$1"
    local triple="${WINDOWS_TRIPLE:-x86_64-w64-mingw32}"
    local cxx="${CXX:-${triple}-g++}"
    local cc="${CC:-${triple}-gcc}"
    local windres="${WINDRES:-${triple}-windres}"

    require_tools "$cxx" "$cc" "$windres" cmake || return $?
    CARCALC_DEPS="$BUILD_ROOT/windows-x64-legacy-deps" \
    WINDOWS_WINNT=0x0502 \
    WINDOWS_SUBSYSTEM_MAJOR=5 WINDOWS_SUBSYSTEM_MINOR=2 \
    OUT="$dest" ./compile_windows.sh
}

build_windows_arm64() {
    local dest="$1"
    local triple="${WINDOWS_ARM64_TRIPLE:-aarch64-w64-mingw32}"
    local cxx="${CXX:-${triple}-g++}"
    local cc="${CC:-${triple}-gcc}"
    local windres="${WINDRES:-${triple}-windres}"

    require_tools "$cxx" "$cc" "$windres" cmake || return $?
    CARCALC_DEPS="$BUILD_ROOT/windows-arm64-deps" \
    WINDOWS_TRIPLE="$triple" \
    WINDOWS_PROCESSOR=ARM64 \
    WINDOWS_WINNT=0x0600 \
    WINDOWS_SUBSYSTEM_MAJOR=6 WINDOWS_SUBSYSTEM_MINOR=0 \
    OUT="$dest" ./compile_windows.sh
}

build_macos_x64_legacy() {
    local dest="$1"
    local cc="${MACOS_X64_CC:-x86_64-apple-darwin-clang}"
    local cxx="${MACOS_X64_CXX:-x86_64-apple-darwin-clang++}"
    local ar="${MACOS_X64_AR:-x86_64-apple-darwin-ar}"
    local deployment="${MACOS_DEPLOYMENT_TARGET:-10.9}"
    local build_dir="$BUILD_ROOT/macos-x64-legacy"
    local toolchain="$build_dir/toolchain.cmake"
    local sdk_lines=""

    require_tools "$cc" "$cxx" "$ar" cmake || return $?
    mkdir -p "$build_dir"
    if [[ -n "${MACOS_SDKROOT:-}" ]]; then
        sdk_lines="set(CMAKE_OSX_SYSROOT $MACOS_SDKROOT)"
    fi

    cat > "$toolchain" <<EOF
set(CMAKE_SYSTEM_NAME Darwin)
set(CMAKE_SYSTEM_PROCESSOR x86_64)
set(CMAKE_C_COMPILER $cc)
set(CMAKE_CXX_COMPILER $cxx)
set(CMAKE_OSX_DEPLOYMENT_TARGET $deployment)
$sdk_lines
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
EOF

    CARCALC_CMAKE_TOOLCHAIN_FILE="$toolchain" \
    CARCALC_EXTRA_CXXFLAGS="-mmacosx-version-min=$deployment" \
    CARCALC_EXTRA_LDFLAGS="-mmacosx-version-min=$deployment" \
    BUILD_DIR="$build_dir" CC="$cc" CXX="$cxx" AR="$ar" \
    CLEAN=0 OUT="$dest" ./build_full.sh
}

if [[ "${STAGE_CLEAN:-0}" == "1" ]]; then
    rm -rf "$RELEASE_DIR"
fi
mkdir -p "$RELEASE_DIR" "$BUILD_ROOT"

# Every target is always attempted, even if an earlier toolchain is missing.
stage_target linux-x86 CarCalc build_linux_x86
stage_target linux-x64 CarCalc build_linux_x64
stage_target windows-x64 CarCalc.exe build_windows_x64
stage_target windows-x86-legacy CarCalc-legacy.exe build_windows_x86_legacy
stage_target windows-x64-legacy CarCalc-x64-legacy.exe build_windows_x64_legacy
stage_target macos-x64-legacy CarCalc build_macos_x64_legacy
stage_target linux-arm CarCalc build_linux_arm
stage_target windows-arm64 CarCalc.exe build_windows_arm64

echo
if [[ "${#SKIPPED[@]}" -gt 0 ]]; then
    echo "Skipped targets (install a cross toolchain or set the matching override):"
    printf '  - %s\n' "${SKIPPED[@]}"
fi
echo "Done: staged available targets in $RELEASE_DIR"
