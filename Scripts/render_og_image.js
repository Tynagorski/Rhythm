/**
 * Renders web/og.png — the 1200x630 card that shows when the site is shared.
 *
 * Uses the Chromium that Playwright already provides rather than hand-plotting
 * pixels, so the card gets real typography and stays in step with the site's
 * palette. Run after changing the brand:
 *
 *   node Scripts/render_og_image.js
 */
const { chromium } = require('playwright');
const path = require('path');
const fs = require('fs');

// This image runs on whatever Chromium the machine already has. Playwright's
// pinned build and the preinstalled one drift apart, so prefer an explicit
// binary when PLAYWRIGHT_CHROMIUM points at one, and fall back to the bundled
// download otherwise.
const EXECUTABLE = process.env.PLAYWRIGHT_CHROMIUM
  || ['/opt/pw-browsers/chromium-1194/chrome-linux/chrome']
       .find((candidate) => fs.existsSync(candidate));

const OUT = path.join(__dirname, '..', 'web', 'og.png');

// The five life domains, in the app's fixed order, with their dark-theme hues
// and the coverage each contributes on the illustrated day.
const DOMAINS = [
  { name: 'Business',      color: '#5C77FC', filled: true  },
  { name: 'Body',          color: '#0BA05D', filled: false },
  { name: 'Mind',          color: '#D546B8', filled: false },
  { name: 'People',        color: '#CA6E03', filled: false },
  { name: 'Recovery',      color: '#1187A8', filled: false },
];

const SCORE = 82;
const COVERAGE = 16;

const html = `<!DOCTYPE html>
<html><head><meta charset="utf-8">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=IBM+Plex+Mono:wght@400;500;600&family=IBM+Plex+Sans:wght@400;500&family=Newsreader:opsz,wght@6..72,300&display=swap">
<style>
  * { box-sizing: border-box; margin: 0; }
  body {
    width: 1200px; height: 630px; background: #0B0C0F; color: #F5F6F8;
    font-family: "IBM Plex Sans", sans-serif; display: flex; overflow: hidden;
  }
  .left { flex: 1; padding: 68px 0 68px 76px; display: flex; flex-direction: column; justify-content: space-between; }
  .mark { display: flex; align-items: center; gap: 13px; font-family: "IBM Plex Mono", monospace;
          font-weight: 600; font-size: 25px; letter-spacing: .05em; }
  h1 { font-family: "Newsreader", Georgia, serif; font-weight: 300; font-size: 62px;
       line-height: 1.04; letter-spacing: -.028em; max-width: 15ch; }
  h1 em { font-style: italic; color: #5C77FC; }
  .foot { font-family: "IBM Plex Mono", monospace; font-size: 17px; letter-spacing: .1em;
          text-transform: uppercase; color: #6B7280; }
  .right { width: 430px; padding: 68px 76px 68px 0; display: flex; flex-direction: column;
           justify-content: center; gap: 30px; }
  .panel { background: #15171C; border: 1px solid #2A2E37; border-radius: 22px; padding: 34px; }
  .gauge { display: flex; align-items: center; gap: 24px; }
  .val { font-family: "IBM Plex Mono", monospace; font-weight: 600; font-size: 52px; line-height: 1;
         color: #0FA271; font-variant-numeric: tabular-nums; }
  .cap { font-family: "IBM Plex Mono", monospace; font-size: 13px; letter-spacing: .15em;
         text-transform: uppercase; color: #6B7280; margin-top: 8px; }
  .rows { margin-top: 30px; padding-top: 26px; border-top: 1px solid #21242B;
          display: flex; flex-direction: column; gap: 14px; }
  .row { display: flex; align-items: center; gap: 14px; font-size: 17px; }
  .row .dot { width: 11px; height: 11px; border-radius: 99px; flex: none; }
  .row span { color: #9AA1AE; flex: 1; }
  .tick { font-family: "IBM Plex Mono", monospace; font-size: 15px; color: #6B7280; }
  .row.on span { color: #F5F6F8; }
  .row.on .tick { color: #0FA271; }
  .covline { margin-top: 26px; font-family: "IBM Plex Mono", monospace; font-size: 15px;
             letter-spacing: .04em; color: #6B7280; }
  .covline b { color: #BC8A0E; font-weight: 600; }
</style></head><body>
  <div class="left">
    <div class="mark">
      <svg width="34" height="34" viewBox="0 0 22 22">
        <circle cx="11" cy="11" r="9" fill="none" stroke="#F5F6F8" stroke-opacity=".25" stroke-width="2.5"/>
        <path d="M11 2a9 9 0 0 1 7.6 13.8" fill="none" stroke="#F5F6F8" stroke-width="2.5" stroke-linecap="round"/>
        <path d="M8 8.2v5.6M11 6.6v8.8M14 8.2v5.6" stroke="#F5F6F8" stroke-width="1.6" stroke-linecap="round"/>
      </svg>
      Rhythm
    </div>
    <h1>Your calendar decides your day.<br><em>Rhythm decides your week.</em></h1>
    <div class="foot">iOS · Widgets · Calendar-aware · No account</div>
  </div>
  <div class="right">
    <div class="panel">
      <div class="gauge">
        <svg width="104" height="104" viewBox="0 0 112 112">
          <circle cx="56" cy="56" r="48" fill="none" stroke="#2A2E37" stroke-width="9"/>
          <circle cx="56" cy="56" r="48" fill="none" stroke="#0FA271" stroke-width="9"
                  stroke-linecap="round" transform="rotate(-90 56 56)"
                  stroke-dasharray="301.6" stroke-dashoffset="${(301.6 * (1 - SCORE / 100)).toFixed(1)}"/>
        </svg>
        <div>
          <div class="val">${SCORE}</div>
          <div class="cap">Balance · today</div>
        </div>
      </div>
      <div class="rows">
        ${DOMAINS.map(d => `<div class="row${d.filled ? ' on' : ''}">
          <span class="dot" style="background:${d.color};opacity:${d.filled ? 1 : .3}"></span>
          <span>${d.name}</span>
          <span class="tick">${d.filled ? 'touched' : '—'}</span>
        </div>`).join('')}
      </div>
      <div class="covline">Coverage <b>${COVERAGE}</b> / 100</div>
    </div>
  </div>
</body></html>`;

(async () => {
  const browser = await chromium.launch(EXECUTABLE ? { executablePath: EXECUTABLE } : {});
  const page = await browser.newPage({ viewport: { width: 1200, height: 630 }, deviceScaleFactor: 1 });
  await page.setContent(html, { waitUntil: 'networkidle' });
  await page.evaluate(() => document.fonts.ready);
  await page.screenshot({ path: OUT });
  await browser.close();
  console.log('wrote', OUT, fs.statSync(OUT).size, 'bytes');
})();
