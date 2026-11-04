# Pure Live backup migration

## User outcome

From Settings → About, select a Pure Live v3 `.txt`/`.json` backup, review a migration summary, and merge supported live-room favorites plus compatible preferences into Hyper-PiliPlus. The user can also export and restore a Hyper-PiliPlus migration backup.

## Compatibility and data boundaries

- Read the Pure Live `backupVersion: 3` format used by `Joe-Mu-Yu/pure_live`.
- Convert supported favorite room records into the existing `LiveFavorite` model. Preserve existing favorites and deduplicate by platform/room identity.
- Import only preference fields with a confirmed same-name/same-meaning mapping. Do not import account credentials, cookies, WebDAV secrets, proxy credentials, or location/broadcast consent.
- Hyper-PiliPlus export uses its own versioned format. It does not claim to be a complete Pure Live backup because Hyper-PiliPlus has no matching live-room history or all Pure Live preference models.
- Show unsupported/invalid favorite counts and the live-history count before import; do not silently discard them.
- Parse and validate the complete file before any Hive mutation.

## Acceptance

- Unit tests cover v3 parsing, favorite conversion, malformed data rejection, merge/deduplication, safe preference mapping, and Hyper-PiliPlus export/import round-trip.
- When the provided backup is supplied as `PURE_LIVE_BACKUP_TEST_FILE`, the parser recognizes its actual counts without persisting its personal data in the repository.
- Format, analyze/tests, signed Release APK, signature/version checks, and `git diff --check` follow repository instructions.
