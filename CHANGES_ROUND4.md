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

**Status: done, verified on device**

### 1. Diagnosis — both symptoms, one bug

Confirmed by reading the render path rather than guessing. Since `a4213bb`
the list rendered a filtered result **as if final while paging was still in
flight**:

    if (narrowedView && companies.isEmpty && hasMore) -> spinner
    ...otherwise render `companies`

The spinner only covered the case where the filtered result was *empty*. If
even one match had arrived, the partial set was rendered as the answer, and
each subsequent page rebuilt the list longer. That is symptom (a) exactly:
Action needed showing 2, then 5.

**Symptom (b) is the same bug, not a separate one.** All the chip filters
share one `CompanyPageController` per screen. Visiting a narrowed tab paged
the controller to completion; returning to All then rendered all 76 documents,
where a fresh All had only the first 20. So whether a red-bordered
action-needed drive appeared in All depended on whether you had previously
opened a narrowed tab. Intermittent, and entirely explained by the same
partial-render.

Nothing else contributes: the urgency colour is a pure function of the drive
and status, and the status stream is stable.

### 2. Fix
The list now pages to completion **before rendering anything**, for every
view including All, and shows a loading state until `hasMore` is false.
Results — or the empty state — are only shown once the set is complete. The
trailing "loading more" row is gone, because there is never a partial set to
append to.

**Tradeoff, stated plainly:** All no longer streams in twenty at a time; it
waits for all 76. At this size that is a sub-second wait and it buys
correctness. If the collection grows into the thousands this needs revisiting
— a server-side filtered query rather than client-side filtering over
everything.

### 3. Device verification
Action needed captured at 0s, 2s and 5s after opening, then compared
pixel-by-pixel with the status bar cropped out:

    0s vs 2s: identical=True  changed_pixels=0
    0s vs 5s: identical=True  changed_pixels=0
    2s vs 5s: identical=True  changed_pixels=0

Same for All: identical at 0s, 2s and 5s. The list no longer grows underneath
you. `A-action-*.png`, `A-all-*.png`.

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
