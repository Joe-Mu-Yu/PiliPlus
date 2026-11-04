# Native movie catalog shell

## Scope

- Replace the Movies tab's home page with a native PiliPlus-styled discovery/search UI.
- Use the currently reachable SOTVLA hot-list JSON endpoint and the search page's embedded result payload for the proof of concept.
- Keep the existing SOTVLA detail/playback page in the in-app WebView; do not extract or proxy media streams.
- Do not transfer browser cookies, account credentials, or source selections into the app.

## Acceptance

- The Movies tab shows native search and categorized poster rows, with loading/error/retry states.
- Search renders native result cards from the currently returned response payload.
- Tapping a result opens its SOTVLA detail URL inside the app, not an external browser.
- No permanent WebView toolbar or floating web-tools button is shown.
- Parsing and navigation have targeted tests; APK builds, installs, launches, and the Movies/search path is smoke-tested on the configured emulator.

## Known integration constraint

SOTVLA's hot-list JSON and server-rendered search bootstrap were observed working at implementation time, but no supported public API contract was found. The implementation must isolate this adapter and fail visibly if its response changes. This is a prototype, not a claim of API support or a long-term availability guarantee.
