# nobuffr-ffmpeg

The FFmpeg build used by NoBuffr on iOS, tvOS and macOS. It is FFmpeg plus the libraries it needs, a set of small patches, and the scripts that cross-compile everything into dynamic frameworks (packaged as xcframeworks).

Release version: `9.0.2-nobuffr.1` (FFmpeg n9.0.2 plus our patch set, revision 1).

## Android

The Android app uses a separate, unmodified LGPL FFmpeg 6.0 audio decoder build. Its sources and build script are in [`android/`](android/README.md), released as `6.0-nobuffr-android.1`.

## Upstream versions

| Component | Version | Source |
| --- | --- | --- |
| FFmpeg | n9.0.2 (`release/9.0` at commit `c179411bbb2864cc71323d3055acda25d5c2aace`, which is n9.0.2 plus stable backports) | https://github.com/FFmpeg/FFmpeg |
| dav1d | 1.5.4 | https://code.videolan.org/videolan/dav1d |
| zimg | release-3.0.6 | https://github.com/sekrit-twc/zimg |
| libzvbi | v0.2.46 | https://github.com/zapping-vbi/zvbi |
| OpenSSL | 3.5.9 | https://github.com/openssl/openssl |
| libass | 0.17.5 | https://github.com/libass/libass |
| FreeType | 2.15.0 | https://download.savannah.gnu.org/releases/freetype/ |
| FriBidi | 1.0.18 | https://github.com/fribidi/fribidi |
| HarfBuzz | 15.1.0 | https://github.com/harfbuzz/harfbuzz |

Exact pins, and checksums for the tarballs, are in `build.sh`, `build-libass.sh` and `deps.json`. `BUILD-INFO.txt` records the inputs, toolchain and configure lines of the shipped build.

## Licenses

The FFmpeg parts are **LGPL-3.0-or-later**. FFmpeg is configured with `--enable-version3` (needed to combine with Apache-2.0 OpenSSL), and with neither `--enable-gpl` nor `--enable-nonfree`. From `build.sh`:

```
--enable-openssl --enable-version3
```

`--enable-gpl` and `--enable-nonfree` appear nowhere in the build scripts. Bundled libraries:

| Library | License |
| --- | --- |
| FFmpeg (libavcodec, libavformat, libavutil, libswresample, libswscale, libavfilter) | LGPL-3.0-or-later |
| OpenSSL (static, inside libavformat) | Apache-2.0 |
| dav1d | BSD-2-Clause |
| zimg | WTFPL |
| libzvbi | LGPL-2.0-or-later (conveyed under LGPL-2.1), `ure.c` under MIT |
| libass (static) | ISC |
| FreeType (static) | FreeType License |
| FriBidi (dynamic) | LGPL-2.1-or-later |
| HarfBuzz (static) | MIT |

License texts and notes are in `LICENSES/`. The root `LICENSE` is LGPL-3.0; this project is a modified version of FFmpegBuild by Vincent Herbst.

## Patches

Applied to FFmpeg (files in `patches/`):

- `aac-adtstoasc-pce-bitreader`: aac_adtstoasc: check the bit reader initialization before the PCE (CVE-2026-125225)
- `aom-film-grain-scaling-points`: aom_film_grain: reject scaling points with a repeated x value (CVE-2026-125185)
- `av1-delayed-rap`: AV1: treat full-refresh Delayed Random Access Points as keyframes
- `avstring-strireplace-empty`: avstring: return a copy when av_strireplace() is given an empty search string (CVE-2026-107677)
- `cbs-vp9-superframe-size`: cbs_vp9: check superframe frame sizes without overflowing size_t (CVE-2026-125253)
- `cook-js-subband-start`: cook: reject js_subband_start beyond subbands (CVE-2026-125182)
- `dca-xll-x-heights`: avcodec/dca_xll: decode the height channels of the DTS:X standard presentation
- `encode-frame-size-match`: encode: reject video frames that do not match the encoder (several CVEs)
- `encryption-init-info-free`: encryption_info: free the init info list without recursion (CVE-2026-107678)
- `exif-ifd-bounds`: exif: bound an IFD tree by the size of the EXIF buffer (CVE-2026-125180)
- `flac-parser-score-iterative`: flac_parser: score the header chain without recursion (CVE-2026-125221)
- `hdr-vivid-bits-left`: dynamic_hdr_vivid: check the bits left after reading the counts
- `hdr10plus-t35-count-bounds`: hdr_dynamic_metadata: reject HDR10+ counts above the array bounds
- `hdr10plus-t35-saturation`: hdr_dynamic_metadata: write color saturation outside the tone mapping block (CVE-2026-107676)
- `hevc-pps-3d-depth-lut`: hevc/ps: skip the depth lookup table bits in one step (CVE-2026-125183)
- `hls-vod-segment-refresh`: hls: reload a finished playlist and retry once when segment tokens expire (option `vod_refresh_on_segment_error`)
- `matroska-byte-seek-done`: matroskadec: forget an end of stream after a generic or byte seek
- `matroska-skip-attachments`: matroskadec: option to skip the attached files while opening
- `mpegaudio-bitreader-size`: mpegaudiodec: fail on packets too large for the bit reader (CVE-2026-125072)
- `pcm-bluray-whole-samples`: pcm-bluray: copy only whole samples on big-endian hosts (CVE-2026-125214)
- `rtsp-redirect-limit`: rtsp: limit the number of redirects (CVE-2026-107696)
- `tls-system-trust`: tls_openssl: verify peers with the Apple system trust store (SecTrust) when no ca_file is set
- `vc1dec-slice-buffer-leak`: vc1dec: free the slice buffer when init_get_bits8() fails (CVE-2026-125199)
- `vorbis-parser-extradata-once`: vorbis_parser: parse the extradata only once (CVE-2026-125224)

Applied to libass (files in `patches/`):

- `libass-ass-size-overflows`: ass: size overflow fixes in sub_recode and ass_read_memory
- `libass-render-extreme-values`: render: avoid undefined behavior on extreme numeric input (CVE-2026-95127)

Applied by functions inside `build.sh` (`patch_ffmpeg*`, `patch_zvbi`): an autorelease-pool fix in `vf_yadif_videotoolbox.m`, an empty clearing subtitle for a PGS display set with a missing palette, VC-1 parser seeding from extradata, a visionOS VideoToolbox compile fix, a warning for Matroska `TrackTimestampScale` other than 1, the `dav1` AV1 sample entry, MPEG-TS probing of MPEG-1 audio PIDs, E-AC-3 `dec3` box fixes, a movenc fragment end fix, a few exported internal symbols, and removal of GPL-only files from libzvbi.

## Third-party sources

Bundled in the source archive (`third_party/`), because their licenses require us to provide the source:

- FFmpeg n9.0.2, patched as `build.sh` patches it (LGPL-3.0-or-later)
- FriBidi 1.0.18 (LGPL-2.1-or-later)
- libzvbi v0.2.46 (LGPL-2.0-or-later, conveyed under LGPL-2.1)

Downloaded by the build scripts from their official URLs, pinned by version and checksum or commit:

- dav1d (BSD-2-Clause): `build.sh:21-22`
- zimg (WTFPL): `build.sh:23-24`
- OpenSSL (Apache-2.0): `build.sh:31-32`
- libass (ISC): `build-libass.sh:25-27`, with the two libass patches in `patches/` applied by `build-libass.sh`
- FreeType (FreeType License): `build-libass.sh:29-31`
- HarfBuzz (MIT): `build-libass.sh:35-37`

libass, FreeType, FriBidi and HarfBuzz are pinned to a sha256 of the release tarball. dav1d, zimg and OpenSSL are pinned to a release tag, and `BUILD-INFO.txt` records the commit each tag resolved to. The FFmpeg commit is at `build.sh:19`, FriBidi at `build-libass.sh:32-34`, libzvbi at `build.sh:25-26`.

## Building

Requirements are listed in `toolchain.json` (Xcode with the iOS, tvOS, visionOS and macOS SDKs, meson, ninja, nasm, pkg-config, autoconf, automake, libtool, jq, python3, perl, curl, git, patch). Check your machine with:

```
Scripts/verify-toolchain.sh
```

Then, from the repository root:

```
./build.sh
./build-libass.sh
```

`build.sh` builds FFmpeg, dav1d, zimg, libzvbi and OpenSSL for every slice and writes xcframeworks to `Sources/`. `build-libass.sh` builds libass, FreeType, FriBidi and HarfBuzz the same way. `./build.sh static` makes the static variant. Sources are fetched from the upstream URLs pinned in the scripts. The frameworks keep the historical prefix `TwoSB` (for example `TwoSBLibavcodec`) so they match what NoBuffr ships.

## Using a modified build with the app

The FFmpeg libraries ship as dynamic frameworks inside the app bundle, so you can swap them. Build your own frameworks as above, replace the matching framework in the app's `Frameworks/` folder, and sign the app again (frameworks first, then the app). If you keep the framework names and install names, no other change is needed.

## Contact and copyright

Questions about this build, or a request for the corresponding source: hello@nobuffr.com

Copyright for our modifications (scripts, patches and documentation): 24 Ventures, LLC. FFmpeg and the other libraries remain under their own licenses and copyrights.
