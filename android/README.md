# Android FFmpeg decoder

The NoBuffr Android app (phone and Android TV) decodes some audio formats in software with
FFmpeg, through Google's Media3 FFmpeg extension. This folder holds what is needed to rebuild
that component.

Release version: `6.0-nobuffr-android.1`.

## What is shipped

`libffmpegJNI.so` (arm64-v8a, armeabi-v7a, x86, x86_64) inside the decoder AAR. It contains:

| Component | Version | License | Source |
| --- | --- | --- | --- |
| FFmpeg (libavcodec, libavutil, libswresample), static | `release/6.0` at commit `37c90f55d8b6c3948c79449b04755527b4ae1351` | LGPL-2.1-or-later | https://github.com/FFmpeg/FFmpeg |
| Media3 FFmpeg extension (`libraries/decoder_ffmpeg`) | androidx/media `1.10.0` | Apache-2.0 | https://github.com/androidx/media |

FFmpeg is unmodified. It is configured by the extension's `build_ffmpeg.sh` with
`--disable-everything` plus these decoders only:
`flac alac pcm_mulaw pcm_alaw mp3 aac ac3 eac3 dca mlp truehd`.
Neither `--enable-gpl` nor `--enable-nonfree` is used, so the build is LGPL-2.1-or-later.

Build settings: NDK `26.1.10909125`, Android API level 23.

## Rebuild

```
./build-android.sh [WORK_DIR]
```

The script fetches the pinned FFmpeg commit and androidx/media `1.10.0`, builds FFmpeg with the
NDK, and builds the AAR. To relink with a modified FFmpeg, change the FFmpeg tree in
`WORK_DIR/ffmpeg` and run the script again; the resulting AAR is a drop-in replacement for the
one in the app.

`media3-decoder-ffmpeg-jni/` is a copy of the extension's JNI sources (`ffmpeg_jni.cc`,
`CMakeLists.txt`, `build_ffmpeg.sh`) from androidx/media `1.10.0`, under the Apache License 2.0
(`LICENSE-Apache-2.0`).

The complete corresponding source (FFmpeg tree, extension sources and this script) is also
attached to the `6.0-nobuffr-android.1` release.

## Contact

hello@nobuffr.com
