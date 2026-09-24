# ADR 002: Apple Music API network provider and the local-only boundary

Status: proposed; design questions resolved by the product owner 2026-09-24 (see Resolved decisions). Still requires non-author architecture and security approval. Gated by [ADR 001](001-execution-model.md) / #83 (execution model), an explicit `VISION.md` boundary change, and operator credentials. No Apple Music API code is implemented until this is accepted.

## Context

Issue #112 asks for a read-only surface showing what the user played in Apple Music **and when**. Investigation recorded on #112 established two facts from primary sources:

- **Local stores are insufficient.** `~/Music/.../Preferences/History.dat` is a ~146 MB XML plist holding a bounded (~200-item) recently-played list with track `name`, `contentDesc.kind`, and catalog identifiers only — no timestamps, no artist/album names (the bulk is embedded artwork). `Library.musicdb` is the proprietary `hfma` format (not SQLite; this is why existing `music` commands fail closed on it). `MusicCatalogData.db` (SQLite, keyed by `adam_id`) carries `duration`/`all_genres`/`added_date` but no artist/album names and no play times. `Extras.itdb` holds only `cddb`/`uits` identifiers.
- **The Apple Music API is richer but still has no per-play timestamps.** Verified against Apple's documentation: `GET /v1/me/recent/played`, `/v1/me/recent/played/tracks`, `/v1/me/recent/played/stations`, and `/v1/me/history/heavy-rotation` return an ordered array of `Resource` objects with full `attributes` (`name`, `artistName`, `albumName`, `genreNames`, `isrc`, `durationInMillis`, `releaseDate`, `artwork`, `playParams`, catalog `id`) and cursor pagination (`next` + `offset`). **None of the history endpoints carry a `playedAt`/last-played/date attribute.** `GET /v1/me/library/recently-added` exposes `dateAdded`, which is a library-add date, not a play date. "Replay" returns aggregate period summaries, not events.

Therefore **exact playback time is unachievable from any Apple-sanctioned surface** and must be represented honestly as `null`, never synthesized. The API nonetheless provides materially better metadata and a true recency order than the local path, which is the basis for proceeding with integration.

This conflicts with the current product boundary: `VISION.md` ("local-only and read-only unless a future issue explicitly changes that boundary"; "do not become a sync service, daemon, or remote data collector") and ADR 001 ("the default remains local-only and read-only"). #112 plus this ADR constitute the explicit boundary change `VISION.md` requires.

Authentication reality: every `/v1/me/...` call needs both a **developer token** (ES256 JWT minted from a MusicKit `.p8` private key, key id, and team id under an Apple Developer Program account) and a **Music User Token**. Apple documents the user token as automatically managed by MusicKit *for Apple-platform apps and web apps*; a bare SwiftPM CLI executable has **no supported user-authorization flow**. This is the principal engineering hurdle.

## Decision

1. **Re-scope #112.** `music history` returns recently-played resources, newest-first, with bounded limit/pagination. Per item: `title`, `artistName`, `albumName`, `sourceType`/`kind`, catalog `id`, `isrc`, `durationMillis`, optional artwork reference, and `playedAt` = `null` (honest). Human-readable and JSON output follow existing `render(_:format:)` conventions. `--since` is **rejected with an actionable message** (no timestamps exist to filter on) rather than silently ignored; help and docs state this.

2. **Add a networked, read-only Apple Music API provider** as a new read-path class. Only `GET` requests to `api.music.apple.com`. **No mutation** — playlist create/edit, ratings, and favorites stay out of scope per the ADR 001 action boundary and would require a separate `actions` namespace and issue.

3. **Opt-in and explicitly gated.** The provider is `defaultPolling: false`, is inert unless credentials are configured, and returns a clear "not configured / authorization missing or expired" error on absence — never a crash and never a silently empty success. Because listening history is interest-graph data, `music history` **requires `--confirm-sensitive`**, consistent with other high-sensitivity reads.

4. **Secrets and redaction.**
   - Developer token is minted locally from operator-supplied MusicKit key id, team id, and `.p8` path (environment or Keychain). The `.p8`, developer token, and user token are never committed, never persisted by the tool, and never logged.
   - Raw API payloads are not logged. Errors surface HTTP status/class and remediation, not token material or full response bodies. This extends `docs/privacy.md` and the issue's redaction requirement.

5. **Music User Token strategy (decided).** Use an **operator-injected token** supplied via environment or Keychain and obtained from a MusicKit host, with a documented refresh procedure. The CLI never runs an interactive authorization flow itself; missing/expired tokens fail closed with an actionable message. A first-class signed `.app` MusicKit token host is deferred to its own issue because it introduces a second signed identity and packaging surface that interacts with #98 (release) and ADR 001's helper rules.

6. **Resilience and budgets.** Reuse `CrawlBudget` for wall-clock and scan bounds; enforce bounded request timeouts; follow `next`/`offset` only up to the configured limit; map `401`/`403` (invalid/expired developer or user token), `429` (rate limit), and transport/offline errors to distinct, actionable failures. Fail closed.

7. **Provider manifest** (additive under `icloud-cli.providers.v1`): add command `music history`; capabilities such as `history`, `network`, `recents`; `permissionExpectations` such as `apple-developer-program`, `musickit-user-token`, `network-egress-apple-music-api`; `defaultPolling: false`; sensitivity `high` (interest-graph + credentialed). **Add a new `network` value to `sourceKind`** (the registry has only `preferences`/`filesystem`/`sqlite`/`mixed` today); per the `docs/provider-manifest.md` compatibility policy consumers must ignore unknown enum values, so this is additive with no schema bump. Update the ADR 001 classification table to add a "Network API (read-only)" class; note that `music` library inventory (status/playlists/tracks) remains a private-store fallback and only the new `history` read path is network.

8. **Docs and privacy.** Update `docs/privacy.md` (music-history row: interest-graph data, default redaction, tokens/payloads never logged, not polled by default), `README.md`, `CLIHelp`, and add `docs/apple-music-api.md` stating the history window, ordering, pagination, and the explicit "Apple provides no per-play timestamps" limitation. Add a `scripts/live-command-audit.py` catalog entry.

9. **Testing (tests-first per `AGENTS.md`).** Fixture-backed parser tests against recorded, anonymized API JSON — no real tokens and no live network in CI. Cover ordering, pagination/limit bounds, `playedAt`-null honesty, `--since` rejection, redaction (assert tokens and raw payloads never appear in output or logs), auth-failure mapping (401/403/429/offline), and budget/timeout behavior. The privacy-fixture gate (`scripts/check-privacy-fixtures.sh`) must pass with no real identifiers or paths.

10. **Network-only for v1 (decided).** Do **not** enrich results from the local `MusicCatalogData.db`; keep the provider single-source so the read path, provenance, and tests stay simple. Local enrichment may be revisited later as an explicit, separately labeled merge.

11. **No local cache for v1 (decided).** Do **not** persist API responses. Caching would store interest-graph data on disk and conflict with the "do not persist private account data" principle; each invocation fetches fresh, bounded by `CrawlBudget`. The default storefront follows the user token's storefront, and rate-limit (`429`) responses fail closed with an actionable retry message.

## Resolved decisions (2026-09-24)

The product owner resolved the open design questions ("yes to all recommended"); these are now binding for implementation:

1. **Music User Token strategy** → **operator-injected harvested token** (environment or Keychain) with a documented refresh; no interactive auth flow in the CLI. A signed `.app` MusicKit host is deferred to a future issue. (Decision 5.)
2. **`sourceKind`** → **add `network`** as an additive enum value; no schema bump. (Decision 7.)
3. **Sensitivity gate** → **`music history` requires `--confirm-sensitive`.** (Decision 3.)
4. **Local enrichment** → **none for v1; network-only.** (Decision 10.)
5. **Caching / rate limits** → **no local cache for v1;** default storefront from the user token, `429` fails closed with an actionable retry message. (Decision 11.)

Remaining implementation-time details (non-blocking): the exact `music history` flag set and JSON field names, the artwork-reference shape, and the anonymized fixture corpus.

## Consequences

- Changes the long-standing local-only invariant and adds a network-egress plus secrets surface that requires security review and operator credential management.
- Delivers richer, correctly-ordered recently-played metadata than the local path, but `playedAt` remains `null`: the issue's "and when" stays unmet by Apple's design, and the docs must say so plainly rather than imply a timestamp.
- No daemon, no background collection, no mutation; read-only `GET`s only; opt-in; not in the default polling set.
- Establishes the contract and precedent for any future networked Apple API provider, including the OpenClaw "media history" view (Apple Books progress, Audible) referenced in #112.

## Approval gate

The product owner has approved the design direction and resolved the open questions (2026-09-24). This ADR still becomes accepted only after **non-author architecture and security approval**, an explicit `VISION.md` boundary update, resolution of #83 as it applies to networked providers, and provisioning of operator credentials (Apple Developer Program + MusicKit `.p8`). Until then, the local-only/read-only default and the daemon non-goal remain authoritative, and no Apple Music API code is implemented.
