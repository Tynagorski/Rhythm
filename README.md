# Rhythm

An iOS app for people whose calendars run their lives. Rhythm keeps the day
organised, makes you keep your calendar honest, and scores whether your week
actually touched more than work.

It is built around one idea: **effort is not the constraint — coverage is.** A
top performer will always feed the business. What quietly starves is everything
else. Rhythm measures that directly and nags about the one input everything else
depends on: an accurate calendar.

## What it does

**Today** — one keystone, up to three momentum tasks, everything else is
maintenance. The tiers are capped deliberately so the plan stays a plan.

**Calendar integrity** — Rhythm reads (never writes) your calendar and looks for
the things that rot a week: unanswered invites, double bookings, work past your
hard stop, days with no ninety-minute stretch left to think, weekdays with
nothing on them at all. If you have not reviewed the week ahead in *n* days
(three by default), it starts nudging, and the nudge escalates for three days
before it stops.

**Rituals** — habits with a domain (Business, Body, Mind, Relationships,
Recovery), a cadence, and an anchor time. A deliberate skip shrinks the
denominator instead of counting as a miss; the app rewards honesty over a padded
streak.

**Balance score** — a 0–100 daily number built from four parts, always shown
broken down:

| Component | Weight | What it measures |
|---|---|---|
| Execution | 30% | Weighted completion of what you committed to |
| Rituals | 25% | Kept versus due today |
| Coverage | 25% | How many of the five domains the day actually touched |
| Protection | 20% | Boundaries held, meeting load, room left to think |

A component with no data for the day (nothing planned, no rituals due) is
dropped and the remaining weights renormalise — an untracked day is unknown, not
bad. Closing the day out with the shutdown ritual adds a small bonus.

**Drift** — days since each domain last received anything. Three days is where
"busy week" becomes a pattern, and that is when Rhythm says so.

**Shutdown** — three steps at your hard stop: see the day honestly, log energy
and one line, set tomorrow's keystone while you still have today's context.

## Widgets

| Widget | Families | What it shows |
|---|---|---|
| Today | small, medium, large | Keystone, balance ring, tappable rituals |
| Rituals | medium, large | Full check-off grid — one tap, no context switch |
| Balance | small, medium | Score plus which domains the day touched |
| Calendar integrity | small | Days since your last review; turns red when overdue |
| At a glance | Lock Screen / StandBy | Circular, rectangular and inline |

The Today, Rituals and Balance widgets are interactive: a tap runs an App Intent
inside the extension that writes to the shared store, so a tap on the home
screen and a tap in the app land in exactly the same place.

## Notifications

Local notifications carry the day-to-day: morning brief, midday checkpoint,
per-ritual anchors, shutdown at your hard stop, a Sunday reset, drift alerts,
and the escalating calendar nudge. They work offline and need no account. Every
one can be turned off individually.

Remote push is wired up client-side and reserved for what only a server can do —
see `Docs/PUSH_NOTIFICATIONS.md`. With no endpoint configured (the default) the
device token never leaves the device.

Siri and Shortcuts: "set my keystone", "check my balance", "mark my calendar
reviewed", "keep a ritual".

## Architecture

```
Rhythm/
  App/         Entry point, root navigation, Info.plist, entitlements
  Core/
    Models/    SwiftData models + the calendar value types
    Store/     Shared ModelContainer, queries, mutators
    Engine/    BalanceEngine, DayAssembler, StreakEngine  (pure, unit tested)
    Services/  EventKit, notifications, push, coordinator  (app target only)
    DesignSystem/
  Features/    One folder per screen
  Intents/     App Intents shared by Siri and the widget buttons
RhythmWidgets/ WidgetKit extension
RhythmTests/   Unit tests
```

Two rules hold the structure together:

1. **Scoring is pure.** `BalanceEngine` takes a `BalanceInput` of plain values
   and returns a `BalanceResult`. It never touches SwiftData, EventKit or the
   main actor, which is why the formula can be tested exhaustively.
2. **The extension shares the store, not the app.** App, widget and App Intents
   all open the same `ModelContainer` in the `group.com.rhythm.app` App Group.
   Anything that touches `UIApplication` or EventKit stays in the app target;
   `Scripts/check_target_membership.py` enforces that.

## Building

Requires Xcode 16 or later, iOS 17 deployment target.

```sh
open Rhythm.xcodeproj
```

Before it will run on a device, set your team and replace the placeholder
identifiers — see `Docs/BUILD.md`.

`Rhythm.xcodeproj/project.pbxproj` is generated, not hand-edited. After adding
or moving a source file:

```sh
python3 Scripts/generate_xcodeproj.py
```

### Checks that run without a Mac

```sh
python3 Scripts/check_swift_syntax.py       # delimiters, string literals
python3 Scripts/check_xcodeproj.py          # project integrity, target membership
python3 Scripts/check_target_membership.py  # extension-safety of shared sources
```

These are a backstop, not a substitute for `xcodebuild`. Run the test suite on a
Mac before shipping:

```sh
xcodebuild test -scheme Rhythm -destination 'platform=iOS Simulator,name=iPhone 16'
```

## Privacy

No account, no analytics, no network calls unless you configure a push endpoint.
Plans, rituals and calendar analysis stay in the App Group container on device.
Calendar access is read-only. Both binaries ship a privacy manifest.

## Documentation

- `Docs/BUILD.md` — signing, capabilities, the identifiers to change
- `Docs/APP_STORE.md` — submission checklist, listing copy, review notes
- `Docs/PUSH_NOTIFICATIONS.md` — APNs payload contract and server requirements
- `Docs/PRIVACY_POLICY.md` — the policy to publish before submitting
