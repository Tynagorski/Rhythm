# Getting Rhythm live

## What is blocking, honestly

An iOS app cannot be published from a Linux container. Three things are required
and none of them can be automated away:

| Requirement | Why | Who can do it |
|---|---|---|
| A Mac with Xcode 16 | Swift for iOS only compiles on macOS | You |
| Apple Developer Program, $99/yr | Signing certificates and App Store Connect | You |
| Apple review | 24–48h typical for a first submission | Apple |

So the honest sequence is: **you open the project on a Mac, fix whatever the
compiler finds, push a TestFlight build, and iterate there.** Everything below
is written to make each of those steps as short as possible.

## The fast path to a usable build

TestFlight, not the App Store. The App Store is where you go once the thing has
survived a few real weeks; TestFlight is where you find out that it hasn't.

1. `open Rhythm.xcodeproj`, set your team on all three targets, hit Build. Fix
   the compile diagnostics — the code has never been through a compiler, so
   expect some.
2. Run the tests: `xcodebuild test -scheme Rhythm -destination 'platform=iOS Simulator,name=iPhone 16'`
3. Follow `Docs/BUILD.md` for the bundle IDs, App Group and capabilities.
4. Archive → Distribute → TestFlight.
5. **Internal testers** (up to 100, anyone on your team) get builds with **no
   review at all** — usually available within ten minutes of processing.
   **External testers** (up to 10,000) need a short review, normally under a day.
6. Once you have a public TestFlight link, put it on the site: it replaces the
   `mailto:` in the CTA of `web/index.html`.

Use internal TestFlight for the first two weeks. Ship daily. The app is built
around a weekly rhythm, so you need at least three real weeks of your own use
before the App Store version is worth anyone's time.

## The website is already live-able

`web/` is a real static site and `.github/workflows/pages.yml` deploys it on
every push.

**The plan is to make this repository public**, which is what GitHub Pages needs
on a free account. Until that happens the deploy workflow probes the Pages API,
gets a 403, and skips with a notice rather than failing — so CI stays green
either way.

### Turning it on

1. **Settings → General → scroll to Danger Zone → Change visibility → Make
   public.** GitHub asks you to type the repository name to confirm.
2. **Actions → Deploy site → Run workflow.** The preflight step enables Pages
   over the API automatically once the plan allows it, so there is no second
   setting to find.
3. The site is at `https://tynagorski.github.io/Rhythm/` about a minute later.

The workflow deploys from `main` **and** from the feature branch, so the site
goes up before the app PR merges. Once it merges, trim the branch list in
`pages.yml` to `main`.

### Before you make it public

The repository has been checked for secrets, signing material and credential
files — there are none, and `.gitignore` already excludes `.p8`, `.p12`, `.cer`
and `.mobileprovision`. Two things are still worth knowing:

- **Your commit metadata becomes public**, including the author email address on
  every commit. If you would rather not have it scraped, set GitHub → Settings →
  Emails → *Keep my email address private*, and use the `@users.noreply.github.com`
  address it gives you for future commits. Existing commits keep the old address
  unless the history is rewritten.
- **The scoring engine is the idea**, and it will be readable. That is a real
  trade — it is also the thing that makes a Show HN or a build-in-public thread
  work, so it can cut in your favour.

### If you change your mind later

Making a repository private again is a single setting, but anything already
cloned or forked stays cloned. The alternative that avoids the trade entirely is
Cloudflare Pages or Netlify: both deploy a public site from a *private* repo for
free, with `web/` as the publish root and no build command.

## SEO: what will and will not work

**"Rhythm" is not a rankable term.** It is a common English word, a music
concept, an energy company and several other products. You will not rank for it,
and chasing it wastes the effort. Brand queries only start mattering once people
already know the name — which is the *end* of the funnel, not the start.

**`tynagorski.github.io/Rhythm` is a weak SEO asset.** It is a path on a shared
subdomain with none of your own authority. Buy a domain — `getrhythm.app`,
`rhythmapp.co`, whatever is free — and point it at Pages via a `CNAME` file in
`web/`. Do it before you build any links, because migrating later loses you
months.

**Where the traffic actually is: long-tail problem queries.** People do not
search for your app, they search for their problem. The site is already written
around these, and they are worth checking in a keyword tool before you write
anything else:

- "app that reminds you to update your calendar"
- "work life balance app for executives"
- "how to stop meetings taking over my day"
- "app to block deep work time"
- "one big thing a day method"
- "habit tracker with home screen widgets iphone"
- "shutdown ritual end of workday"
- "how many meetings is too many per day"

Each of those is a blog post that ranks, not a landing page section. A landing
page ranks for two or three phrases; twenty honest articles rank for hundreds.
If you want compounding search traffic, that is the actual work — one piece a
week, each answering one question completely.

**The App Store is a separate discipline.** App Store ranking is ASO, and Google
SEO does almost nothing for it. What moves ASO:

- The **title** and **subtitle** are weighted most heavily. `Docs/APP_STORE.md`
  has `Rhythm: Focus & Life Balance` / `Run your day, keep your life`. The title
  field is the single highest-leverage 30 characters you will write.
- The **keyword field** (100 chars, comma-separated, no spaces, never repeat a
  word already in the title).
- **Ratings volume and velocity.** This dominates everything else. Ask for the
  rating in-app after a user's third completed shutdown — someone who has closed
  out three days is someone who likes the app.

## On "going viral"

Worth being straight with you: **productivity apps essentially never go viral
from a landing page.** The ones that appear to have — Sunsama, Amie, Structured —
grew over one to three years through consistent audience-building. Treat anyone
promising otherwise as selling something.

What is genuinely in your favour is that Rhythm has a **thesis**, and theses
travel where feature lists do not. The shareable claim is:

> *You can score 82 out of 100 on a day where four fifths of your life got
> nothing. That is why the number is worthless without the breakdown.*

That is a screenshot, an argument, and a reason to send it to a colleague. Build
the launch around that claim, not around "productivity app for professionals."

Channels that actually work for this category, in the order I would spend effort:

1. **Build in public.** Post the weekly balance breakdown from your *own* use —
   real numbers, including the bad weeks. This audience can smell a fake
   screenshot instantly. Twelve weeks of this outperforms any launch day.
2. **Product Hunt**, once TestFlight has real users and a few testimonials. A
   launch with no existing audience lands nowhere; the launch amplifies an
   audience, it does not create one.
3. **Reddit** — r/productivity, r/iosapps, r/ExperiencedDevs. Lead with the
   thesis and the honest limitations. A post about *the idea* that mentions the
   app survives; a post about the app gets removed.
4. **LinkedIn** for this specific audience, which is genuinely where the target
   user is. The "82 with 16 coverage" screenshot is built for that feed.
5. **Short video** demoing one thing: tapping a ritual on the home screen widget
   without opening the app. Interactive widgets still surprise people.
6. **Hacker News Show HN** — the repo is public and the architecture is unusual
   enough (generated `pbxproj`, pure scoring engine, checkers that run without a
   Mac) to interest that crowd. Lead with the engineering, not the marketing.

The thing that actually determines whether any of this works is retention. An
app people use for three weeks and abandon cannot be marketed into success. Get
TestFlight retention above roughly 40% at week four before spending real effort
on any of the above.

## Order of operations

- [ ] Make the repository public (Settings → General → Danger Zone), then run
      the Deploy site workflow. Verify the URL loads in a private window
- [ ] Consider switching to a `noreply` commit email first, if you would rather
      your address not be public
- [ ] Buy a domain and add `web/CNAME`; update `BASE` in
      `Scripts/build_doc_pages.py`, `Scripts/check_site.py`, the canonical tags
      and `SettingsView`
- [ ] Replace `hello@example.com` on the privacy and support pages with a real
      address
- [ ] Open the project on a Mac, compile, fix, get the tests green
- [ ] TestFlight internal build; use it yourself for three weeks
- [ ] TestFlight external, 20–50 people who match the target user
- [ ] Only then: App Store submission per `Docs/APP_STORE.md`
- [ ] Start the weekly article cadence the day the site goes live, not the day
      the app ships — search traffic takes months to compound and there is no
      reason to spend those months waiting
