# Remote notifications

## What is and is not remote

Everything Rhythm sends day to day is a **local** notification, scheduled by
`NotificationService.rescheduleAll` on the device: the morning brief, the midday
checkpoint, per-ritual anchors, the shutdown, the Sunday reset, drift alerts,
and the escalating calendar nudge. They work offline, need no account, and no
data leaves the device to produce them.

APNs is reserved for the two things a device cannot do alone:

1. **Coaching prompts derived from long-range trends** — patterns that need more
   history or more computation than is reasonable on device.
2. **Silent sync** — a `content-available` push that tells Rhythm to re-derive
   its state and refresh widgets, for when the app has not been opened in days.

## Client state

`PushService.endpoint` is `nil` by default. In that state:

- the device registers with APNs and receives a token,
- the token is stored in the App Group `UserDefaults`,
- **nothing is transmitted**.

Setting `endpoint` turns on registration upload. Do that only once you have a
backend and have updated the App Privacy answers — see `Docs/APP_STORE.md`.

```swift
// e.g. in RhythmApp.task
PushService.shared.endpoint = URL(string: "https://api.example.com/v1/devices")
```

## Registration payload

`POST` to your endpoint, `Content-Type: application/json`:

```json
{
  "token": "a1b2c3…",
  "platform": "ios",
  "bundleID": "com.rhythm.app",
  "environment": "development",
  "timeZone": "America/New_York",
  "appVersion": "1.0"
}
```

`environment` is `development` in DEBUG builds and `production` otherwise, so the
server knows which APNs host to use without a separate flag. `timeZone` matters:
a server-sent nudge that arrives at 3am is worse than no nudge.

Respond `2xx`. Anything else is surfaced in Settings → Push as a registration
error.

## Payloads Rhythm understands

### A visible nudge

```json
{
  "aps": {
    "alert": {
      "title": "Recovery has gone quiet",
      "body": "Nine days without a single recovery entry. Put something small on tomorrow."
    },
    "sound": "default",
    "interruption-level": "active"
  },
  "route": "balance"
}
```

`route` maps to `RhythmRoute` and decides where the tap lands: `today`, `plan`,
`rituals`, `balance`, `calendarReview`, `shutdown`, `settings`. An unknown or
missing route opens Today.

### A silent refresh

```json
{
  "aps": { "content-available": 1 },
  "command": "recompute"
}
```

`command` is handled by `PushService.handle(payload:)`:

| Command | Effect |
|---|---|
| `refresh` | Reloads all widget timelines |
| `recompute` | Full pass: calendar, scores, drift, notification schedule, widgets |

Silent pushes need `content-available: 1`, no `alert`, and the
`remote-notification` background mode — all already configured. iOS throttles
them; treat delivery as best-effort and never make correctness depend on one.

## Server requirements

- **APNs auth key** (`.p8`), key ID, team ID. Prefer token auth over
  certificates: one key covers every app and never expires.
- **HTTP/2 to `api.push.apple.com`** (`api.sandbox.push.apple.com` for
  development tokens). Match the host to the `environment` the client reported —
  sending a sandbox token to production returns `BadDeviceToken`.
- **`apns-push-type`**: `alert` for visible nudges, `background` for silent ones.
  Required, and a silent push with `apns-push-type: alert` is rejected.
- **`apns-priority`**: `10` for alerts, `5` for background (`10` is rejected for
  background pushes).
- **`apns-topic`**: your bundle ID.
- **Token hygiene**: on a `410 Unregistered` response, delete the token. Tokens
  also rotate — take the newest registration for a device as authoritative.

## Testing

On a real device (the simulator supports drag-and-drop `.apns` files but not the
full registration path):

```sh
# Simulator: drop a .apns file onto the window, or
xcrun simctl push booted com.rhythm.app payload.apns
```

`payload.apns` needs a `Simulator Target Bundle` key alongside `aps`.

For a device, either run your server against the sandbox host or use a tool that
speaks APNs token auth directly. Check Settings → Push in the app to confirm the
token registered before debugging the server side.
