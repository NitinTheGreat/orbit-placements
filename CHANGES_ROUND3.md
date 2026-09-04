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

**Status:** done in code and tests. Client half is live-ready; **the server
half cannot be deployed because billing is disabled on the project** — see
"Needs your attention".

### 4. Level detected separately, and before branch matching
`DegreeLevel { undergraduate, postgraduate }` in Dart,
`UNDERGRADUATE` / `POSTGRADUATE_LEVEL` in Python.

- **Student level** from the regNo prefix: `B*` undergraduate, `M*`
  postgraduate, anything else null.
- **Drive level** from eligibility text, per entry.

**Judgment call on keyword safety.** The two directions of error are not
equal: a false *postgraduate* reading on a B.Tech drive would suppress a
drive a student is genuinely eligible for, while a false *undergraduate*
reading merely returns today's behaviour. So the PG list is deliberately
narrow and unambiguous (`m tech`, `mtech`, `m e`, `mca`, `msc`, `mba`, `pg`,
`postgraduate`, `masters`) and I left out a bare `me`, which would collide
with the English word.

### 5. Level beats branch, and one restructure it forced
A level mismatch is a confident mismatch regardless of branch overlap, so
`M.Tech CSE` no longer matches a B.Tech CSE student. Both levels named
(`B.Tech/M.Tech CSE`) admits both. Level unstated stays unknown.

**A flaw my own fixture caught.** My first version returned `not_open` from
any entry whose level excluded the student, and the existing "any entry that
admits you wins" union then let that dominate. On Keyence — which lists
`B.Tech Mech,EEE,ECE` *and* `M.Tech Mech,EEE,ECE` — an M.Tech student was
flagged `not_open` on the strength of the **B.Tech** line, even though the
M.Tech line admits their level. That is exactly the false negative the whole
design is meant to avoid.

`branchRelevance` now tracks level admission separately from branch
exclusion: an entry that excludes the student's level contributes nothing to
the branch decision, and a confident mismatch is only returned when **no**
entry admits their level, or when an entry that does admit it also excludes
their branch.

**Second judgment call:** for a student whose code is `M*`, the confirmed
rules give a level but no discipline ("M.Tech, any specialisation"). So once
the level check passes, the branch dimension is treated as **unknown** rather
than mismatched. An M.Tech student is never flagged on branch, only on level.

### 6. Applied everywhere — and it moved a real drive
`branchRelevance` derives the level from `BranchInfo.code` when none is
passed, so the sort band, the tabs, and `sinksForBranch` all picked it up
with no call-site changes. The Python side already routed through
`branch_relevance_for_reg_no`, which now passes level, so auto-opt-in
suppression and the notification fan-out are covered by the same change.

**The live M.Tech drives currently in production**, all of which name a
CSE/IT overlap and so were previously matching a B.Tech CSE student:

| Drive | Eligibility text | Was | Now |
| --- | --- | --- | --- |
| **Face Prep** | `M. Tech ( CSE / IT ) related branches only` | shown, open now | suppressed |
| **Voxela** | `M.Tech CSE & IT related branches` | shown | suppressed |
| **FlamAI** | `M.Tech( 2 yr & 5 Yr) CSE,IT,ECE,EEE related branches` | shown | suppressed |
| **Premas Life Science** | `M.Tech Biotechnology` | shown | suppressed |
| Haleon | `MBA` | shown | suppressed |

On the live snapshot, **Face Prep moved out of `openNoAction` into
`branchMismatch`**, taking that band from 3 to 4. It is the one that was
most visibly wrong, since it was sitting in "Open now".

Also checked the drives that must **not** move: Syrma SGS lists unlabelled
B.Tech branch names alongside an `MBA` entry, and a B.Tech CSE student stays
`eligible` there because the CSE entry names no level. Cognizant's
`['B.E','B.Tech']` names a level but no branch, so it stays `unknown`.

### 7. Parity table extended
`test_fixtures/branch_cases.json` gained a `levels` block (11 codes) and 10
new relevance scenarios drawn from the real production text above. Both
suites parametrise over them: **120 Dart, 128 Python**, agreeing on every
row.

Two pre-existing expectations changed as a deliberate consequence, not a
regression: Keyence for an MCA student is now `unknown` rather than
`eligible` (an `M*` code carries no discipline, so claiming eligibility was
over-reaching), and Cognizant/Kinaxis for an MCA student are now `not_open`
(both are B.Tech-only, so an M.Tech student genuinely is not eligible).

**Verified:** 348 Dart tests, 288 Python tests, analyze clean.
**Assumed:** not seen on a device.

---

## Part C — tab semantics

**Status:** done, except the higher-package feature which is **deliberately
inactive** — see item 11.

### 8. Open now
`registrationStillOpen` = status is `registration_open` **and** (deadline in
the future **or** no deadline at all). Added as a shared predicate in
`application_status.dart`, not inline in the lock.

WinWire (Part of NTT DATA) is the live example: `registration_open` with a
deadline of 01 Sep, i.e. already past. It no longer appears. The live-snapshot
test asserts this against whatever stale-open drives the fixture actually
contains rather than hard-coding a name.

### 9. Shortlisted
Was `isInProgress || selected`, and `isInProgress` requires
`overallStatus == active` — so a student who cleared a round and was later
rejected vanished from the tab entirely. Now `wasShortlisted`: any round
history entry with `cleared` or `invited`, or an outright offer, **regardless
of the drive's lifecycle state**. Concluded drives therefore stay visible.

**Judgment call, and it reverses one of my own earlier tests.** An offer is
now checked *before* the opted-out guard, so a student who turned tracking
off still sees a drive they were selected for. Hiding somebody's offer
because they muted notifications would be the worse error. A cleared round
with tracking off is still hidden, as before.

De-emphasis: `DriveCard` takes `deEmphasiseConcluded`, set only by the
Shortlisted list, and reuses the **existing** muted treatment already built
for off-branch drives — the same `0.58` opacity and the same forced
`DeadlineUrgency.passed` rail. No second visual language, no strikethrough.

Colour-coding for active entries needed no work: the card already draws its
rail from `DriveApplication.urgency`, which is the one urgency scale. I
checked rather than adding a parallel one.

### 10. Selected — already correct, verified not changed
`DriveFilter.selected` already tested `overallStatus == OverallStatus.selected`
and never consulted round history. I added a test pinning that a merely
*cleared* round does **not** put a drive on the Selected tab, so the
distinction cannot regress.

### 11. Higher-package eligibility — built, and off

**Checked first, as asked:** there are no `ctcMinLpa` / `ctcMaxLpa` fields
anywhere in the schema or the ingestion code. `ctc` is a free-text string
only. So parsing had to be written.

`ctc_parsing.dart` handles every shape actually present in production, and
each one is a test case:

| Live string | Parsed |
| --- | --- |
| `20 LPA` | 20 |
| `11.58 LPA` | 11.58 |
| `10.00 LPA (If converted)` | 10 |
| `1365000 (If Converted)` | 13.65 |
| `800000` | 8 |
| `7.5 LPA - 16 Lakhs` | 7.5 – 16 |
| `INR 12 LPA - INR 18 LPA` | 12 – 18 |
| `Refer Attachment` | nothing |
| `To be announced later` | nothing |

A bare number of 10,000 or more is read as rupees per annum and divided down;
below that it is read as already being in lakhs. Crore is handled.

**`offerMultiplierThresholds` is written to `config/ingestion` with both
`dream` and `superDream` set to `null`**, exactly as instructed, and read at
runtime. `OfferThresholds.isConfigured` is false, so
`stillEligibleAbove` returns false for everything and **nothing is surfaced
on the Selected tab**. I did not guess a multiplier. Tests pin that the
feature stays silent while unset and works once set.

To switch it on, set those two numbers in `config/ingestion` and tell me.

**Verified:** 15 CTC tests, 13 tab-semantics tests including two against the
live snapshot, 376 Dart tests, analyze clean.
**Assumed:** the de-emphasised rendering has not been seen on a device.

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

### 1. Billing is disabled on `orbit-507316` — nothing server-side can ship

Deploying Part B's server half failed:

    Error: Request to secretmanager.googleapis.com/.../GMAIL_OAUTH_CLIENT_SECRET
    had HTTP Error: 403, This API method requires billing to be enabled.

Confirmed directly rather than inferred:

    GET cloudbilling/v1/projects/orbit-507316/billingInfo
    { "billingAccountName": "billingAccounts/018BC3-AA2EB7-BCDCD5",
      "billingEnabled": false }

The billing account is still linked, it is just switched off. I cannot turn
it back on — the service account gets `PERMISSION_DENIED` reading the billing
account, and enabling billing is an owner action tied to a payment method
regardless.

**What this means right now:**

- **No Cloud Function can be deployed.** Part B's Python gate (auto-opt-in
  suppression and the notification fan-out) is committed and tested but is
  **not live**. It will take effect on the first successful deploy.
- Gen-2 functions run on Cloud Run, which needs billing, so **ingestion,
  `syncNow`, the scheduled sweeps and notifications are very likely down
  too**, not merely un-updatable. I did not stress-test this, but it is the
  expected consequence.
- Everything client-side in this round — the tab unification, the level gate
  in the app's own filtering and ordering — works without a deploy and ships
  with the next app or PWA build.

**Please re-enable billing at**
https://console.cloud.google.com/billing/enable?project=orbit-507316
then tell me, and I will deploy the pending functions and verify ingestion
recovers.
