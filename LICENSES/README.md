nobuffr-ffmpeg is a modified version of FFmpegBuild by Vincent Herbst. Modified by 24 Ventures, LLC. Modifications (C) 2026 24 Ventures, LLC.

# Third-party licenses

FFmpegBuild's shipped xcframeworks aggregate the following components. Apps
that distribute these frameworks must reproduce the applicable license texts
(for example on an acknowledgements screen or in bundled documentation).

| Component | Frameworks | License | Text |
| --- | --- | --- | --- |
| FFmpeg (libavcodec, libavformat, libavutil, libswresample, libswscale, libavfilter) | `TwoSBLibavcodec`, `TwoSBLibavformat`, `TwoSBLibavutil`, `TwoSBLibswresample`, `TwoSBLibswscale`, `TwoSBLibavfilter` | LGPL-3.0-or-later | [LGPL-3.0.txt](LGPL-3.0.txt), [GPL-3.0.txt](GPL-3.0.txt) |
| OpenSSL (libssl, libcrypto; static, inside libavformat) | `TwoSBLibavformat` | Apache-2.0 | [openssl.Apache-2.0.txt](openssl.Apache-2.0.txt) |
| dav1d | `TwoSBLibdav1d` | BSD-2-Clause | [dav1d.BSD-2-Clause.txt](dav1d.BSD-2-Clause.txt) |
| zimg | `TwoSBLibzimg` | WTFPL | [zimg.WTFPL.txt](zimg.WTFPL.txt) |
| libzvbi (library sources) | `TwoSBLibzvbi` | LGPL-2.0-or-later (conveyed under LGPL-2.1), `ure.c` under MIT | [LGPL-2.1.txt](LGPL-2.1.txt), [libzvbi-ure.MIT.txt](libzvbi-ure.MIT.txt) |
| libass (static) | `TwoSBLibass` | ISC | [libass.ISC.txt](libass.ISC.txt) |
| FreeType (static), used under the FreeType License option; BDF/PCF driver and `fthash.c` parts under MIT-style terms | `TwoSBLibfreetype` | FTL | [freetype.FTL.txt](freetype.FTL.txt), [freetype-bdf-pcf.MIT.txt](freetype-bdf-pcf.MIT.txt) |
| GNU FriBidi (dynamic) | `TwoSBLibfribidi` | LGPL-2.1-or-later | [LGPL-2.1.txt](LGPL-2.1.txt) |
| HarfBuzz (static) | `TwoSBLibharfbuzz` | MIT ("Old MIT") | [harfbuzz.MIT.txt](harfbuzz.MIT.txt) |

Notes:

- FFmpeg is configured with `--enable-version3` and `--enable-openssl`
  (OpenSSL 3 is Apache-2.0, which FFmpeg only combines with the version 3
  licenses), so the FFmpeg portions are LGPL-3.0-or-later. LGPL-3.0 is a set
  of additional permissions on top of GPL-3.0, so both texts ship. There is
  still no `--enable-gpl`: no GPL-only FFmpeg code is compiled in. The exact
  configure flags are in [build.sh](../build.sh).
- OpenSSL is built from unmodified upstream sources as static libraries and
  linked into `TwoSBLibavformat` only. None of its symbols are exported from
  that framework. Apache-2.0 section 4 asks you to pass its license text on
  with the binary, which the row above covers.
- libzvbi's tree contains three GPL-2 licensed source files
  (`packet-830.c`, `pdc.c`, `exp-vtx.c`). `build.sh` removes them from the
  library and replaces the two referenced entry points with LGPL stubs, so no
  GPL code is compiled into the shipped binaries. This is a modification of
  libzvbi in the sense of LGPL section 2; the modification is published in
  `build.sh` (`patch_zvbi`).
- The FFmpeg sources also carry a small set of local patches, which modify
  FFmpeg in the same LGPL section 2 sense. Each one is listed and explained
  in the top-level [README](../README.md#local-ffmpeg-patches) and applied by
  the `patch_ffmpeg*` functions in [build.sh](../build.sh), where its code is
  published.
- dav1d and zimg are built from unmodified upstream sources.
- The subtitle stack (libass, FreeType, FriBidi, HarfBuzz) is built by
  [build-libass.sh](../build-libass.sh) from release tarballs pinned by
  SHA-256. FreeType, FriBidi and HarfBuzz are unmodified; libass carries the
  two `patches/libass-*.patch` security fixes, applied by
  `patch_libass_security`. libass, FreeType and HarfBuzz ship as static libraries;
  FriBidi, being LGPL, ships as a dynamic framework like the FFmpeg
  libraries. FreeType is offered under
  either the FTL or GPL-2.0; it is taken under the FTL, whose credits
  clause says that a program using any part of FreeType must acknowledge
  somewhere in its documentation that it has used the FreeType code. An
  app that ships these frameworks must therefore carry that acknowledgement in
  its own documentation (for example its licenses or acknowledgements
  screen). Ready-to-paste line (the year is the one from the FreeType
  version used, 2.15.0):

  > Portions of this software are copyright © 2026 The FreeType Project (https://freetype.org). All rights reserved.

  Its gzip module is not built. No fontconfig is
  built: fonts come from libass's CoreText provider.
