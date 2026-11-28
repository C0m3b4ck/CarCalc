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
#   macos-x64-legacy    legacy x86_64 macOS (deployment target 10.15 by default)
#   linux-arm           Linux ARM; defaults to AArch64 (see LINUX_ARM_* below)
#   windows-arm64       Windows ARM64 PE32+
#   windows-mobile-arm  legacy Windows Mobile/CE PE32 ARM (subsystem 4.20)
#
# A target whose cross toolchain is not installed is skipped with a clear
# message; the remaining targets are still built. Supply a matching toolchain
# through the overrides below to build the skipped targets.
#
# Available overrides:
#   RELEASE_DIR, STAGE_BUILD_ROOT, STAGE_CLEAN
#   LINUX_X86_CC/CXX/AR, LINUX_ARM_TRIPLE/CC/CXX/AR/PROCESSOR
#   CARCALC_LINUX_X11_ROOT (cross X11/curl headers and libraries)
#   MACOS_X64_CC/CXX/AR, MACOS_DEPLOYMENT_TARGET, MACOS_SYSTEM_VERSION
#   MACOS_SDKROOT, MACOS_STDLIB
#   WINDOWS_X64_CXX/CC/WINDRES, WINDOWS_X86_LEGACY_CXX/CC/AR/WINDRES
#   WINDOWS_X64_LEGACY_CXX/CC/WINDRES, WINDOWS_ARM64_TRIPLE/CXX/CC/WINDRES
#   WINDOWS_MOBILE_TRIPLE/CXX/CC/WINDRES, SFX_STUB
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
    for name in LICENSE cars.db cars_en.db cars_pl.db THIRD_PARTY_LICENSES.md; do
        [[ -f "$name" ]] || die "missing release asset: $name"
        cp -f "$name" "$dir/$name"
    done

    rm -rf "$dir/translations" "$dir/licenses"
    [[ ! -d translations ]] || cp -a translations "$dir/translations"
    [[ ! -d licenses ]] || cp -a licenses "$dir/licenses"
}

archive_target() {
    local target="$1"
    local dir="$RELEASE_DIR/$target"
    local archive sfx_stub=""
    local made=0

    # Archives live beside the target folders, never inside them, so an
    # archive can never include itself. Windows targets get ZIP for broad
    # compatibility, 7z for better compression, and a self-extracting EXE
    # when a Windows SFX module is available.
    case "$target" in
        windows-*)
            if command -v zip >/dev/null 2>&1; then
                archive="$RELEASE_DIR/$target.zip"
                rm -f "$archive"
                (cd "$dir" && zip -q -r "$archive" .)
                [[ -s "$archive" ]] || die "failed to create archive for $target"
                echo "==> archived $archive"
                made=1
            fi
            if command -v 7z >/dev/null 2>&1; then
                archive="$RELEASE_DIR/$target.7z"
                rm -f "$archive"
                (cd "$dir" && 7z a -bso0 -bsp0 "$archive" . >/dev/null)
                [[ -s "$archive" ]] || die "failed to create archive for $target"
                echo "==> archived $archive"
                made=1
            fi
            sfx_stub="${SFX_STUB:-}"
            if [[ -z "$sfx_stub" && -f /usr/lib/7zip/7z.sfx ]]; then
                sfx_stub=/usr/lib/7zip/7z.sfx
            fi
            if command -v 7z >/dev/null 2>&1 && [[ -n "$sfx_stub" && -f "$sfx_stub" ]]; then
                archive="$RELEASE_DIR/$target.exe"
                rm -f "$archive"
                (cd "$dir" && 7z a -bso0 -bsp0 "-sfx$sfx_stub" "$archive" . >/dev/null)
                [[ -s "$archive" ]] || die "failed to create archive for $target"
                echo "==> archived $archive"
                made=1
            else
                echo "==> no Windows SFX module for $target; set SFX_STUB to a 7-Zip 7z.sfx file to build $target.exe" >&2
            fi
            if [[ "$made" -eq 0 ]]; then
                echo "==> zip and 7z not found; using tar.gz for $target" >&2
                archive="$RELEASE_DIR/$target.tar.gz"
                rm -f "$archive"
                tar -czf "$archive" -C "$dir" .
                [[ -s "$archive" ]] || die "failed to create archive for $target"
                echo "==> archived $archive"
            fi
            ;;
        *)
            archive="$RELEASE_DIR/$target.tar.gz"
            rm -f "$archive"
            tar -czf "$archive" -C "$dir" .
            [[ -s "$archive" ]] || die "failed to create archive for $target"
            echo "==> archived $archive"
            ;;
    esac
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
    archive_target "$target"
    echo "==> staged $dest"
}

linux_cross_x11_root() {
    local root="${CARCALC_LINUX_X11_ROOT:-}"
    if [[ -z "$root" && -d /tmp/opencode/carcalc-tools/linux-x11-sysroot ]]; then
        root=/tmp/opencode/carcalc-tools/linux-x11-sysroot
    fi
    printf '%s' "$root"
}

write_linux_toolchain() {
    local name="$1"
    local triple="$2"
    local processor="$3"
    local cc="$4"
    local cxx="$5"
    local build_dir="$BUILD_ROOT/$name"
    local file="$build_dir/toolchain.cmake"
    local x11_root
    local find_roots="/usr/$triple"

    x11_root=$(linux_cross_x11_root)
    if [[ -n "$x11_root" && -d "$x11_root" ]]; then
        find_roots="$x11_root;/usr/$triple"
    fi

    mkdir -p "$build_dir"
    cat > "$file" <<EOF
set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR $processor)
set(CMAKE_C_COMPILER $cc)
set(CMAKE_CXX_COMPILER $cxx)
set(CMAKE_FIND_ROOT_PATH $find_roots)
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
    local x11_root
    local ldflags="${CARCALC_EXTRA_LDFLAGS:-}"

    require_tools "$cc" "$cxx" "$ar" cmake || return $?
    x11_root=$(linux_cross_x11_root)
    if [[ -n "$x11_root" && -d "$x11_root/usr/lib/i386-linux-gnu" ]]; then
        ldflags="$ldflags -L$x11_root/usr/lib/i386-linux-gnu"
    fi
    toolchain=$(write_linux_toolchain linux-x86 i686-linux-gnu i686 "$cc" "$cxx")
    CARCALC_CMAKE_TOOLCHAIN_FILE="$toolchain" \
    CARCALC_EXTRA_LDFLAGS="$ldflags" \
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
    local x11_root
    local ldflags="${CARCALC_EXTRA_LDFLAGS:-}"

    require_tools "$cc" "$cxx" "$ar" cmake || return $?
    x11_root=$(linux_cross_x11_root)
    if [[ -z "$x11_root" || ! -f "$x11_root/usr/lib/$triple/libssl.so" ]]; then
        echo "==> SKIPPED $CURRENT_TARGET: missing target-architecture X11/curl/OpenSSL development libraries" >&2
        echo "    install libssl-dev:$triple and set CARCALC_LINUX_X11_ROOT to a sysroot containing libX11/libXext/libcurl/libssl" >&2
        SKIPPED+=("$CURRENT_TARGET: missing target-architecture X11/curl/OpenSSL development libraries")
        return 2
    fi
    if [[ -d "$x11_root/usr/lib/$triple" ]]; then
        ldflags="$ldflags -L$x11_root/usr/lib/$triple"
    fi
    toolchain=$(write_linux_toolchain linux-arm "$triple" "$processor" "$cc" "$cxx")
    CARCALC_CMAKE_TOOLCHAIN_FILE="$toolchain" \
    CARCALC_EXTRA_LDFLAGS="$ldflags" \
    BUILD_DIR="$BUILD_ROOT/linux-arm" CC="$cc" CXX="$cxx" AR="$ar" \
    CLEAN=0 OUT="$dest" ./build_full.sh
}

build_windows_x64() {
    local dest="$1"
    local triple="${WINDOWS_TRIPLE:-x86_64-w64-mingw32}"
    local cxx="${WINDOWS_X64_CXX:-${CXX:-${triple}-g++}}"
    local cc="${WINDOWS_X64_CC:-${CC:-${triple}-gcc}}"
    local windres="${WINDOWS_X64_WINDRES:-${WINDRES:-${triple}-windres}}"

    require_tools "$cxx" "$cc" "$windres" cmake || return $?
    CXX="$cxx" CC="$cc" WINDRES="$windres" \
    CARCALC_DEPS="$BUILD_ROOT/windows-x64-deps" \
    OUT="$dest" ./compile_windows.sh
}

build_windows_x86_legacy() {
    local dest="$1"
    local cxx="${WINDOWS_X86_LEGACY_CXX:-${CXX:-i686-w64-mingw32-g++}}"
    local cc="${WINDOWS_X86_LEGACY_CC:-${CC:-i686-w64-mingw32-gcc}}"
    local ar="${WINDOWS_X86_LEGACY_AR:-${AR:-i686-w64-mingw32-ar}}"
    local windres="${WINDOWS_X86_LEGACY_WINDRES:-${WINDRES:-i686-w64-mingw32-windres}}"

    require_tools "$cxx" "$cc" "$ar" "$windres" cmake || return $?
    CXX="$cxx" CC="$cc" AR="$ar" WINDRES="$windres" \
    CARCALC_LEGACY_DEPS="$BUILD_ROOT/windows-x86-legacy-deps" \
    CARCALC_LEGACY_BUILD="$BUILD_ROOT/windows-x86-legacy-build" \
    OUT="$dest" ./compile_windows_legacy.sh
}

build_windows_x64_legacy() {
    local dest="$1"
    local triple="${WINDOWS_TRIPLE:-x86_64-w64-mingw32}"
    local cxx="${WINDOWS_X64_LEGACY_CXX:-${CXX:-${triple}-g++}}"
    local cc="${WINDOWS_X64_LEGACY_CC:-${CC:-${triple}-gcc}}"
    local windres="${WINDOWS_X64_LEGACY_WINDRES:-${WINDRES:-${triple}-windres}}"

    require_tools "$cxx" "$cc" "$windres" cmake || return $?
    CXX="$cxx" CC="$cc" WINDRES="$windres" \
    CARCALC_DEPS="$BUILD_ROOT/windows-x64-legacy-deps" \
    WINDOWS_WINNT=0x0502 \
    WINDOWS_SUBSYSTEM_MAJOR=5 WINDOWS_SUBSYSTEM_MINOR=2 \
    OUT="$dest" ./compile_windows.sh
}

build_windows_arm64() {
    local dest="$1"
    local triple="${WINDOWS_ARM64_TRIPLE:-aarch64-w64-mingw32}"
    local cxx="${WINDOWS_ARM64_CXX:-${CXX:-${triple}-g++}}"
    local cc="${WINDOWS_ARM64_CC:-${CC:-${triple}-gcc}}"
    local windres="${WINDOWS_ARM64_WINDRES:-${WINDRES:-${triple}-windres}}"

    require_tools "$cxx" "$cc" "$windres" cmake || return $?
    CXX="$cxx" CC="$cc" WINDRES="$windres" \
    CARCALC_DEPS="$BUILD_ROOT/windows-arm64-deps" \
    WINDOWS_TRIPLE="$triple" \
    WINDOWS_PROCESSOR=ARM64 \
    WINDOWS_WINNT=0x0600 \
    WINDOWS_SUBSYSTEM_MAJOR=6 WINDOWS_SUBSYSTEM_MINOR=0 \
    OUT="$dest" ./compile_windows.sh
}

build_windows_mobile_arm() {
    local dest="$1"
    local triple="${WINDOWS_MOBILE_TRIPLE:-armv7-w64-mingw32}"
    local cxx="${WINDOWS_MOBILE_CXX:-${CXX:-${triple}-g++}}"
    local cc="${WINDOWS_MOBILE_CC:-${CC:-${triple}-gcc}}"
    local windres="${WINDOWS_MOBILE_WINDRES:-${WINDRES:-${triple}-windres}}"

    require_tools "$cxx" "$cc" "$windres" cmake || return $?
    CXX="$cxx" CC="$cc" WINDRES="$windres" \
    CARCALC_DEPS="$BUILD_ROOT/windows-mobile-arm-deps" \
    WINDOWS_TRIPLE="$triple" \
    WINDOWS_PROCESSOR=ARM \
    WINDOWS_WINNT=0x0500 \
    WINDOWS_SUBSYSTEM_MAJOR=4 WINDOWS_SUBSYSTEM_MINOR=20 \
    OUT="$dest" ./compile_windows.sh
}

build_macos_x64_legacy() {
    local dest="$1"
    local cc="${MACOS_X64_CC:-x86_64-apple-darwin-clang}"
    local cxx="${MACOS_X64_CXX:-x86_64-apple-darwin-clang++}"
    local ar="${MACOS_X64_AR:-x86_64-apple-darwin-ar}"
    local deployment="${MACOS_DEPLOYMENT_TARGET:-10.15}"
    local stdlib="${MACOS_STDLIB:-libc++}"
    local build_dir="$BUILD_ROOT/macos-x64-legacy"
    local toolchain="$build_dir/toolchain.cmake"
    local sdk_lines=""
    local system_version="${MACOS_SYSTEM_VERSION:-20.4}"
    local extra_flags="-mmacosx-version-min=$deployment -stdlib=$stdlib"
    local framework_flags="-framework Cocoa -framework CoreFoundation -framework CoreGraphics -framework ApplicationServices -framework Carbon"
    local curl_inc="$build_dir/curl-include"
    local host_curl_inc=""
    local curl_cflags="${CARCALC_CURL_CFLAGS:-}"
    local curl_libs="${CARCALC_CURL_LIBS:-}"
    local use_sdk_curl=0

    require_tools "$cc" "$cxx" "$ar" cmake || return $?
    mkdir -p "$build_dir"
    if [[ -n "${MACOS_SDKROOT:-}" ]]; then
        sdk_lines="set(CMAKE_OSX_SYSROOT $MACOS_SDKROOT)"
    fi

    cat > "$toolchain" <<EOF
set(CMAKE_SYSTEM_NAME Darwin)
set(CARCALC_DARWIN 1)
set(CMAKE_SYSTEM_VERSION $system_version)
set(CMAKE_SYSTEM_PROCESSOR x86_64)
set(CMAKE_C_COMPILER $cc)
set(CMAKE_CXX_COMPILER $cxx)
set(CMAKE_OBJCXX_COMPILER $cxx)
set(CMAKE_OSX_DEPLOYMENT_TARGET $deployment)
$sdk_lines
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
EOF

    # Prefer curl headers from the macOS SDK. Older SDKs omit them, so fall
    # back to copying the host headers into the build tree; never pass a host
    # /usr/include path to the cross compiler.
    if [[ -z "$curl_cflags" ]]; then
        local sdk_curl_h
        for sdk_curl_h in "$(dirname "$(dirname "$cc")")"/SDK/MacOSX*.sdk/usr/include/curl/curl.h; do
            if [[ -f "$sdk_curl_h" ]]; then
                use_sdk_curl=1
                curl_libs="-lcurl"
                break
            fi
        done
    fi
    if [[ "$use_sdk_curl" -eq 0 && -z "$curl_cflags" ]]; then
        host_curl_inc=$(pkg-config --variable=includedir libcurl 2>/dev/null || true)
        if [[ -n "$host_curl_inc" && -f "$host_curl_inc/curl/curl.h" ]]; then
            mkdir -p "$curl_inc/curl"
            cp -f "$host_curl_inc"/curl/*.h "$curl_inc/curl/"
            curl_cflags="-I$curl_inc"
            curl_libs="-lcurl"
        fi
    fi
    if [[ "$use_sdk_curl" -eq 0 && -z "$curl_cflags" ]] && command -v pkg-config >/dev/null 2>&1; then
        curl_cflags=$(pkg-config --cflags libcurl 2>/dev/null || true)
    fi
    if [[ -z "$curl_libs" ]] && command -v pkg-config >/dev/null 2>&1; then
        curl_libs=$(pkg-config --libs libcurl 2>/dev/null || true)
    fi

    CARCALC_CURL_CFLAGS="$curl_cflags" \
    CARCALC_CURL_LIBS="$curl_libs" \
    CARCALC_CMAKE_TOOLCHAIN_FILE="$toolchain" \
    CARCALC_FLTK_BACKEND_X11=OFF \
    CARCALC_EXTRA_CFLAGS="${CARCALC_EXTRA_CFLAGS:-} $extra_flags" \
    CARCALC_EXTRA_CXXFLAGS="${CARCALC_EXTRA_CXXFLAGS:-} $extra_flags" \
    CARCALC_EXTRA_OBJCXXFLAGS="${CARCALC_EXTRA_OBJCXXFLAGS:-} $extra_flags" \
    CARCALC_EXTRA_LDFLAGS="${CARCALC_EXTRA_LDFLAGS:-} $extra_flags $framework_flags" \
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
stage_target windows-mobile-arm CarCalc-mobile.exe build_windows_mobile_arm

echo
if [[ "${#SKIPPED[@]}" -gt 0 ]]; then
    echo "Skipped targets (install a cross toolchain or set the matching override):"
    printf '  - %s\n' "${SKIPPED[@]}"
fi
echo "Done: staged available targets in $RELEASE_DIR"
