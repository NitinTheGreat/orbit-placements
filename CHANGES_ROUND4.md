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

**Status: done and deployed, verified on device**

### 5. Checked first: rounds carry no scheduled date at all
Across all 76 companies there are 64 round objects, and their keys are exactly:

    name, announcedAt, order, id, type

`scheduledDate` appears **0 times**; `announcedAt` appears 64 times and is the
moment Orbit *detected* the round, not when it happens. So your suspicion was
right and the field had to be added.

Added `scheduled_date` to the extraction schema with prompt guidance that is
explicit about the trap: give the date the round happens when the mail states
it, and **never** the date the mail was sent. Stored as `scheduledDate` on the
round object, and a later mail can fill it in on a round that was first seen
without one.

**Existing drives will not have it until re-ingested.** Every round in
production today was created before this field existed, so the upcoming-round
branch cannot fire for them yet. New and updated drives will populate it.

Extraction and the round merge are **deployed** — billing came back, so this
did not have to wait.

### 4. One derived date, first match wins
`drive_date.dart`, priority exactly as specified: next upcoming dated round
(labelled with the round name) → registration deadline → most recent past
dated round (labelled as past) → `Date not announced`. A closed registration
is used as a last resort before giving up, which is more useful than nothing.

**A regression I caught on device, in my own logic.** My first version gated
the registration branch on `registrationStillOpen`, which requires
`status == registration_open`. On device that produced **"Registration closed
6 Sep 2026" for Cognizant — a date in the future**, because its status is
`in_progress` while its deadline is still ahead. For *display* what matters is
whether the deadline has passed, not the lifecycle field, so the branch now
tests the deadline directly. Two tests pin it: a future deadline reads as
closing whatever the status, and a deadline tomorrow is never described as
closed.

### 6. Device verification
`B-dates-fixed.png`, `B-dates-scrolled.png`:

    FlamAI      Closes in 2 days
    WinWire     Registration closed 1 Sep 2026
    Kinaxis     Registration closed 2 Sep 2026
    RFPIO       Closes today

**No card reads "No deadline" any more.** 11 tests, 428 Dart, 291 Python.

### Something this surfaced, worth its own pass
FlamAI now exists as **three** company documents, and in one of them the
extractor split a single eligibility sentence into fragments:

    'M.Tech( 2 yr & 5 Yr) CSE'   'IT'   'ECE'   'EEE related branches'
    ...and in another: 'Computer Science and Mathematics'   (on its own)

That last fragment is orphaned from its "M.Tech/ Dual degree" qualifier, so
the level gate correctly reads it as *level unstated* and returns **eligible**.
The gate is behaving correctly on the data it is given; the fault is upstream,
in extraction splitting one qualified sentence into unqualified pieces. It is
why one FlamAI card now shows without the branch tag while the other two are
still suppressed.

---

## Part C — chatbot memory

**Status: done and deployed** (billing came back, so it did not have to stay
PENDING-DEPLOY as the brief anticipated)

### 7. Conversation history
`askOrbit` now reads the student's recent exchanges, passes them as prior
turns, and appends the new one. A follow-up like "what about the second one"
has the earlier answer to resolve against.

Three independent caps, each tested:

- **6 turns** (`MAX_HISTORY_TURNS`) — oldest dropped first
- **4000 characters total** (`MAX_HISTORY_CHARS`) — turns dropped from the
  front until it fits, so six long turns cannot blow up the prompt
- **1200 characters per stored answer** — a single huge answer is *truncated*
  rather than dropping the turn, so the thread stays coherent

Malformed history is ignored rather than trusted: non-lists, non-dicts,
missing or blank or non-string fields all yield an empty history.

### 8. Scoping and rate limit unchanged
This is the part that mattered most, so it is worth being explicit about what
did **not** change:

- The rate limit still counts **before** the model call and is untouched at 20
  per student per UTC day.
- `statuses_for_student` still filters on the caller's uid; `build_context` is
  unchanged.
- History is stored under `assistantUsage/{studentId}`, the same
  per-student document, which is already behind the catch-all deny in
  `firestore.rules` — a student can neither read nor write it. The existing
  rules tests already cover that document.

**History can never widen data reach.** It carries only the student's own
prior questions and Orbit's own prior answers, and the prompt says explicitly
that the earlier turns are for resolving references and that CONTEXT is the
only source of facts. A test asserts that instruction survives alongside a
history entry that mentions another student's name.

**Verified:** 8 new tests, 36 in the assistant suite, 291 Python overall.
Deployed to `orbit-507316`.

**Not verified:** no multi-turn conversation has been held against the live
model. The plumbing and the caps are tested; the model's actual follow-up
resolution is not.

---

## Part D — profile branch-relevant count

**Status: done**

### 10. The stat
`ProfileStats.branchRelevant` counts drives whose `branchRelevance` is not
`notOpen` for this student — reusing the existing gate rather than inventing
a second rule, so it agrees with the sort band and the tabs by construction.

Shown on the profile as **"open to your branch and level"**, beside the
existing **"drives tracked"**. The two are deliberately different things and
the labels say so:

- *drives tracked* — how many the student is actually following
- *open to your branch and level* — how many they are eligible for at all

They move independently: a drive can be relevant but untracked, or tracked but
off-branch if the student opted in deliberately. A test pins exactly that.

Unknown eligibility counts as relevant, consistent with the safety rule that
Orbit never suppresses on doubt.

### 11. The behaviour behind it is now live, contrary to the brief's assumption
The brief expected server-side suppression to still be PENDING-DEPLOY. It is
**not** — billing was restored at the start of this session and round 3's
M.Tech and branch gate deployed with it. New mismatched drives no longer
auto-track.

**But the backlog was auto-tracked while billing was down**, so drives ingested
in that window are still opted in regardless of branch. The display is correct
either way; the historic tracking state is not, and nothing in this round
retroactively corrects it.

**Verified:** 5 new tests, 433 Dart tests.

---

## Part E — colour and typography

**Status: done, measured and verified on device**

### 12. What was actually wrong
I looked at the shipped screens first. Three things, and the hue was the
least of them:

1. **Every card carried a hard outline, and action-needed cards got a
   saturated red one.** A screen of urgent drives became a wall of red-boxed
   rectangles. This was the single biggest contributor to "harsh".
2. **Amber was doing six jobs at once** — brand accent, active chip, stage
   pill wash *and* text, floating button, stat numbers, active nav. Because
   every card carries a stage pill, the most saturated colour on screen
   appeared on every single row.
3. **Three saturated hues co-occurred with no tonal middle ground.** Amber,
   red and green all at full strength against a warm near-black, and the only
   other tone available was a border. Hierarchy was carried entirely by
   outlines, which is why the outlines had to be strong.

So the fix is mostly about **saturation, repetition and elevation**, not
about picking a different hue.

### 13. What changed
- **Seed:** `#B4823C`, a muted ochre. Deliberately not the AI-default
  purple/blue, and deliberately still recognisably Orbit — it keeps the amber
  identity while the tonal ramp built from it is far lower-chroma than the
  hand-picked amber it replaces.
- **Tonal surfaces replace outlines.** Cards are a raised surface with a very
  soft shadow and **no border at all**. The red urgent border is gone
  entirely — urgency now reads from the rail and the deadline text, which
  were always the real signal.
- **Chips are tonal pills**, no outlines, inactive ones sitting on
  `surfaceSunken` rather than being outlined boxes.
- Radii softened (card 18 → 20, sheet 20 → 24, control 12 → 14).

**Semantics are untouched, as instructed.** Urgency still reads red for
today/imminent, amber for this week, green for distant, muted for passed —
the same single `urgencyColor` function. Outcomes still read success and
urgent. Only the specific colour values moved; nothing changed meaning.

Gradients: none added to cards. The splash keeps its existing treatment.

### 14. Typography
**Space Grotesk → Plus Jakarta Sans** for display and headings, **IBM Plex
Sans → Inter** for body and UI.

Space Grotesk is a tight, geometric, slightly technical face — it was
reinforcing the hard-edged feel. Plus Jakarta Sans has rounder terminals and
a softer bowl, which suits tonal Material surfaces. Inter is the most legible
UI face at 12–14px and has genuine `tnum`. Display tracking was loosened
(-0.8 → -0.4) because Jakarta is wider and did not need the same negative
tracking.

**Tabular figures** kept on `labelMedium`, `labelSmall`, and added to
`bodyMedium` and `headlineMedium`, so deadlines, CTC figures and the profile
stat numbers all align.

### 15. Contrast, measured not assumed
Every text-on-surface pair in both themes, 40 measurements, WCAG AA
thresholds (4.5 for body text, 3.0 for large/graphical):

    light: 20/20 pass    dark: 20/20 pass    TOTAL FAILURES: 0

**One real failure caught and fixed before shipping.** White on the light
accent measured **4.22**, under the 4.5 needed for the filled button. I
computed candidates rather than eyeballing and moved the light accent from
`#A5711F` to `#96661B`, which measures **4.98**, with `accentEdge` following
to `#7E5516`.

### 16. Device verification
`E-list.png`, `E-profile.png`, `E-widget2.png`. The red-outline wall is gone;
cards read as raised surfaces; chips are quiet; the urgency rail and deadline
text still carry the signal.

**The widget: updated, not left behind.** It had hardcoded `#11152A` navy and
three hardcoded text colours. Those are now named resources matching the new
dark palette (`#1C1D21` surface, `#EFC98F` headline, `#EAEAEE` title,
`#AFB0B8` subtitle), so on the home screen it reads as an Orbit card rather
than a differently-coloured island.

**The splash and launcher icon keep the brand navy deliberately.** They are
the launch identity and share the icon's own artwork; the pixel-matched
splash-to-curtain handoff verified in the device session depends on that navy
staying put on both sides.

---

## Part F — release

**Status: shipped, but as v1.2.0 rather than v1.1.0**

### 17. The version number changed on me, and you should know why
The brief said "version-bumped from v1.0.0", so I built and tagged v1.1.0 —
and `gh release create` refused it: **a v1.1.0 release already exists**,
published 2 September, carrying `app-release.apk` (60,222,280 bytes, already
downloaded twice) and `orbit-unsigned.ipa`, with notes about the web sign-in
fix and iOS sideloading.

Overwriting it would have destroyed a release people had already pulled, so I
did not. The round 2–4 build ships as **v1.2.0** instead, and v1.1.0 is
untouched — verified after the fact that both its assets and their download
counts are still there.

`pubspec.yaml` is `1.2.0+3` to match.

### 18. The release
- `flutter analyze`: clean
- 433 Dart tests, 309 Python tests: pass
- `app-release.apk`, 57.5 MB, signed with the same key as v1.1.0 so it
  installs over the top and keeps the Gmail connection
- `adb install -r`: Success. Device reports `versionCode=3 versionName=1.2.0`
- Launched and screenshotted on device (`F-v120-running.png`): list renders
  with the new palette, real drives, real dates
- <https://github.com/NitinTheGreat/orbit-placements/releases/tag/v1.2.0>,
  marked Latest, one asset `orbit-1.2.0.apk` in state `uploaded`

Release notes cover rounds 2–4: eligibility and degree-level gating, the
derived dates, the paging fix, Ask Orbit and its memory, notifications and
the widget, and the visual overhaul.

---

## Found while verifying, after Part F

### 19. Ask Orbit was answering in half a sentence — fixed, not yet deployed
Going back to close the two Ask Orbit checks that had never been run against
the live model, I asked the 24-hour preset on the phone and got back:

> In the next 24 hours, the

and nothing more. I checked the layout first and cleared it: the panel sizes
to its content, and a swipe over the answer produced **zero changed pixels**,
so nothing was being clipped. The answer really was that short.

The cause is `max_output_tokens=400` on `gemini-3.7-flash`, which **thinks by
default, and thinking tokens are drawn from that same budget.** Reproduced
against the live model with the exact shipped config:

    OLD  max_output_tokens=400, default thinking
         finish_reason: MAX_TOKENS
         thoughts_tokens: 381   candidates_tokens: 15
         text: 'Today, 2026-09-05, you'

    NEW  max_output_tokens=1200, thinking_level=low
         finish_reason: STOP
         thoughts_tokens: 244   candidates_tokens: 57
         text: 'RFPIO India Pvt. Ltd (DBA Responsive) and TresVista Financial
                Services both have deadlines due today on 2026-09-05.
                Additionally, Cognizant has a deadline coming up on 2026-09-06.'

381 of 400 tokens went to thinking. Fifteen were left for the answer.

**Fixed:** thinking held to `low`, budget raised to 1200. If the cap is ever
hit anyway the answer is cut back to whole sentences instead of being handed
over mid-clause, and a fragment with no complete sentence raises rather than
being shown. 12 new tests, 309 Python tests pass.

**This has NOT reached your phone** — see *Needs your attention*.

### 20. The three outstanding Ask Orbit checks, now run
Run against the live `gemini-3.7-flash` with the shipped prompt and the new
config, on a context built from your actual visible drives:

**Memory resolves a follow-up.** Turn one asked what was due in 24 hours.
Turn two asked *"Which of those two pays more, and what do I still have to do
for it?"* — no company named, a pronoun pointing back. It answered
TresVista at 11.58 LPA over RFPIO at 10.00 LPA, with TresVista's status and
deadline. **Passes.**

**It refuses to invent.** Asked for the cutoff CGPA and coding-round date for
a "Google drive" that does not exist in the context: *"I do not have any
information about a Google drive, as Orbit has not seen it yet. Consequently,
I do not know the cutoff CGPA or the date for its coding round."* No invented
company, no invented date. **Passes.**

**Long answers come back whole.** A question asking for every drive one by
one returned 551 characters, `finish_reason: STOP`, all four drives with
deadline, pay and state. **Passes.**

The scrolling half of that last check is still only proven in a widget test
(`a long answer scrolls while the chips and input stay put`, which asserts
`maxScrollExtent > 0` on a 320×480 screen with a genuinely overflowing
answer). I could not force an overflowing answer on the phone, because the
phone is still running the truncating build.

---

## Needs your attention

### The assistant fix is written, tested and pushed, but not deployed
`firebase deploy --only functions:askOrbit` fails with **"Failed to
authenticate, have you run firebase login?"**. The CLI's credential store at
`C:\Users\-THE-GREAT-\.config\configstore\firebase-tools.json` now holds only
`motd` and `apiEnablementCache` — the tokens are gone. They were present
earlier in this session, when the recovery deploys ran. There is no service
account key on this machine and no `GOOGLE_APPLICATION_CREDENTIALS` set, and
`firebase login` needs a browser I cannot drive.

**What that means right now:** Ask Orbit on your phone still truncates every
answer to a fragment. Everything else in v1.2.0 is client-side and works.

**To fix it:** run `firebase login`, then

    firebase deploy --only functions:askOrbit --project orbit-507316

The commit is `c3faa9e` and is already on `main`.

### Watch renewal is still unproven
Carried over from the recovery session and unchanged: `renewGmailWatches`
never actually executed — two scheduler triggers logged "no available
instance" and a direct OIDC invoke returned `429 Rate exceeded`. No
expiration moved. All seven watches still have roughly six days of headroom,
so this is not urgent, but the renewal path has not been shown to work since
billing came back.
