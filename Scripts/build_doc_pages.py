#!/usr/bin/env python3
"""Generates the site's two document pages (privacy, support).

They share a shell and a palette with the landing page, so the tokens are lifted
straight out of `web/index.html` rather than duplicated — one palette, one place
to change it. Run after editing the landing page's token block:

    python3 Scripts/build_doc_pages.py
"""

import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
WEB = ROOT / "web"
BASE = "https://tynagorski.github.io/Rhythm"

MARK = (
    '<svg width="22" height="22" viewBox="0 0 22 22" aria-hidden="true">'
    '<circle cx="11" cy="11" r="9" fill="none" stroke="currentColor" stroke-opacity=".25" stroke-width="2.5"></circle>'
    '<path d="M11 2a9 9 0 0 1 7.6 13.8" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round"></path>'
    '<path d="M8 8.2v5.6M11 6.6v8.8M14 8.2v5.6" stroke="currentColor" stroke-width="1.6" stroke-linecap="round"></path>'
    "</svg>"
)

LAYOUT_CSS = """
*, *::before, *::after { box-sizing: border-box; }
body { margin: 0; background: var(--ground); color: var(--ink); font-family: var(--sans);
       font-size: 17px; line-height: 1.65; -webkit-font-smoothing: antialiased; }
a { color: var(--accent); }
:focus-visible { outline: 2px solid var(--accent); outline-offset: 3px; border-radius: 3px; }
.wrap { max-width: 44rem; margin-inline: auto; padding-inline: var(--gutter); }
header.doc { border-bottom: 1px solid var(--hairline); padding-block: .85rem;
             margin-bottom: clamp(2.5rem, 6vw, 4rem); }
.doc-inner { display: flex; align-items: center; justify-content: space-between; gap: 1rem; }
.wordmark { display: inline-flex; align-items: center; gap: .6rem; font-family: var(--mono);
            font-weight: 600; font-size: .95rem; letter-spacing: .04em;
            text-decoration: none; color: var(--ink); }
.doc-inner nav { display: flex; gap: 1.25rem; font-size: .88rem; }
.doc-inner nav a { color: var(--ink-2); text-decoration: none; }
.doc-inner nav a:hover { color: var(--ink); }
.eyebrow { font-family: var(--mono); font-size: .72rem; font-weight: 500; letter-spacing: .14em;
           text-transform: uppercase; color: var(--ink-3); margin: 0; }
h1 { font-family: var(--display); font-optical-sizing: auto; font-weight: 300;
     font-size: clamp(2rem, 5vw, 3rem); line-height: 1.08; letter-spacing: -.025em;
     text-wrap: balance; margin: .9rem 0 1.25rem; }
h2 { font-family: var(--display); font-optical-sizing: auto; font-weight: 500; font-size: 1.4rem;
     line-height: 1.2; letter-spacing: -.012em; text-wrap: balance; margin: 2.75rem 0 .85rem; }
h3 { font-size: 1rem; font-weight: 600; margin: 1.75rem 0 .5rem; color: var(--ink); }
p, li { color: var(--ink-2); }
p { margin: 0 0 1rem; }
strong { color: var(--ink); font-weight: 600; }
ul { padding-left: 1.15rem; margin: 0 0 1rem; }
li { margin-bottom: .45rem; }
.lede { font-size: 1.1rem; }
.callout { background: var(--surface); border: 1px solid var(--hairline);
           border-left: 3px solid var(--accent); border-radius: 0 10px 10px 0;
           padding: 1.15rem 1.35rem; margin: 1.75rem 0; }
.callout p:last-child { margin-bottom: 0; }
.meta { font-family: var(--mono); font-size: .74rem; letter-spacing: .04em;
        color: var(--ink-3); margin-bottom: 2rem; }
details { border-top: 1px solid var(--hairline); padding-block: 1.1rem; }
details:last-of-type { border-bottom: 1px solid var(--hairline); margin-bottom: 1.5rem; }
summary { cursor: pointer; font-weight: 500; color: var(--ink); list-style: none; display: flex;
          justify-content: space-between; gap: 1rem; align-items: baseline; }
summary::-webkit-details-marker { display: none; }
summary::after { content: "+"; font-family: var(--mono); color: var(--ink-3); flex: none; }
details[open] summary::after { content: "\\2013"; }
details p { margin-top: .75rem; font-size: .96rem; }
footer.doc { border-top: 1px solid var(--hairline); margin-top: clamp(3rem, 7vw, 5rem);
             padding-block: 2rem 3rem; font-size: .86rem; color: var(--ink-3);
             display: flex; flex-wrap: wrap; gap: 1rem 1.75rem; justify-content: space-between; }
footer.doc a { color: var(--ink-2); text-decoration: none; }
footer.doc a:hover { color: var(--ink); text-decoration: underline; }
footer.doc nav { display: flex; gap: 1.25rem; flex-wrap: wrap; }
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after { transition-duration: .001ms !important; }
}
"""


def tokens_from_landing():
    """Single source of truth for the palette: the landing page's token block."""
    source = (WEB / "index.html").read_text()
    match = re.search(r"/\* ---- Tokens.*?\n(?=/\* ---- Base)", source, re.S)
    if not match:
        sys.exit("could not find the token block in web/index.html")
    return match.group(0)


def render(slug, title, description, body, extra_head=""):
    css = tokens_from_landing() + LAYOUT_CSS
    canonical = f"{BASE}/{slug}/"
    return f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{title}</title>
<meta name="description" content="{description}">
<link rel="canonical" href="{canonical}">
<meta name="robots" content="index, follow">
<meta name="theme-color" content="#0B0C0F" media="(prefers-color-scheme: dark)">
<meta name="theme-color" content="#F6F6F4" media="(prefers-color-scheme: light)">
<meta property="og:type" content="website">
<meta property="og:site_name" content="Rhythm">
<meta property="og:title" content="{title}">
<meta property="og:description" content="{description}">
<meta property="og:url" content="{canonical}">
<meta property="og:image" content="{BASE}/og.png">
<meta name="twitter:card" content="summary_large_image">
<link rel="icon" href="../favicon.png" type="image/png">
<link rel="apple-touch-icon" href="../apple-touch-icon.png">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=IBM+Plex+Mono:wght@400;500;600&family=IBM+Plex+Sans:wght@400;500;600&family=Newsreader:opsz,wght@6..72,300;6..72,500&display=swap">
{extra_head}<style>{css}</style>
</head>
<body>
<header class="doc">
  <div class="wrap doc-inner">
    <a class="wordmark" href="../">{MARK}Rhythm</a>
    <nav>
      <a href="../">Home</a>
      <a href="../privacy/">Privacy</a>
      <a href="../support/">Support</a>
    </nav>
  </div>
</header>
<main class="wrap">
{body}
</main>
<footer class="doc wrap">
  <span>Rhythm — a daily planner for iOS.</span>
  <nav>
    <a href="../">Home</a>
    <a href="../privacy/">Privacy</a>
    <a href="../support/">Support</a>
    <a href="https://github.com/Tynagorski/Rhythm">Source</a>
  </nav>
</footer>
</body>
</html>
"""


PRIVACY_BODY = """
<p class="eyebrow">Legal</p>
<h1>Privacy Policy</h1>
<p class="meta">Last updated 27 August 2026 · Applies to Rhythm 1.0 and later</p>

<p class="lede">Rhythm does not collect your data. There is no account, no analytics and no
server. Everything you enter, and everything the app works out from your calendar, stays on
your device.</p>

<div class="callout">
  <p><strong>The short version.</strong> No sign-in. No tracking. No third-party SDKs. Calendar
  access is read-only. Nothing is transmitted anywhere, because there is nowhere to transmit
  it to.</p>
</div>

<h2>What Rhythm stores, and where</h2>
<p>Rhythm keeps the following in a private container on your device, shared only between the
app and its own widgets:</p>
<ul>
  <li>Your priorities, rituals and their completion history</li>
  <li>Daily logs: balance scores, energy ratings and any notes you write</li>
  <li>Your settings: workday boundaries, notification preferences, review interval</li>
  <li>The date of your last calendar review</li>
</ul>
<p>This container is protected by iOS. It is included in your device backup if you have
backups switched on, under the same protection Apple applies to the rest of that backup.
None of it is uploaded to us.</p>

<h2>Calendar access</h2>
<p>If you grant calendar access, Rhythm reads events from the calendars you choose in order
to show today's schedule and how much of the day is booked, to detect conflicts, unanswered
invitations, over-booked days and work scheduled outside the hours you set, and to tell you
when you last reviewed the week ahead.</p>
<p><strong>Rhythm never creates, modifies or deletes calendar events.</strong> There is no
write path in the app.</p>
<p>Events are read into memory, analysed on your device, and discarded. The app stores only
the derived numbers — total minutes booked, minutes outside your hours, the length of your
longest clear block. Event titles, attendees and locations are never written to disk by
Rhythm and never transmitted.</p>
<p>You can revoke calendar access at any time in Settings → Privacy &amp; Security →
Calendars. Rhythm keeps working without it; the load and conflict features simply go quiet.</p>

<h2>Notifications</h2>
<p>Notifications are scheduled on your device by the app itself, and their contents are
composed locally from data already on your device.</p>

<h2>Push notifications</h2>
<p>Rhythm registers with Apple Push Notification service so that a future feature can deliver
server-generated prompts. <strong>In this version no push server is configured</strong> — your
device token is stored locally and is not transmitted to us or to anyone else. You can confirm
this in the app under Settings → Push.</p>
<p>If that changes, this policy will be updated before the version that changes it ships.</p>

<h2>What Rhythm does not do</h2>
<ul>
  <li>No analytics or crash-reporting SDKs</li>
  <li>No advertising identifiers, no tracking, no data shared with third parties</li>
  <li>No account, no sign-in, no cloud sync</li>
  <li>No sale of personal information, under any definition</li>
</ul>

<h2>Children</h2>
<p>Rhythm is not directed at children under 13 and does not knowingly collect information from
them. Since the app collects nothing from anyone, there is nothing to delete.</p>

<h2>Your rights</h2>
<p>Because your data never leaves your device, you exercise every right directly:</p>
<ul>
  <li><strong>Access and portability</strong> — your data is in your device backup</li>
  <li><strong>Deletion</strong> — delete the app, or remove its data in iOS Settings; both
  remove the container and everything in it</li>
  <li><strong>Withdraw consent</strong> — revoke calendar or notification permission in iOS
  Settings at any time</li>
</ul>
<p>If you are in the EEA or UK, we are not a data controller for any personal data under GDPR,
because no personal data is transmitted to or processed by us. If you are in California, we do
not collect or sell personal information as the CCPA defines those terms.</p>

<h2>Changes</h2>
<p>If a future version of Rhythm collects or transmits anything, this policy will be updated
before that version ships, and the change will be described in the App Store release notes.</p>

<h2>Contact</h2>
<p>Questions about this policy:
<a href="mailto:hello@example.com">hello@example.com</a></p>

<div class="callout">
  <p><strong>Before you publish this page:</strong> replace the contact address above with a
  real one, confirm the "last updated" date, and add a postal address if your jurisdiction
  requires one. App Review checks that this URL resolves and that the contact route works.</p>
</div>
"""

SUPPORT_BODY = """
<p class="eyebrow">Support</p>
<h1>Help with Rhythm</h1>
<p class="meta">Response within two business days</p>

<p class="lede">Rhythm is a small app with a narrow job, so most questions have short answers.
If yours is not here, write to <a href="mailto:hello@example.com">hello@example.com</a> and
include your iOS version and what you were doing when it went wrong.</p>

<h2>Common questions</h2>

<details open>
  <summary>My widgets are empty even though the app has data</summary>
  <p>This almost always means the App Group is misconfigured — the app and the widget are
  reading different containers. If you built Rhythm yourself, check that the group identifier
  matches in <code>AppGroup.swift</code> and in both entitlements files, and that the group is
  enabled on both App IDs in the Developer portal.</p>
</details>

<details>
  <summary>Rhythm is not seeing my calendar</summary>
  <p>Rhythm needs full calendar access, not write-only access, because the whole feature is
  reading events that already exist. Check Settings → Privacy &amp; Security → Calendars →
  Rhythm. If you have narrowed the calendar list in Rhythm's own settings, confirm the calendar
  you expect is selected — an empty selection means all calendars.</p>
</details>

<details>
  <summary>The calendar nudge stopped appearing</summary>
  <p>That is deliberate. The nudge fires when you pass your review interval and escalates for
  three days, then stops. An alert that never stops is an alert you turn off. Reviewing the
  week ahead resets the clock; the interval itself is in Settings → Calendar review.</p>
</details>

<details>
  <summary>My ritual streak reset even though I kept it</summary>
  <p>Streaks count consecutive <em>scheduled</em> days. A weekdays-only ritual steps over the
  weekend rather than breaking, and a deliberate skip pauses the streak instead of ending it.
  A silent miss on a scheduled day is what ends it.</p>
</details>

<details>
  <summary>Why can I only set one keystone?</summary>
  <p>Because two keystones is zero keystones. The cap is the feature. Setting a new keystone
  demotes the old one to Momentum rather than deleting it.</p>
</details>

<details>
  <summary>Why did my balance score go down on a productive day?</summary>
  <p>Execution is only 30% of it. A day where you finished everything but touched nothing
  outside work scores well on execution and badly on coverage — and if meetings ate the day,
  badly on protection too. Open the Balance tab to see which of the four parts moved.</p>
</details>

<details>
  <summary>Can I get my data out?</summary>
  <p>Rhythm has no export yet. Your data is in your encrypted device backup. If export matters
  to you, say so in an email — it is on the list, and demand decides the order.</p>
</details>

<details>
  <summary>Does Rhythm work on iPad or Apple Watch?</summary>
  <p>iPhone only for now. The project builds for iPad but the layouts are not designed for it,
  and there is no watch app.</p>
</details>

<h2>Reporting a bug</h2>
<p>Useful reports include your iOS version and iPhone model, what you expected versus what
happened, and whether it reproduces. Screenshots of the Balance tab help for anything
score-related.</p>
<p>You can also open an issue on
<a href="https://github.com/Tynagorski/Rhythm/issues">GitHub</a>, which is public.</p>

<h2>Requesting a feature</h2>
<p>Rhythm's job is narrow on purpose, so the honest answer to most feature requests is no. The
ones that get built are the ones that make the existing job work better rather than adding a
new one.</p>

<div class="callout">
  <p><strong>Before you publish this page:</strong> replace the contact address with a real
  one. App Review checks that the support URL resolves and offers a genuine contact route.</p>
</div>
"""

FAQ_SCHEMA = """<script type="application/ld+json">
{"@context":"https://schema.org","@type":"FAQPage","mainEntity":[
{"@type":"Question","name":"Why are my Rhythm widgets empty?","acceptedAnswer":{"@type":"Answer","text":"An empty widget almost always means the App Group is misconfigured, so the app and the widget are reading different containers. Check that the group identifier matches in AppGroup.swift and both entitlements files, and that the group is enabled on both App IDs."}},
{"@type":"Question","name":"Why is Rhythm not seeing my calendar?","acceptedAnswer":{"@type":"Answer","text":"Rhythm needs full calendar access rather than write-only access, because the feature reads events that already exist. Check Settings, Privacy and Security, Calendars, Rhythm. Also confirm the calendar you expect is selected in Rhythm's own calendar list."}},
{"@type":"Question","name":"Why did the calendar reminder stop appearing?","acceptedAnswer":{"@type":"Answer","text":"By design. The nudge fires once you pass your review interval and escalates for three days, then stops. Reviewing the week ahead resets the clock."}},
{"@type":"Question","name":"Why did my balance score drop on a productive day?","acceptedAnswer":{"@type":"Answer","text":"Execution is only 30 percent of the score. A day where everything got finished but nothing outside work was touched scores well on execution and badly on coverage, and badly on protection too if meetings filled the day."}}
]}
</script>
"""


def main():
    (WEB / "privacy").mkdir(parents=True, exist_ok=True)
    (WEB / "support").mkdir(parents=True, exist_ok=True)

    (WEB / "privacy" / "index.html").write_text(render(
        "privacy",
        "Privacy Policy — Rhythm",
        "Rhythm collects no data. No account, no analytics, no server. Calendar access is "
        "read-only and nothing leaves your device.",
        PRIVACY_BODY,
    ))

    (WEB / "support" / "index.html").write_text(render(
        "support",
        "Support — Rhythm",
        "Help with Rhythm: empty widgets, calendar access, streaks, the balance score, bug "
        "reports and feature requests.",
        SUPPORT_BODY,
        extra_head=FAQ_SCHEMA,
    ))

    print("wrote web/privacy/index.html and web/support/index.html")
    return 0


if __name__ == "__main__":
    sys.exit(main())
