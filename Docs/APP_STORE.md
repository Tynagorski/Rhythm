# App Store submission

## Before you can submit

- [ ] Replace every placeholder identifier (`Docs/BUILD.md`)
- [ ] Publish the privacy policy and support pages, and point `SettingsView` at
      the real URLs — App Review rejects placeholder links
- [ ] Enable App Groups, Push Notifications and Time Sensitive Notifications on
      the App ID
- [ ] Archive once and confirm `aps-environment` flipped to `production`
- [ ] Run the test suite on a Mac (`xcodebuild test -scheme Rhythm`)
- [ ] Screenshots at 6.9" and 6.5"; 13" iPad only if you ship iPad
- [ ] Fill in App Privacy in App Store Connect (see below)

## App Privacy answers

Rhythm has no account, no analytics SDK and makes no network request unless a
push endpoint is configured. In App Store Connect:

- **Data collection**: *No, we do not collect data from this app.*

If you later configure a push endpoint, that changes: the device token is an
identifier tied to the device and must be declared as **Identifiers → Device ID**,
collected for **App Functionality**, **not** linked to identity and **not** used
for tracking. Update `PrivacyInfo.xcprivacy` at the same time.

Both binaries already ship a privacy manifest declaring the one required-reason
API the app uses (`NSPrivacyAccessedAPICategoryUserDefaults`, reason `CA92.1` —
reading and writing within the app's own App Group).

## Review notes

Paste something like this into App Review Information → Notes, because two
things in the app are easy for a reviewer to mistake for a bug:

> Rhythm is a personal planning app. Two notes on permissions:
>
> 1. **Calendar (EventKit)** — Rhythm requests full access because the feature
>    reads existing events to detect scheduling conflicts, unanswered invites and
>    over-booked days. The app never creates, edits or deletes events; there is
>    no write path in the codebase. Calendar data is analysed on device and is
>    never transmitted.
>
> 2. **Notifications** — all day-to-day notifications are scheduled locally. The
>    push entitlement is present for a future server-driven coaching feature; no
>    backend is configured in this build, so no device token is transmitted.
>
> To see the calendar features, add a few overlapping events to the device
> calendar, then open Today → "Review week".
>
> All features are free. There is no account, subscription or paywall.

## Listing copy

**App name (30):**
`Rhythm: Focus & Life Balance`

**Subtitle (30):**
`Run your day, keep your life`

**Promotional text (170):**
`Your calendar decides your day. Rhythm decides your week — one keystone at a
time, with a nudge every few days to keep the calendar honest.`

**Keywords (100):**
`productivity,habits,calendar,focus,planner,work life balance,routine,executive,daily planner,widget`

**Description:**

```
You are not short on effort. You are short on a system that holds the parts of
your life your calendar does not.

Rhythm is a daily operating system for people whose calendars run their lives.
It keeps the day organised, makes you keep your calendar honest, and scores
whether your week actually touched more than work.

ONE KEYSTONE, THREE MOMENTUM TASKS
Every day gets one keystone — the thing that makes the day count — plus up to
three momentum tasks. The tiers are capped on purpose. A plan you cannot finish
is not a plan.

A CALENDAR THAT STAYS HONEST
Rhythm reads your calendar and finds what quietly rots a week: unanswered
invites, double bookings, work past your hard stop, days with no ninety-minute
stretch left to think, weekdays with nothing on them at all. Every few days it
makes you review the week ahead — and the nudge escalates until you do.

Rhythm never creates, edits or deletes an event. It reads, and it tells you.

RITUALS ACROSS FIVE DOMAINS
Business. Body. Mind. Relationships. Recovery. Anchor a ritual to a time and it
becomes a decision you already made. Skip one deliberately and Rhythm counts
that as honesty, not failure.

A BALANCE SCORE THAT CANNOT BE GAMED
One number out of 100, always shown broken into its four parts: what you
executed, what rituals you kept, how many parts of your life the day touched,
and whether your boundaries held. A day spent entirely on business cannot score
well, however much got done. That is the point.

DRIFT DETECTION
Rhythm tracks how long each domain has gone without anything at all. Three days
is where a busy week becomes a pattern — and that is when it tells you.

THE SHUTDOWN
At your hard stop: see the day honestly, log what it cost you, set tomorrow's
keystone while you still have today's context. Then put it down.

WIDGETS AND THE LOCK SCREEN
Your keystone, your balance ring, and tappable rituals on the home screen. Days
since your last calendar review, in red when you have let it slide. Circular,
rectangular and inline widgets for the Lock Screen and StandBy.

NOTIFICATIONS THAT EARN THEIR PLACE
A morning brief, a midday checkpoint, your rituals at their anchor times, a
shutdown at your hard stop, a Sunday reset. Every one can be turned off
individually.

SIRI AND SHORTCUTS
"Set my keystone." "Check my balance." "Mark my calendar reviewed."

PRIVATE BY DEFAULT
No account. No analytics. No subscription. Your plans, rituals and calendar
analysis stay on your device.
```

**What's New (1.0):**

```
First release.

- One keystone, three momentum tasks, and a maintenance list that knows its place
- Calendar review that finds conflicts, unanswered invites and days with no room to think
- Rituals across Business, Body, Mind, Relationships and Recovery
- A balance score built from execution, rituals, coverage and protection
- Drift detection for the domains you have been starving
- Interactive home screen widgets and Lock Screen complications
- Shutdown ritual to close the day and set tomorrow's keystone
```

## Screenshot plan

Six, in this order. Every one should show real-looking data — an empty Today
screen sells nothing.

1. **Today** — keystone set, balance ring at 74, calendar banner visible
   > "One keystone. The day has a spine."
2. **Calendar review** — a conflict and an unanswered invite flagged
   > "Your calendar, audited every few days."
3. **Balance** — score card plus the four-part breakdown
   > "A number you cannot game."
4. **Rituals** — the week grid with a mix of kept, skipped and missed
   > "Five domains. Skipping honestly still counts."
5. **Widgets** — home screen with Today (medium), Calendar integrity (small),
   Balance (small)
   > "It nags from the home screen."
6. **Shutdown** — step three, tomorrow's keystone being set
   > "Close the day. Then put it down."

## Age rating and category

- **Primary category**: Productivity
- **Secondary category**: Health & Fitness
- **Age rating**: 4+
- **Encryption**: `ITSAppUsesNonExemptEncryption` is already `false` in
  `Info.plist` — the app uses only HTTPS via URLSession, which is exempt

## Known rejection risks

| Risk | Mitigation |
|---|---|
| Full calendar access looks excessive | The review note above explains the read-only analysis; there is no write path to point at |
| Push entitlement with no push feature | Explained in the review note. If you would rather not explain it, remove `aps-environment` from the entitlements and the `remote-notification` background mode from `Info.plist` before submitting |
| Placeholder privacy/support URLs | Publish both pages first — this is the most common cause of a rejection on a first submission |
| Widget shows another person's data in the gallery | Already handled: `getSnapshot` returns `WidgetSnapshot.placeholder` when `context.isPreview` |
