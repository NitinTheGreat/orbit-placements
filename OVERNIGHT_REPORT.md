# Overnight build report

Started 2026-09-02. One section per part. Each is updated as that part
finishes, not written at the end.

Status vocabulary: **done** / **partial** / **blocked**.

---

## Part A — independent UI fixes

**Status:** done

### 1. Tile name truncation
The name now takes the full tile width on its own line and wraps freely —
no `maxLines`, no ellipsis. The stage pill moved down into a `Wrap` under
the category line, which is what was squeezing the name before.

**Verified:** `flutter analyze` clean, 144 Dart tests pass. Longest real
company name in production is `Ethos Technologies (Ethos Life)` (31 chars).
**Assumed:** not yet seen rendered on a device.

### 2. List ordering
New pure function `orderDrives` in
`lib/features/companies/presentation/drive_ordering.dart`, four bands:
action needed → open with no action → everything else → concluded.

**Judgment call:** an in-progress drive that still has an outstanding
required step lands in the *action needed* band, not the "everything else"
band. Action needed is a student-facing urgency, so it outranks the drive's
own lifecycle stage. Tested explicitly.

**Judgment call:** concluded drives sort most-recent-deadline **first**
within their band, not oldest-first — a drive that closed yesterday is more
interesting than one from three months ago. Everything else is
soonest-deadline-first. Drives with no deadline sort last inside their band;
ties break on name.

**Verified:** 10 tests in `test/drive_ordering_test.dart`.

### 3. Branch-relevance hint
`lib/models/branch_eligibility.dart`.

**Verified against real data:** your regNo in Firestore is `23BCT0098`, so
the branch code is characters 2–5 (`BCT`) — two year digits, three branch
letters, four serial digits. The parser requires that exact shape and
returns null for anything else.

**Verified against real data:** the matcher was written against the actual
`eligibleBranches` strings in your 18 production companies, and those exact
strings are in the tests — Keyence's `B.Tech Mech,EEE,ECE related branches`,
Kinaxis's three role-scoped entries, WinWire's `CSE/IT/AIML/DS` list,
Urban Company's `All B.Techs (except CS/IT Related)`.

Safety rules, all tested: unknown branch code → no flag; empty
`eligibleBranches` → no flag; text naming no recognisable branch → no flag;
an exclusion clause naming nothing recognisable → no flag; any single entry
that admits you wins over every entry that doesn't. Only a confident
mismatch mutes the tile and adds the `Not open to your branch` tag. The
drive is never hidden.

**NEEDS YOUR ATTENTION — the code-to-name table.** I could not verify the
branch-code meanings empirically. I tried: the shortlist spreadsheets
attached to your placement mail are keyed by **NeoID only**, with no regNo
and no branch column, so there was no ground truth to derive the mapping
from. The table in `vitBranchCodes` is written from general knowledge of
VIT's registration-number scheme and is deliberately easy to edit.

The entry that matters most is **`BCT` → Computer Science and Engineering
(`BranchFamily.computerScience`)** — that is your own code, and it decides
every flag you personally see. If BCT is not a CSE-family branch, change
that one line. Codes not in the table are treated as unknown and never
produce a flag, so a missing entry is harmless; only a *wrong* entry is
dangerous.

### 4. Logo and launch animation
**Judgment call:** you said `logo_final.png`, and no file by that name
existed. The repo root had `logo.png` and `new logo final.png`. I took
`new logo final.png` (the orbit ring with the comet on the dark navy tile)
and copied it to `assets/brand/logo_final.png`. The old `assets/icon/`
folder and both `orbit_icon*.png` files are deleted; nothing references
them any more.

`assets/brand/logo_final_foreground.png` is a transparent-background
version I generated from it by masking on distance from the tile's
background colour, then re-cropping and padding to the adaptive-icon safe
zone. Used for the adaptive icon foreground, the monochrome layer, the
native splash bitmap, and the in-app entrance.

Launcher icons regenerated with flutter_launcher_icons 0.14.4 — I checked
the key names against the installed package's `config.dart` rather than
trusting the README. Adaptive background is now the flat brand navy
`#11152A` instead of an image.

Native cold-start splash: `launch_background.xml` (and the v21 variant) now
paint `#11152A` with the mark centred, at five densities. Android 12+ gets
`values-v31` and `values-night-v31` with `windowSplashScreenBackground` and
`windowSplashScreenAnimatedIcon`, because the system splash on API 31+
ignores `windowBackground`.

In-Flutter entrance: `lib/core/widgets/launch_curtain.dart`, mounted in the
`MaterialApp.router` builder. The navy ground carries over from the native
splash so there is no colour jump; the mark settles in with a spring scale
and a slight counter-rotation, then pushes past the viewer — scaling up and
fading while the whole ground lifts away to reveal the app. It removes
itself from the tree when finished, and is skipped entirely when the OS
asks for reduced motion.

**Verified:** analyze clean, 144 tests pass, Android resources compile.
**Assumed:** the visual timing has not been watched on a device.

---

## Part B — bottom navigation and profile

**Status:** not started

---

## Part C — Android home-screen widget

**Status:** not started

---

## Part D — "not shortlisted" detection

**Status:** not started

---

## Part E — notifications

**Status:** not started

---

## Part F — App Check, monitoring mode

**Status:** not started

---

## Part G — Android release

**Status:** not started

---

## Part H — iOS, best effort

**Status:** not started

---

## Needs your attention

Nothing yet.
