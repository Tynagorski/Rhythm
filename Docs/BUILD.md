# Building and signing Rhythm

## Requirements

- Xcode 16 or later
- iOS 17.0 deployment target (SwiftData, interactive widgets and `chartXSelection` all need it)
- A paid Apple Developer account for device builds, push, and App Store submission

## Identifiers to change

The repo ships with placeholders. Every one of these must change before you can
sign, and the App Group has to match in three places or the widgets will read an
empty store.

| Placeholder | Where | Replace with |
|---|---|---|
| `com.rhythm.app` | app target `PRODUCT_BUNDLE_IDENTIFIER` | your app's bundle ID |
| `com.rhythm.app.widgets` | widget target `PRODUCT_BUNDLE_IDENTIFIER` | `<your bundle ID>.widgets` |
| `com.rhythm.app.tests` | test target | `<your bundle ID>.tests` |
| `group.com.rhythm.app` | `AppGroup.identifier`, both `.entitlements` files | `group.<your bundle ID>` |
| `https://tynagorski.github.io/Rhythm/privacy/` | `SettingsView` | your policy URL, if you move off GitHub Pages |
| `https://tynagorski.github.io/Rhythm/support/` | `SettingsView` | your support URL, if you move off GitHub Pages |

The privacy and support pages are real and deployed from `web/` — see
`Docs/LAUNCH.md`. They only need changing if you move the site to a custom
domain.

The bundle identifiers live in `Scripts/generate_xcodeproj.py` (`BUNDLE_ID`,
`APP_GROUP`). Change them there and regenerate rather than editing the project
file by hand:

```sh
python3 Scripts/generate_xcodeproj.py
```

Then update `AppGroup.identifier` in `Rhythm/Core/Store/AppGroup.swift` and both
entitlements files to match.

## Capabilities to enable on the App ID

In the Developer portal, on the app's identifier:

- **App Groups** — add `group.<your bundle ID>`, and enable it on the widget
  extension's identifier too
- **Push Notifications** — required by `aps-environment` in the entitlements
- **Time Sensitive Notifications** — the escalating calendar nudge raises its
  interruption level after the first day. Without the entitlement iOS silently
  downgrades those to `.active`; the app still works, but the nudge is easier to
  miss. To drop the capability entirely, remove
  `com.apple.developer.usernotifications.time-sensitive` from
  `Rhythm/App/Rhythm.entitlements` and the `.timeSensitive` line in
  `NotificationService.calendarNudgeRequests`.

`aps-environment` is set to `development` in the checked-in entitlements. Xcode
rewrites it to `production` when you archive for distribution, so leave it.

## Signing

Both targets use automatic signing. Select your team on the app target, the
widget target and the test target. The widget extension's bundle ID must be
prefixed by the app's, or embedding fails at build time.

## Running

```sh
open Rhythm.xcodeproj
xcodebuild -scheme Rhythm -destination 'platform=iOS Simulator,name=iPhone 16' build
xcodebuild test -scheme Rhythm -destination 'platform=iOS Simulator,name=iPhone 16'
```

Widgets need a real add from the home screen to exercise the App Intent path;
the SwiftUI previews in each widget file render the layouts without it.

## Testing the parts that need a device

Some behaviour cannot be seen in the simulator or in unit tests:

- **Calendar analysis** — seed a simulator calendar with overlapping events, an
  unanswered invite and a meeting past your hard stop, then open Calendar review
- **Notification actions** — the "Done" / "Skip today" actions on a ritual
  notification write through `RitualMutator`; check the widget updates
- **Interactive widgets** — tap a ritual on the home screen and confirm the app
  shows it kept
- **Remote push** — requires a real device; see `Docs/PUSH_NOTIFICATIONS.md`

## Regenerating the project

`project.pbxproj` is generated so that adding a file is a one-command operation
and diffs stay readable. Object IDs are derived from a hash of each object's
path and role, so regenerating without changing anything produces a byte-
identical file.

After any file move, run the generator and then the checks:

```sh
python3 Scripts/generate_xcodeproj.py
python3 Scripts/check_xcodeproj.py
python3 Scripts/check_target_membership.py
python3 Scripts/check_swift_syntax.py
```

`check_target_membership.py` is the important one. The widget extension is built
with `-application-extension`, so a single reference to a `UIApplication`-
touching type from a shared file breaks the extension build. The script fails if
anything compiled into the extension names a type only the app target declares.
