# Privacy Policy — Rhythm

**Last updated: [DATE]**
**Effective for Rhythm version 1.0 and later**

> This is a template that matches what the shipped code actually does. Publish it
> at a stable URL, put that URL in App Store Connect and in `SettingsView`, and
> replace every `[BRACKETED]` placeholder. If you change the app — in particular
> if you configure a push endpoint or add analytics — this document has to change
> with it.

## The short version

Rhythm does not collect your data. There is no account, no analytics, and no
server. Everything you enter and everything the app derives from your calendar
stays on your device.

## What Rhythm stores, and where

Rhythm stores the following in a private container on your device, shared only
between the app and its own widgets:

- Your priorities, rituals and their completion history
- Daily logs: balance scores, energy ratings, and any notes you write
- Your settings: workday boundaries, notification preferences, review interval
- The date of your last calendar review

This container is protected by iOS. It is included in your device backup if you
have backups enabled, under the same protection Apple applies to the rest of
that backup. Nothing is uploaded to us, because there is nowhere to upload it to.

## Calendar access

If you grant calendar access, Rhythm reads events from the calendars you choose
in order to:

- show today's schedule and how much of the day is booked,
- detect conflicts, unanswered invitations, over-booked days, and work scheduled
  outside the hours you set,
- tell you when you last reviewed the week ahead.

**Rhythm never creates, modifies or deletes calendar events.** There is no write
path in the app.

Calendar events are read into memory, analysed on your device, and discarded.
The app stores only the derived numbers — total minutes booked, minutes outside
your hours, the length of your longest clear block. Event titles, attendees and
locations are never written to disk by Rhythm and never transmitted.

You can revoke calendar access at any time in Settings → Privacy & Security →
Calendars. Rhythm continues to work without it; the load and conflict features
simply go quiet.

## Notifications

Notifications are scheduled on your device by the app itself. Their contents are
composed locally from data already on your device. Scheduling a notification
sends nothing to us or to Apple beyond the standard iOS delivery mechanism.

## Push notifications

Rhythm registers with Apple Push Notification service (APNs) so that a future
feature can deliver server-generated prompts.

**In this version, no push server is configured.** Your device token is stored
locally and is not transmitted to us or to anyone else. You can confirm this in
the app under Settings → Push.

*[If you configure a push endpoint, replace this section with a description of
what you send, where it is stored, how long you keep it, and how a user can have
it deleted — and update your App Privacy answers in App Store Connect.]*

## What Rhythm does not do

- No analytics or crash-reporting SDKs
- No advertising identifiers, no tracking, no data shared with third parties
- No account, no sign-in, no cloud sync
- No sale of personal information, under any definition

## Children

Rhythm is not directed at children under 13 and does not knowingly collect
information from them. Since the app collects nothing from anyone, there is
nothing to delete.

## Your rights

Because your data never leaves your device, you exercise every right directly:

- **Access and portability** — your data is in your device backup
- **Deletion** — delete the app, or use iOS Settings to remove its data; both
  remove the App Group container and everything in it
- **Withdraw consent** — revoke calendar or notification permission in iOS
  Settings at any time

If you are in the EEA or UK, we are not a data controller for any personal data
under GDPR, because no personal data is transmitted to or processed by us. If
you are in California, we do not collect or sell personal information as CCPA
defines those terms.

## Changes

If a future version of Rhythm collects or transmits anything, this policy will
be updated before that version ships, and the change will be described in the
App Store release notes.

## Contact

[YOUR NAME OR COMPANY]
[SUPPORT EMAIL]
[POSTAL ADDRESS, if required in your jurisdiction]
