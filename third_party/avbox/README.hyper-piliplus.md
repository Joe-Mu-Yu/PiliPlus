# AVBox in Hyper-PiliPlus

This directory contains a source snapshot of
[XiaochangXu/AVBox](https://github.com/XiaochangXu/AVBox) at commit
`72e007e398d2a5e924f20e7039fd5fcd49c506f9`.

AVBox is licensed under GNU AGPL-3.0. The unmodified license text is retained
in [`LICENSE`](LICENSE). Hyper-PiliPlus distributes the corresponding source in
this `third_party/avbox` directory alongside the combined application source.

## Hyper-PiliPlus modifications

- Converted the standalone Android application to non-launcher library modules.
- Removed upstream signing configuration, signing material, launcher identity,
  broad storage/install-package permissions, and exported import activities.
- Added a lazy embedded runtime so AVBox does not replace the Flutter host
  `Application` or its locale configuration.
- Moved AVBox's horizontal destination navigation from the bottom to the top
  and aligned its capsule, 64/56 dp geometry, labels, accent state, refraction,
  press/drag response, and backdrop sampling with the Miuix
  `IosLiquidGlassNavigationBar` visual language; the adaptive side rail remains
  for wide layouts.
- Updated the embedded Python runtime to 3.11 for the host build environment;
  the parser falls back to Python's standard `json` module when `ujson` is not
  available for Android Python 3.11.
- Assigned the source-empty QuickJS dependency bridge a unique Android
  namespace so it does not collide with the upstream wrapper AAR.
- Moved the bundled RTMP AAR's runtime packaging to the final host application;
  AVBox keeps it as `compileOnly` so AGP 9 produces a valid library AAR.
- Builds the embedded Python runtime for the host's three split APK ABIs. The
  vendored Thunder native SDK remains limited to the ABI supplied upstream;
  this limitation applies to Thunder/magnet playback, not ordinary remote URLs.
- Retains AVBox's native Media3 playback engine, including its hardware/software
  decoder fallback, fresh-resolve retry, player fallback, and line switching.
  Resolved media is not handed to Flutter because that would bypass AVBox's
  source-specific playback recovery. No content source is bundled or
  preconfigured.

Files derived from AVBox remain subject to AGPL-3.0. Host-specific bridge files
outside this directory follow the repository's root license.
