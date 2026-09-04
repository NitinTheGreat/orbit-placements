# Round four

Started 2026-09-05.

Status vocabulary: **done** / **partial** / **blocked** / **PENDING-DEPLOY**.

---

## Recovery status carried over

| Step | Result |
| --- | --- |
| 1. billing + deploy | **done** — `billingEnabled: true`; all 8 ingestion functions deployed; round 3's M.Tech gate is now **live** |
| 2. scheduler jobs | **done** — both listed and `ENABLED` |
| 3. Gmail watches | **done** — all 7 students healthy, none lapsed |
| 4. needs_reconnect banner | **not exercisable** — no student is in that state |
| 5. backlog sweep | in progress |
| 6. askOrbit checks | folded into round 4 device verification |

**Callables verified serving:** `syncNow`, `askOrbit`, `connectGmail`,
`dryRunFilter` all return JSON `UNAUTHENTICATED` with the app's own messages,
where they returned `503` before. That is the healthy signature.

**Watches, per student** — all `connected`, all expirations in the future, no
`lastError`, all with a token document:

    Deepanshu 23BIT0264          +142.5h
    Naif Naqeeb 23BIT0279        +142.5h
    Prasiddhi Rajesh 23BIT0221   +164.9h
    Ayush Raj 23BCT0103          +142.5h
    Srijan Srivastava 23BCE0226  +142.5h
    Nitin Kumar Pandey 23BCT0098 +142.5h
    Mayukh Banerjee 23BIT0061    +142.5h

Nothing lapsed, so **no student needs to reconnect** and the
`needs_reconnect` banner still has never been exercised. The watches survived
because they were last renewed 3–4 September and Gmail watches last seven
days; billing was only down about two.

**One caveat, honestly:** the manual `renewGmailWatches` run did **not**
renew. Two scheduler triggers logged `no available instance`, and a direct
OIDC invoke returned `429 Rate exceeded`. Since every watch has ~6 days of
headroom and the scheduled job is enabled for 03:00 IST, this is not urgent —
but it is unverified, and I have not proven the renewal path works
post-recovery.

---

## Part A — list race

**Status:** not started

---

## Part B — relevant date, never "no deadline"

**Status:** not started

---

## Part C — chatbot memory

**Status:** not started

---

## Part D — profile branch-relevant count

**Status:** not started

---

## Part E — colour and typography

**Status:** not started

---

## Part F — release

**Status:** not started

---

## Needs your attention

Nothing yet.
