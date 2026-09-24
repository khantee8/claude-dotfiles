# cyber.nanoteofficial.me v1.2 — Threat Intel production pass — Design Spec

**Date:** 2026-09-24 · **Repos:** `khantee8/cyber.nanoteofficial.me` (v1.2.0), `khantee8/nanoteofficial.me` (patch) · **Status:** approved in chat, 2026-09-24

## 1. Problem

- Refresh happens on a page request: when the 15-minute `unstable_cache` expires, one visitor's request fetches all eight upstream feeds (KEV alone is 1.7 MB) before the page renders.
- When a feed fails, its panels show the committed `fallback.json`, frozen on **2026-09-08** — it reads as mock data.
- The portfolio's `nanoteofficial.me/cyber` preview is a hand-written fake CVE feed.

Owner's goals: real data only, lighter on resources, **no cost** (stay on Vercel Hobby, GitHub free, Neon free tier).

## 2. Decisions

| # | Decision |
|---|---|
| D1 | Refresh in the background into Neon; pages never call upstream (approach 1 of 3) |
| D2 | Keep the last good copy per source; show its real age instead of an old committed file |
| D3 | Cadence 30 min (GitHub Actions) + daily Vercel cron backstop — chosen for the Neon free-tier compute budget (§6) |
| D4 | Page cache invalidated by the refresh job, not by a timer — visitor traffic adds almost no DB wake-ups |
| D5 | Portfolio `/cyber` becomes a permanent redirect to https://cyber.nanoteofficial.me; the fake feed page is deleted |

## 3. Data model (additive)

```ts
intel_source (
  source        text PK      -- 'kev' | 'epss' | 'ransomware' | 'feodo' | 'isc' | 'news'
  data          jsonb null   -- parsed, trimmed payload as the aggregate consumes it; null until first success
  fetchedAt     timestamp null  -- last successful fetch (or 304 confirmation)
  attemptedAt   timestamp not null
  error         text null    -- last failure message, cleared on success
  etag          text null
  lastModified  text null
)
```

Only what the UI shows is stored (e.g. the newest N KEV entries, not the whole catalogue). Target row size < 200 KB; total < 1 MB.

## 4. Refresh job

- `GET /api/cron/intel` — requires `Authorization: Bearer $CRON_SECRET`; 401 otherwise. `maxDuration` 60 s.
- For each source: call the existing `fetch*` (never throws) via a thin wrapper that adds conditional-request headers where the source supports them (KEV: `If-None-Match` / `If-Modified-Since`).
  - 200 + parses → replace `data`, set `fetchedAt`, clear `error`, store validators.
  - 304 → keep `data`, bump `fetchedAt`.
  - failure → keep `data` and `fetchedAt`, set `error`, bump `attemptedAt`.
- EPSS is fetched only for the CVEs present in the KEV rows being shown (as today).
- One upsert per source; then `revalidateTag('intel')`.
- Returns `{ sources: { [id]: 'ok' | 'not_modified' | 'failed' } }` — no data in the response.
- Pure core, unit-tested: `mergeSourceRow(prev, result, now) → next`.

**Triggers**
- `.github/workflows/intel-refresh.yml`: `schedule: '*/30 * * * *'` + `workflow_dispatch`; one `curl -fsS -H "Authorization: Bearer ${{ secrets.CRON_SECRET }}"`; the repo is public, so Actions minutes are free.
- `vercel.json` cron: once daily (Hobby limit) as a backstop. Vercel sends `CRON_SECRET` as the bearer automatically.

## 5. Read path

- `getIntelSnapshot()` = `unstable_cache(readSnapshotFromDb, ['intel-snapshot-v2'], { tags: ['intel'], revalidate: 3600 })`. The one-hour timer is only a safety net; the refresh job invalidates the tag every 30 min.
- `readSnapshotFromDb`: one `select * from intel_source`, then the existing `buildIntelSnapshot` logic assembles panels from rows instead of live fetches (refactor: split "fetch" from "assemble").
- Health per source, from `fetchedAt` age (pure, tested): `< 60 min` → `live`; older → `stale` (UI shows "updated 3 h ago"); never succeeded → `down`.
- `fallback.json` is used only when `DATABASE_URL` is unset (build, tests) or the table is empty / unreachable — never as a routine substitute. The Sep 8 file is refreshed once in this release so first-deploy output is current.
- `/`, `/intel`, `/api/intel` unchanged in shape; `/api/intel` keeps its response format.

## 6. Cost budget (free tiers)

| Resource | Usage | Free allowance |
|---|---|---|
| GitHub Actions | 48 runs/day × ~10 s | Unlimited for public repos |
| Vercel function invocations | ~49/day for refresh + page renders | Hobby limits, far below |
| Neon compute | ~48 wake-ups/day × ≤ 5 min ≈ 4 h/day at 0.25 CU ≈ 30 CU-h/month, plus GRC use | Free plan compute allowance; keep refresh at 30 min, never faster |
| Upstream bandwidth | KEV only when changed (304 otherwise); other feeds < 100 KB each | — |

If Neon usage approaches its limit, the cadence goes to 60 min (one-line change) before anything costs money.

## 7. UI

- Each panel header shows its own age ("updated 12 min ago"); stale panels use the existing stale style plus the age. The landing HUD uses the snapshot's newest `fetchedAt`.
- No layout changes.

## 8. Portfolio

- `nanoteofficial.me`: add `/cyber` and `/cyber/:path*` → `https://cyber.nanoteofficial.me` permanent redirects in `next.config.ts` (same pattern as `/plan`), delete `src/app/cyber/` (page + OG image). `proxy.ts` subdomain rewrite for `cyber` is unaffected (the subdomain is bound to its own Vercel project). Patch release.
- The public Tools map already lists cyber as live; no connection change, so `tools.nanoteofficial.me` is untouched.

## 9. Testing

Vitest, no network:
- `mergeSourceRow`: success replaces; 304 keeps data and bumps `fetchedAt`; failure keeps data and records error; first failure leaves `data` null.
- `healthFromAge`: boundaries at 59/60 min; null → down.
- Snapshot assembly from rows matches the existing aggregate output for the fixtures.
- Cron route auth: pure helper `isAuthorised(header, secret)` (missing/wrong/right; empty secret always false).
Gate unchanged (build with `DATABASE_URL` empty). Manual: run the endpoint locally against the Docker DB twice (second run: KEV 304), then load `/intel`.

## 10. Release

1. Additive migration (`intel_source`) to production, as in v1.1.0 (generate diff → review → one transaction).
2. `CRON_SECRET`: generate, set in Vercel (production) and as a GitHub Actions secret.
3. Deploy cyber v1.2.0; trigger the workflow once manually; confirm six rows with `fetchedAt` set and `/api/intel` all `ok`.
4. Portfolio patch release; confirm `nanoteofficial.me/cyber` → 308 to cyber.nanoteofficial.me.
5. Update both repos' CLAUDE.md and `/project/CLAUDE.md`.

## 11. Out of scope

New feeds, feed-specific history/trends, alerting, per-user filters. GRC multi-customer work is a separate spec (sub-project B).
