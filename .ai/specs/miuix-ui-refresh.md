# Miuix-inspired UI refresh

## Goal

Use Miuix as the visual reference for Hyper-PiliPlus across the Flutter app and
the Android floating navigation bar. Keep existing navigation, player, feed,
recorder, and dialog behavior intact.

Miuix is a Compose Multiplatform library, so Flutter pages use the same visual
language through the app's existing `ThemeUtils` and Flutter widgets. The
Android floating bar continues to use the existing native Compose Miuix
implementation.

## Design rules

- Follow the selected light/dark mode and accent palette; do not pin pages to a
  separate brand palette.
- Use neutral Miuix-like surfaces and softly rounded superellipse shapes for
  shared cards, dialogs, sheets, and buttons.
- Keep media artwork and page-specific content layouts intact unless a layout
  change is needed for a coherent Miuix presentation.
- Keep Android status-bar contrast in sync with the active theme.
- Use the official Miuix floating bar and item components. Keep route selection,
  drag-to-select, occlusion, and diagnostic sampling lifecycle.

## Work sequence

1. Apply shared shape tokens through `ThemeUtils` so normal Flutter routes
   inherit the same component language.
2. Remove conflicting page-level palettes from home, dynamics, and Movies;
   make the Movies WebView theme follow the active `ColorScheme`.
3. Audit remaining page-specific colors and shapes for overrides that break
   light/dark mode or the selected accent, preserving explicit user settings.
4. Verify light and dark themes, navigation and overlay behavior, Movies search
   and playback, and the floating bar on Android.

## Acceptance

- Main Flutter routes follow the selected theme and accent in light and dark
  modes without isolated Netflix-red or fixed-black palettes.
- Shared cards, dialogs, bottom sheets, and buttons use the Miuix-inspired
  rounded shape tokens.
- The native floating bar uses Miuix's official component visuals and active
  theme colors while keeping click, drag selection, and diagnostics available.
- Existing page interactions remain available; Android UI behavior is checked
  on a running build before calling the refresh complete.

## Progress

- Shared Flutter theme now applies rounded superellipse shapes to cards,
  dialogs, sheets, and standard buttons.
- Home, dynamics, Movies, and Pure Live playback follow the active theme instead
  of page-specific fixed palettes; the Movies WebView CSS also uses the active
  `ColorScheme`.
- The native bar now calls the pinned Miuix `FloatingNavigationBar` and
  `FloatingNavigationBarItem` directly. It uses Miuix's default `surfaceContainer`
  surface, rounded shape, shadow, spacing, icon sizing, and selected/unselected
  colors; the previous custom glass surface and selection capsule are removed.
  All six routes remain available as icon-only items with accessible labels,
  even though the official docs describe a recommended range of two to five.
  Drag selection is retained as an app-level gesture using the same Miuix item
  selected state.
- The pinned Flutter 3.47.4 SDK was restored in this worktree, and only the
  stale Flutter SDK roots in the ignored local package config were redirected
  to it. `./scripts/flutterw test --no-pub` passes all 137 tests.
- Signed Release APKs for all three ABIs built as version `2.1.4.0` and passed
  `apksigner` verification. The arm64 APK installed and launched on a Pixel 8
  API 37 AVD. Home, Movies, search results, and movie details rendered; the
  floating bar remained visible, and no app crash was observed. After the bar
  adjustment, its six distinct icons and selected state were visible, and
  tapping Movies opened the Movies route.
- Playback and screen-on behavior passed on the Pixel 8 API 37 AVD using the
  QY source for episode 1 of `小城良方`: video advanced from `00:04` to
  `00:52`. With the AVD screen-off timeout temporarily set to 15 seconds, the
  display stayed awake during playback and Android reported a
  `SCREEN_BRIGHT_WAKE_LOCK` attributed to the app. The original AVD timeout
  (`2147483647`) was restored afterward. One initial playback attempt returned
  a transient WebView TLS error; retrying the same source loaded and played.
- The simulator confirmed taps on all six bar destinations and drag selection
  from Movies to Recording. Light/dark switching remains unverified.
- `git diff --check` passes.
