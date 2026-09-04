# Round three — nine fixes

Started 2026-09-05. One section per part, updated as each finishes.

Status vocabulary: **done** / **partial** / **blocked**.

---

## Part A — unify tab filtering with the sort bands

**Status:** done — but the diagnosis contradicts the premise, so read this
section before the rest.

### 1. Diagnosis — measured, and it is not what the brief assumed

**They were never two separate implementations of the predicates.** Both
`matchesFilter` and `driveBand` already called the *same* `DriveApplication`
getters (`needsAction`, `isInProgress`). So there was no duplicated
action-needed logic to delete.

I ran both over `test_fixtures/live_snapshot.json` (29 real drives) at the
same pinned instant the ordering test uses, and printed every count:

| | band | tab | |
| --- | --- | --- | --- |
| action needed | 6 | **7** | disagreed |
| concluded / Closed | 4 | **0** | disagreed |
| in progress | — | 1 | agreed (Accenture) |
| selected | — | 0 | agreed |
| rejected | — | 0 | agreed |

**Two real disagreements, and neither is the one the brief expected:**

1. **Closed was the badly broken one.** The tab used
   `company.status == CompanyStatus.closed`, while the band used
   `concludedStatuses`, which is `{closed, results_declared}`. Production
   contains **four** `results_declared` drives and **zero** `closed` ones, so
   the tab could only ever render empty. That is the whole bug.
2. **Action needed leaked one drive.** The tab did not apply the branch gate,
   so an off-branch drive that still needed action counted as action-needed
   (7) where the band correctly sank it into `branchMismatch` (6).

**And the tabs the brief called empty mostly were not.** "In progress"
returns Accenture, exactly as the band does. "Selected" and "Rejected" are
genuinely empty because no status document in production carries
`overallStatus: selected` or `rejected` — that is correct behaviour on this
data, not a bug.

**One more thing worth knowing:** at *today's* clock rather than the pinned
one, action-needed drops from 6 to 1 in **both** band and tab, because the
deadlines have since passed. If the tab looked emptier than you expected
when you checked, that is the reason, and it is the right answer.

### 2. Unified — one definition per concept
`matchesFilter` now takes the student's `BranchInfo` and routes the two tabs
that have a band through `driveBand`:

    Action needed -> band == DriveBand.actionNeeded
    Closed        -> band == DriveBand.concluded

The rest keep reading the shared `DriveApplication` getters, which are the
single definition for those concepts already. Nothing new was invented.
`applyFilter` and the list screen thread `branch` through.

Also fixed the copy: the Closed empty state said "No closed drives yet",
which is wrong now that it means concluded — it reads "Nothing has wrapped
up yet."

### 3. Live counts, after the fix

    All              29
    Action needed     6   Superjoin, Ethos, TresVista, Accenture, Goldmansachs, Unthinkable
    In progress       1   Accenture
    Selected          0
    Rejected          0
    Closed            4   ResMed, MUFG, Hitwicket, JPMorganChase

`Closed` went 0 -> 4 and `Action needed` 7 -> 6, both matching their bands
exactly. `test/tab_band_parity_test.dart` asserts set equality between each
tab and its band on the real snapshot, that every `results_declared` drive
reaches Closed, and that no off-branch drive leaks into Action needed.
`test/live_snapshot.dart` is a shared loader so later parts reuse one
fixture rather than re-parsing it.

**Verified:** 311 Dart tests, analyze clean.
**Assumed:** nothing here was seen on a device.

---

## Part B — degree-level gate

**Status:** not started

---

## Part C — tab semantics

**Status:** not started

---

## Part D — application-channel tag

**Status:** not started

---

## Part E — profile screen

**Status:** not started

---

## Part F — ordering and colour

**Status:** not started

---

## Part G — Ask Orbit scroll

**Status:** not started

---

## Needs your attention

Nothing yet.
