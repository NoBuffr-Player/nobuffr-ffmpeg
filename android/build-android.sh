#!/usr/bin/env bash
# Builds the FFmpeg audio decoder used by the NoBuffr Android app: Google's Media3 FFmpeg
# extension (androidx/media libraries/decoder_ffmpeg, Apache-2.0) on top of an LGPL FFmpeg.
#
# FFmpeg is configured by Google's build_ffmpeg.sh without --enable-gpl or --enable-nonfree
# (LGPL-2.1-or-later), with only the audio decoders listed below, and linked statically into
# libffmpegJNI.so inside the AAR.
#
# Usage: build-android.sh [WORK_DIR]   (default: $TMPDIR/nobuffr-ffmpeg-android)
# Needs: git, Java 17+, Android SDK with NDK 26.1.10909125 (sdkmanager "ndk;26.1.10909125")
# Env:   ANDROID_SDK_ROOT / ANDROID_HOME (default ~/Library/Android/sdk or ~/Android/Sdk)
# Output: WORK_DIR/out/media3-ffmpeg-decoder-1.10.0-1.aar
set -euo pipefail

MEDIA3_TAG="1.10.0"
FFMPEG_REPO="https://github.com/FFmpeg/FFmpeg.git"
FFMPEG_COMMIT="37c90f55d8b6c3948c79449b04755527b4ae1351" # release/6.0
NDK_VERSION="26.1.10909125"
ANDROID_API=23
ENABLED_DECODERS=(flac alac pcm_mulaw pcm_alaw mp3 aac ac3 eac3 dca mlp truehd)
ARTIFACT_VERSION="1.10.0-1"

WORK_DIR="${1:-${TMPDIR:-/tmp}/nobuffr-ffmpeg-android}"
mkdir -p "$WORK_DIR"
WORK_DIR="$(cd "$WORK_DIR" && pwd)"

case "$(uname -s)" in
  Darwin) HOST_PLATFORM="darwin-x86_64" ;;
  Linux) HOST_PLATFORM="linux-x86_64" ;;
  *) echo "unsupported host $(uname -s)" >&2; exit 1 ;;
esac

SDK="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"
if [ -z "$SDK" ]; then
  for d in "$HOME/Library/Android/sdk" "$HOME/Android/Sdk"; do [ -d "$d" ] && SDK="$d" && break; done
fi
NDK_PATH="$SDK/ndk/$NDK_VERSION"
[ -d "$NDK_PATH" ] || { echo "NDK $NDK_VERSION missing: sdkmanager \"ndk;$NDK_VERSION\"" >&2; exit 1; }
export ANDROID_HOME="$SDK" ANDROID_SDK_ROOT="$SDK"

MEDIA_DIR="$WORK_DIR/media"
FFMPEG_DIR="$WORK_DIR/ffmpeg"

if [ ! -f "$MEDIA_DIR/libraries/decoder_ffmpeg/build.gradle" ]; then
  rm -rf "$MEDIA_DIR"
  git clone -q --depth 1 --branch "$MEDIA3_TAG" https://github.com/androidx/media "$MEDIA_DIR"
fi

if [ ! -d "$FFMPEG_DIR/.git" ] || [ "$(git -C "$FFMPEG_DIR" rev-parse HEAD 2>/dev/null)" != "$FFMPEG_COMMIT" ]; then
  rm -rf "$FFMPEG_DIR"
  mkdir -p "$FFMPEG_DIR"
  git -C "$FFMPEG_DIR" init -q
  git -C "$FFMPEG_DIR" remote add origin "$FFMPEG_REPO"
  git -C "$FFMPEG_DIR" fetch -q --depth 1 origin "$FFMPEG_COMMIT"
  git -C "$FFMPEG_DIR" checkout -q FETCH_HEAD
fi

JNI_DIR="$MEDIA_DIR/libraries/decoder_ffmpeg/src/main/jni"
ln -sfn "$FFMPEG_DIR" "$JNI_DIR/ffmpeg"
(cd "$JNI_DIR" && ./build_ffmpeg.sh "$MEDIA_DIR/libraries/decoder_ffmpeg/src/main" "$NDK_PATH" "$HOST_PLATFORM" "$ANDROID_API" "${ENABLED_DECODERS[@]}")

(cd "$MEDIA_DIR" && nb-build ./gradlew --no-daemon :lib-decoder-ffmpeg:assembleRelease)

AAR="$(find "$MEDIA_DIR/libraries/decoder_ffmpeg" -name '*release*.aar' | head -1)"
[ -f "$AAR" ] || { echo "release AAR not found" >&2; exit 1; }
mkdir -p "$WORK_DIR/out"
cp "$AAR" "$WORK_DIR/out/media3-ffmpeg-decoder-$ARTIFACT_VERSION.aar"
echo "Built $WORK_DIR/out/media3-ffmpeg-decoder-$ARTIFACT_VERSION.aar"
