#!/bin/zsh
#
# build-libass.sh: libass and the font libraries it needs (FreeType, FriBidi,
# HarfBuzz) for ASS subtitle rendering, in xcframeworks. libass, FreeType and
# HarfBuzz are static libraries. FriBidi is LGPL-2.1, so like the LGPL FFmpeg
# libraries it ships as a dynamic framework (@rpath install name, with dSYMs).
#
# Separate from build.sh on purpose: it builds nothing of FFmpeg and touches no
# FFmpeg xcframework, so the subtitle stack can be rebuilt on its own.
#
# Fonts come from libass's CoreText provider. There is no fontconfig: the
# Apple font system answers every family lookup, and the libraries carry no
# fontconfig, expat or bzip2 dependency.
#
# Usage:
#   ./build-libass.sh          # build all slices into build/libass/xcframeworks, copy into Sources/
#   ./build-libass.sh package  # repackage the xcframeworks from existing build products
#   ./build-libass.sh clean    # remove build/libass
#
# Output: build/libass/xcframeworks/ holds exactly the four xcframeworks and
# nothing else, ready to be zipped. They are then copied into Sources/.
#
set -eo pipefail

LIBASS_VERSION="0.17.5"
LIBASS_URL="https://github.com/libass/libass/releases/download/${LIBASS_VERSION}/libass-${LIBASS_VERSION}.tar.xz"
LIBASS_SHA256="2dca25c0e0c837ddf00b52011b3f82cac1e4ddd3ad018227806b0c2288864acc"
# FreeType is dual-licensed; it is used here under the FreeType License (FTL).
FREETYPE_VERSION="2.15.0"
FREETYPE_URL="https://download.savannah.gnu.org/releases/freetype/freetype-${FREETYPE_VERSION}.tar.xz"
FREETYPE_SHA256="93cd47eb719c325107f2d3cf087d06299e944c3b48a40b55537302304dea1dd5"
FRIBIDI_VERSION="1.0.18"
FRIBIDI_URL="https://github.com/fribidi/fribidi/releases/download/v${FRIBIDI_VERSION}/fribidi-${FRIBIDI_VERSION}.tar.xz"
FRIBIDI_SHA256="1de5e8073d035388b71d0b2d452b1da1f8caeea8a7702997b401fe1b6250727f"
HARFBUZZ_VERSION="15.1.0"
HARFBUZZ_URL="https://github.com/harfbuzz/harfbuzz/releases/download/${HARFBUZZ_VERSION}/harfbuzz-${HARFBUZZ_VERSION}.tar.xz"
HARFBUZZ_SHA256="0fc7c565443a5f4be7da65ac5ee5bd737d9b158dc908708b7689a0a5796b0c8d"

# Same as build.sh: line tables are enough to symbolicate a crash.
DEBUG_CFLAG="-gline-tables-only"
SCRIPT_DIR="${0:a:h}"
BUILD_DIR="${SCRIPT_DIR}/build/libass"
DOWNLOAD_DIR="${BUILD_DIR}/download"
SRC_DIR="${BUILD_DIR}/src"
THIN_DIR="${BUILD_DIR}/thin"
WORK_DIR="${BUILD_DIR}/work"
OUT_DIR="${BUILD_DIR}/xcframeworks"
SOURCES_DIR="${SCRIPT_DIR}/Sources"
PKG_CONFIG_BIN="$(command -v pkg-config)"
JOBS="$(sysctl -n hw.ncpu)"

# Shipped name -> name of the thin library meson installs.
LIBS=(TwoSBLibass:libass TwoSBLibfreetype:libfreetype TwoSBLibfribidi:libfribidi TwoSBLibharfbuzz:libharfbuzz)

MODE="build"
case "$1" in
    "") ;;
    package) MODE="package" ;;
    clean) rm -rf "${BUILD_DIR}"; echo "✓ removed ${BUILD_DIR}"; exit 0 ;;
    *) echo "Unknown argument: $1"; exit 1 ;;
esac

[[ -n "${PKG_CONFIG_BIN}" ]] || { echo "pkg-config is required"; exit 1; }

fetch() {
    local NAME="$1" URL="$2" SHA="$3"
    local ARCHIVE="${DOWNLOAD_DIR}/${URL:t}"
    mkdir -p "${DOWNLOAD_DIR}" "${SRC_DIR}"
    [[ -f "${ARCHIVE}" ]] || curl -fsSL --retry 3 -o "${ARCHIVE}" "${URL}"
    local GOT="$(shasum -a 256 "${ARCHIVE}" | awk '{print $1}')"
    if [[ "${GOT}" != "${SHA}" ]]; then
        echo "✗ ${ARCHIVE:t}: sha256 ${GOT}, expected ${SHA}"
        exit 1
    fi
    rm -rf "${SRC_DIR}/${NAME}"
    mkdir -p "${SRC_DIR}/${NAME}"
    tar -xf "${ARCHIVE}" -C "${SRC_DIR}/${NAME}" --strip-components 1
}

# patch_libass <patch> <marker> <file>: applies patches/<patch> to the libass
# source unless <file> already contains <marker>, i.e. the pinned release has it.
patch_libass() {
    local P="${SCRIPT_DIR}/patches/$1"
    if grep -q "$2" "${SRC_DIR}/libass/$3"; then
        return
    fi
    echo "→ Patching libass: ${1:r}"
    # patch(1), not git apply: the extracted tarball sits inside this repo's work
    # tree, where git apply would resolve the paths against the repo root.
    patch -p1 -N -s -d "${SRC_DIR}/libass" < "${P}" || {
        echo "✗ libass patch $1 did not apply (libass source changed?)"
        exit 1
    }
}

# Fixes not in any libass release yet: CVE-2026-95127 (PR 955) and the size
# overflow fixes from master. Each skips itself once LIBASS_VERSION has it.
patch_libass_security() {
    patch_libass libass-render-extreme-values.patch "wrap_i32" libass/ass_utils.h
    patch_libass libass-ass-size-overflows.patch "size_t osize = size + 1;" libass/ass.c
}

write_cross_file() {
    local FILE="$1" SDK="$2" ARCH="$3" TARGET="$4" PREFIX="$5"
    local SDK_PATH="$(xcrun --sdk "${SDK}" --show-sdk-path)"
    local CPU="aarch64"
    [[ "${ARCH}" == "x86_64" ]] && CPU="x86_64"
    local FLAGS="'-arch', '${ARCH}', '-isysroot', '${SDK_PATH}', '-target', '${TARGET}', '-fno-common', '${DEBUG_CFLAG}', '-I${PREFIX}/include'"
    cat > "${FILE}" << CROSSEOF
[binaries]
c = '/usr/bin/clang'
cpp = '/usr/bin/clang++'
objc = '/usr/bin/clang'
ar = '/usr/bin/ar'
strip = '/usr/bin/strip'
pkg-config = '${PKG_CONFIG_BIN}'

[properties]
pkg_config_libdir = ['${PREFIX}/lib/pkgconfig']

[built-in options]
c_args = [${FLAGS}]
cpp_args = [${FLAGS}]
objc_args = [${FLAGS}]
c_link_args = ['-arch', '${ARCH}', '-isysroot', '${SDK_PATH}', '-target', '${TARGET}', '-L${PREFIX}/lib', '-Wl,-headerpad_max_install_names']
cpp_link_args = ['-arch', '${ARCH}', '-isysroot', '${SDK_PATH}', '-target', '${TARGET}', '-L${PREFIX}/lib', '-Wl,-headerpad_max_install_names']

[host_machine]
system = 'darwin'
cpu_family = '${CPU}'
cpu = '${CPU}'
endian = 'little'
CROSSEOF
}

# meson_build <name> <slice key> <cross file> <prefix> <static|shared> [options...]
meson_build() {
    local NAME="$1" KEY="$2" CROSS="$3" PREFIX="$4" KIND="$5"
    shift 5
    local DIR="${WORK_DIR}/${KEY}/${NAME}"
    rm -rf "${DIR}"
    meson setup "${DIR}" "${SRC_DIR}/${NAME}" \
        --cross-file "${CROSS}" \
        --prefix="${PREFIX}" \
        --libdir=lib \
        --default-library="${KIND}" \
        --buildtype=release \
        --wrap-mode=nofallback \
        "$@" 2>&1 | tail -3
    ninja -C "${DIR}" -j"${JOBS}" 2>&1 | tail -1
    ninja -C "${DIR}" install > /dev/null
}

build_slice() {
    local KEY="$1" SDK="$2" ARCH="$3" TARGET="$4"
    echo ""
    echo "━━━ libass stack: ${KEY} (${ARCH} for ${SDK}) ━━━"

    local PREFIX="${THIN_DIR}/${KEY}"
    rm -rf "${PREFIX}" "${WORK_DIR}/${KEY}"
    mkdir -p "${PREFIX}" "${WORK_DIR}/${KEY}"
    local CROSS="${WORK_DIR}/${KEY}/cross.txt"
    write_cross_file "${CROSS}" "${SDK}" "${ARCH}" "${TARGET}" "${PREFIX}"

    # No compressed, PNG or HVF fonts and no HarfBuzz autohinting: subtitle fonts are
    # plain TrueType/OpenType, and every option left out is a dependency less.
    meson_build freetype "${KEY}" "${CROSS}" "${PREFIX}" static \
        -Dbrotli=disabled -Dbzip2=disabled -Dharfbuzz=disabled -Dhvf=disabled \
        -Dpng=disabled -Dzlib=disabled -Dtests=disabled

    meson_build fribidi "${KEY}" "${CROSS}" "${PREFIX}" shared \
        -Ddocs=false -Dbin=false -Dtests=false

    # libass shapes with its own FreeType callbacks, so HarfBuzz needs none of
    # its optional backends.
    meson_build harfbuzz "${KEY}" "${CROSS}" "${PREFIX}" static \
        -Dglib=disabled -Dgobject=disabled -Dcairo=disabled -Dchafa=disabled \
        -Dpng=disabled -Dzlib=disabled -Dicu=disabled -Dfreetype=disabled \
        -Dcoretext=disabled -Draster=disabled -Dvector=disabled -Dgpu=disabled \
        -Dgpu_demo=disabled -Dsubset=disabled -Dtests=disabled \
        -Dintrospection=disabled -Ddocs=disabled -Dutilities=disabled \
        -Dbenchmark=disabled

    # The x86_64 slices are simulator/Intel-Mac only; they skip the nasm
    # kernels rather than make nasm a build requirement.
    local ASM="enabled"
    [[ "${ARCH}" == "x86_64" ]] && ASM="disabled"
    meson_build libass "${KEY}" "${CROSS}" "${PREFIX}" static \
        -Dfontconfig=disabled -Dcoretext=enabled -Ddirectwrite=disabled \
        -Dlibunibreak=disabled -Drequire-system-font-provider=true \
        -Dasm="${ASM}" -Dtest=disabled -Dcompare=disabled -Dprofile=disabled \
        -Dfuzz=disabled -Dcheckasm=disabled

    echo "✓ ${KEY} → ${PREFIX}"
}

# The module KSPlayer imports is `libass`. The other three libraries ship no
# headers: nothing outside libass calls them. Xcode copies a static library's
# Headers/ into one shared include/ directory, so a top-level module.modulemap
# would collide with the module.modulemap of any other static xcframework in
# the same build ("Multiple commands produce .../include/module.modulemap").
# Everything therefore sits under Headers/libass/; the module name stays `libass`.
write_headers() {
    local FROM="$1" TO="$2"
    rm -rf "${TO}"
    mkdir -p "${TO}/libass/ass"
    cp "${FROM}/include/ass/ass.h" "${FROM}/include/ass/ass_types.h" "${TO}/libass/ass/"
    cat > "${TO}/libass/module.modulemap" << 'MAPEOF'
module libass {
    header "ass/ass.h"
    export *
}
MAPEOF
}

# make_library <out .a> <thin slice key>...
make_library() {
    local OUT="$1" LIB="$2"
    shift 2
    local INPUTS=()
    for KEY in "$@"; do INPUTS+=("${THIN_DIR}/${KEY}/lib/${LIB}.a"); done
    mkdir -p "${OUT:h}"
    if (( ${#INPUTS} == 1 )); then
        cp "${INPUTS[1]}" "${OUT}"
    else
        lipo -create "${INPUTS[@]}" -output "${OUT}"
    fi
    # Like the FFmpeg frameworks, simulator slices carry no debug info: they
    # never reach an archive or a crash report. Symbols stay for linking.
    if [[ "${OUT}" == */*-simulator/* ]]; then
        strip -S "${OUT}"
    fi
}

# make_dylib_framework <framework dir> <shipped name> <platform> <thin slice key>...
# Packages FriBidi the way build.sh packages the FFmpeg frameworks: one dylib
# per platform with an @rpath install name, a dSYM built from the debug map
# (before strip -x), Info.plist, the versioned bundle layout on macOS, and an
# ad-hoc signature.
make_dylib_framework() {
    local FW_DIR="$1" FW="$2" PLATFORM="$3"
    shift 3
    rm -rf "${FW_DIR}"
    mkdir -p "${FW_DIR}"
    local INPUTS=() DWARFS=() KEY THIN OUT
    for KEY in "$@"; do
        THIN="${THIN_DIR}/${KEY}/lib/libfribidi.dylib"
        INPUTS+=("${THIN}")
        OUT="${BUILD_DIR}/dsyms/thin/${KEY}/${FW}.dSYM"
        rm -rf "${OUT}"
        mkdir -p "${OUT:h}"
        dsymutil --out "${OUT}" "${THIN}"
        local FOUND=("${OUT}/Contents/Resources/DWARF/"*(N))
        if (( ${#FOUND} == 0 )); then
            echo "✗ ${FW} (${KEY}): no debug info; run a full ./build-libass.sh"
            exit 1
        fi
        DWARFS+=("${FOUND[1]}")
    done
    lipo -create "${INPUTS[@]}" -output "${FW_DIR}/${FW}"

    local DSYM="${BUILD_DIR}/dsyms/${PLATFORM}/${FW}.framework.dSYM"
    rm -rf "${DSYM}"
    mkdir -p "${DSYM}/Contents/Resources/DWARF"
    lipo -create "${DWARFS[@]}" -output "${DSYM}/Contents/Resources/DWARF/${FW}"
    cat > "${DSYM}/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleDevelopmentRegion</key><string>English</string>
<key>CFBundleIdentifier</key><string>com.apple.xcode.dsym.com.twosb.${FW}</string>
<key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
<key>CFBundlePackageType</key><string>dSYM</string>
<key>CFBundleSignature</key><string>????</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
<key>CFBundleVersion</key><string>1</string>
</dict></plist>
EOF

    local SUBPATH="${FW}.framework/${FW}"
    [[ "${PLATFORM}" == "macos" ]] && SUBPATH="${FW}.framework/Versions/A/${FW}"
    install_name_tool -id "@rpath/${SUBPATH}" "${FW_DIR}/${FW}"
    strip -x "${FW_DIR}/${FW}"

    local MIN_OS SUPPORTED_PLATFORM
    MIN_OS="$(vtool -show-build "${FW_DIR}/${FW}" | awk '/minos/ {print $2}' | sort -uV | tail -n 1)"
    [[ -n "${MIN_OS}" ]] || { echo "error: cannot read minos from ${FW_DIR}/${FW}" >&2; exit 1; }
    case "${PLATFORM}" in
        ios)            SUPPORTED_PLATFORM="iPhoneOS" ;;
        ios-simulator)  SUPPORTED_PLATFORM="iPhoneSimulator" ;;
        tvos)           SUPPORTED_PLATFORM="AppleTVOS" ;;
        tvos-simulator) SUPPORTED_PLATFORM="AppleTVSimulator" ;;
        xros)           SUPPORTED_PLATFORM="XROS" ;;
        xros-simulator) SUPPORTED_PLATFORM="XRSimulator" ;;
        macos)          SUPPORTED_PLATFORM="MacOSX" ;;
    esac
    cat > "${FW_DIR}/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>${FW}</string>
<key>CFBundleIdentifier</key><string>com.24ventures.twosb.${FW}</string>
<key>CFBundleName</key><string>${FW}</string>
<key>CFBundleVersion</key><string>1.0</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
<key>CFBundlePackageType</key><string>FMWK</string>
<key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
<key>CFBundleSupportedPlatforms</key><array><string>${SUPPORTED_PLATFORM}</string></array>
<key>MinimumOSVersion</key><string>${MIN_OS}</string>
</dict></plist>
EOF

    if [[ "${PLATFORM}" == "macos" ]]; then
        local V="${FW_DIR}/Versions/A"
        mkdir -p "${V}/Resources"
        mv "${FW_DIR}/${FW}"      "${V}/${FW}"
        mv "${FW_DIR}/Info.plist" "${V}/Resources/Info.plist"
        ln -s "A"                          "${FW_DIR}/Versions/Current"
        ln -s "Versions/Current/${FW}"     "${FW_DIR}/${FW}"
        ln -s "Versions/Current/Resources" "${FW_DIR}/Resources"
    fi
    codesign --force --sign - "${FW_DIR}"
}

make_xcframeworks() {
    echo ""
    echo "━━━ Packaging xcframeworks ━━━"
    rm -rf "${OUT_DIR}" "${BUILD_DIR}/fat"
    mkdir -p "${OUT_DIR}"
    local SLICE_GROUPS=(
        "ios:ios-arm64"
        "ios-simulator:isimulator-arm64 isimulator-x86_64"
        "tvos:tvos-arm64"
        "tvos-simulator:tvsimulator-arm64 tvsimulator-x86_64"
        "xros:xros-arm64"
        "xros-simulator:xrsimulator-arm64"
        "macos:macos-arm64 macos-x86_64"
    )
    for ENTRY in "${LIBS[@]}"; do
        local NAME="${ENTRY%%:*}" LIB="${ENTRY##*:}"
        local ARGS=()
        for GROUP in "${SLICE_GROUPS[@]}"; do
            local PLATFORM="${GROUP%%:*}"
            local KEYS=(${=GROUP#*:})
            local FAT="${BUILD_DIR}/fat/${PLATFORM}/${NAME}"
            if [[ "${NAME}" == "TwoSBLibfribidi" ]]; then
                make_dylib_framework "${FAT}/${NAME}.framework" "${NAME}" "${PLATFORM}" "${KEYS[@]}"
                ARGS+=(-framework "${FAT}/${NAME}.framework")
                if [[ "${PLATFORM}" != *simulator ]]; then
                    ARGS+=(-debug-symbols "${BUILD_DIR}/dsyms/${PLATFORM}/${NAME}.framework.dSYM")
                fi
                continue
            fi
            make_library "${FAT}/lib${NAME}.a" "${LIB}" "${KEYS[@]}"
            ARGS+=(-library "${FAT}/lib${NAME}.a")
            if [[ "${NAME}" == "TwoSBLibass" ]]; then
                write_headers "${THIN_DIR}/${KEYS[1]}" "${FAT}/Headers"
                ARGS+=(-headers "${FAT}/Headers")
            fi
        done
        xcodebuild -create-xcframework "${ARGS[@]}" -output "${OUT_DIR}/${NAME}.xcframework" > /dev/null
        echo "✓ ${OUT_DIR}/${NAME}.xcframework"
    done
}

install_into_sources() {
    for ENTRY in "${LIBS[@]}"; do
        local NAME="${ENTRY%%:*}"
        rm -rf "${SOURCES_DIR}/${NAME}.xcframework"
        cp -R "${OUT_DIR}/${NAME}.xcframework" "${SOURCES_DIR}/"
    done
}

record_versions() {
    local FILE="${OUT_DIR:h}/BUILD-INFO-libass.txt"
    {
        echo "libass   ${LIBASS_VERSION}   ${LIBASS_SHA256}"
        local P
        for P in "${SCRIPT_DIR}"/patches/libass-*.patch(N); do
            echo "  patch ${P:t}  sha256 $(shasum -a 256 "${P}" | cut -d' ' -f1)"
        done
        echo "freetype ${FREETYPE_VERSION}   ${FREETYPE_SHA256}"
        echo "fribidi  ${FRIBIDI_VERSION}   ${FRIBIDI_SHA256}"
        echo "harfbuzz ${HARFBUZZ_VERSION}   ${HARFBUZZ_SHA256}"
        echo "clang    $(xcrun clang --version | head -n 1)"
        echo "meson    $(meson --version)"
    } > "${FILE}"
    echo "✓ ${FILE}"
}

if [[ "${MODE}" == "build" ]]; then
    fetch libass "${LIBASS_URL}" "${LIBASS_SHA256}"
    patch_libass_security
    fetch freetype "${FREETYPE_URL}" "${FREETYPE_SHA256}"
    fetch fribidi "${FRIBIDI_URL}" "${FRIBIDI_SHA256}"
    fetch harfbuzz "${HARFBUZZ_URL}" "${HARFBUZZ_SHA256}"

    build_slice ios-arm64          iphoneos         arm64  arm64-apple-ios16.0
    build_slice isimulator-arm64   iphonesimulator  arm64  arm64-apple-ios16.0-simulator
    build_slice isimulator-x86_64  iphonesimulator  x86_64 x86_64-apple-ios16.0-simulator
    build_slice tvos-arm64         appletvos        arm64  arm64-apple-tvos16.0
    build_slice tvsimulator-arm64  appletvsimulator arm64  arm64-apple-tvos16.0-simulator
    build_slice tvsimulator-x86_64 appletvsimulator x86_64 x86_64-apple-tvos16.0-simulator
    build_slice xros-arm64         xros             arm64  arm64-apple-xros1.0
    build_slice xrsimulator-arm64  xrsimulator      arm64  arm64-apple-xros1.0-simulator
    build_slice macos-arm64        macosx           arm64  arm64-apple-macos14.0
    build_slice macos-x86_64       macosx           x86_64 x86_64-apple-macos14.0
fi

make_xcframeworks
record_versions
install_into_sources

echo ""
echo "Sizes:"
for xcf in "${OUT_DIR}"/*.xcframework; do
    echo "  $(du -sh "${xcf}" | cut -f1)  ${xcf:t}"
done
