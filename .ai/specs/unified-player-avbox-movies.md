# Unified player and AVBox Movies

## Why

Hyper-PiliPlus currently exposes three visibly and behaviorally different playback paths: the normal PiliPlus video player, Bilibili/Pure Live playback, and the existing Gimy-based Movies shell. Replace that split with one PiliPlus player language and make AVBox the Android Movies experience.

## What

- Android Movies opens an embedded AVBox experience pinned to upstream commit `72e007e398d2a5e924f20e7039fd5fcd49c506f9`; the old Gimy catalog/WebView implementation is removed.
- AVBox is imported without its Git metadata, signing files, signing configuration, launcher entry, or bundled secrets. Its AGPL-3.0 license and source provenance remain visible.
- AVBox's own bottom destinations move to a top `IosLiquidGlassNavigationBar` treatment; Hyper-PiliPlus main destinations stay in their current position and continue using the existing native glass component.
- Bilibili live and Pure Live use the PiliPlus `PLVideoPlayer` controls. Movies keeps AVBox's native Media3 player because its source-specific hard/software decode fallback, fresh URL resolution, player fallback, and line switching are part of playback correctness rather than replaceable presentation code.
- Non-Android Movies displays an explicit Android-only availability state instead of the removed Gimy implementation.

## Context

**Relevant files:**
- `lib/pages/movies/` — current Gimy catalog to replace with the AVBox bridge/fallback.
- `lib/pages/pure_live_follow/playback_page.dart` — standalone media_kit player to migrate onto PiliPlus player controls.
- `lib/pages/live_room/` and `lib/plugin/pl_player/` — existing live and canonical PiliPlus playback patterns.
- `lib/pages/main/view.dart` — native navigation visibility and destination synchronization.
- `android/app/src/main/kotlin/com/aritxonly/hyperpiliplus/` — Flutter/native bridge and Miuix glass overlay.
- `third_party/avbox/` — vendored AVBox Android library, fixed to the audited commit.

**Key decisions already made:**
- The user accepted AVBox's AGPL-3.0 obligations and Android-only integration on 2026-11-13.
- The combined repository remains source-available; AVBox-derived files retain AGPL-3.0 notices and provenance.
- No external signing material or repository secrets are imported.
- Playback behavior takes priority over superficial skinning: `PLVideoPlayer` owns the Flutter video/live paths, while AVBox retains its upstream Media3 recovery chain for Movies.

## Constraints

**Must:**
- Preserve existing Bilibili video/live interactions, Pure Live danmaku/quality/line selection, route back behavior, overlays, and native-navigation occlusion.
- Keep the pinned Flutter 3.47.4 wrapper and current Android signing flow.
- Use the app `ColorScheme`; all main destination navigation must use the Miuix `IosLiquidGlassNavigationBar` visual language.
- Record AVBox commit, license, modifications, and corresponding-source location.

**Must not:**
- Import AVBox `.git`, `.key`, keystores, passwords, generated APKs, caches, or launcher identity.
- Preconfigure third-party content sources or bypass content access controls.
- Route AVBox media into `PLVideoPlayer` unless its complete source-specific recovery behavior has first been reproduced and verified there.
- Push, tag, or publish without a separate explicit push request.

## Tasks

### T1: AVBox library and Android bridge

**Do:** Vendor the pinned source as a non-launcher Android library, adapt application startup safely, expose a Flutter `PlatformView` bridge that renders AVBox directly inside the Movies tab, move its navigation to the top glass style, and preserve AGPL/provenance notices.

**Verify:** Gradle compiles the AVBox module and Flutter debug/release Android compilation reaches packaging without imported signing data.

### T2: Movies replacement

**Do:** Delete the Gimy catalog and tests, replace Movies with an embedded Android AVBox destination and a clear non-Android state, and keep native navigation visibility/return behavior coherent.

**Verify:** Widget tests cover both supported and unsupported platform states; selecting Movies keeps `MainActivity` active, renders AVBox immediately, and returns without duplicate navigation bars.

### T3: Player convergence

**Do:** Introduce reusable external-source `PLVideoPlayer` controls for Pure Live and align live controls with the canonical player. Keep AVBox Movies on its upstream Media3 engine so ordinary resolved URLs still receive AVBox's decode, re-resolve, kernel, and line fallback behavior.

**Verify:** Targeted tests cover headers, source switching, lifecycle, and controls; existing video/live tests remain green.

### T3.1: Pure Live orientation and responsive layout

**Do:** Feed decoded video width, height, and portrait state into `PlPlayerController`; rotate an active fullscreen session when the stream aspect changes; use player-only fullscreen, stacked portrait layout, and split landscape layout without shrinking controls or touch targets.

**Verify:** Portrait and landscape streams choose the matching fullscreen orientation, exiting playback restores the app orientation, and the interaction panel has no overflow at narrow landscape widths or enlarged text sizes.

### T4: UI and delivery verification

**Do:** Audit main/player/navigation surfaces against the Miuix glass reference, format/analyze/test, build signed split Release APKs, verify signature/package/version, then launch and smoke-test Home, Movies, Live, playback, top navigation, back, and overlays.

**Verify:** `./scripts/flutterw test --no-pub`, targeted analyze, `git diff --check`, signed APK verification, and actual Android UI-path evidence.

## Status

- [x] Old Movies implementation is absent and Android Movies now owns an embedded AVBox `PlatformView`; physical-device rendering remains a delivery smoke test.
- [x] AVBox's destination navigation is top-positioned and always uses the `IosLiquidGlassNavigationBar` component layout; Hyper-PiliPlus's existing main navigation remains unchanged.
- [x] Pure Live uses the canonical PiliPlus player controls; AVBox Movies retains the upstream Media3 playback and recovery chain for all resolved media.
- [x] AVBox AGPL/provenance and source link are accessible; no signing files, launcher identity, Git metadata, or generated APKs were imported.
- [x] The AVBox AppCompat crash path is themed, and AndroidAutoSize has been removed so it cannot rewrite host `DisplayMetrics`.
- [x] Pure Live forwards decoder dimensions into the common player and has dedicated portrait, landscape, and fullscreen layouts.
- [ ] Signed split Release APKs are rebuilt and verified from the final source state.
- [ ] Physical-device smoke tests pass for cold start, floating navigation, embedded Movies, AVBox subscription management, and Pure Live portrait/landscape playback.
