#!/usr/bin/env python3
"""Checks the static site in web/ before it is deployed.

A broken canonical tag or an invalid JSON-LD block fails silently — the page
still renders, it just stops working for search engines and link previews. This
catches those, plus internal links that point at nothing and a sitemap that has
drifted from the pages on disk.
"""

import html.parser
import json
import pathlib
import re
import sys
import urllib.parse

ROOT = pathlib.Path(__file__).resolve().parent.parent
WEB = ROOT / "web"
BASE = "https://tynagorski.github.io/Rhythm"

VOID = {"area", "base", "br", "col", "embed", "hr", "img", "input",
        "link", "meta", "param", "source", "track", "wbr"}


class TagBalance(html.parser.HTMLParser):
    """Reports tags left open at EOF, and closers with nothing to close."""

    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.stack = []
        self.problems = []

    def handle_starttag(self, tag, attrs):
        if tag not in VOID:
            self.stack.append((tag, self.getpos()[0]))

    def handle_endtag(self, tag):
        if tag in VOID:
            return
        for index in range(len(self.stack) - 1, -1, -1):
            if self.stack[index][0] == tag:
                del self.stack[index:]
                return
        self.problems.append(f"line {self.getpos()[0]}: </{tag}> closes nothing")

    def finish(self):
        for tag, line in self.stack:
            self.problems.append(f"line {line}: <{tag}> is never closed")
        return self.problems


def meta(source, attr, key):
    match = re.search(
        r'<meta\s+[^>]*%s=["\']%s["\'][^>]*content=["\'](.*?)["\']' % (attr, re.escape(key)),
        source, re.S | re.I)
    return match.group(1) if match else None


def check_page(path, problems):
    rel = path.relative_to(ROOT)
    source = path.read_text()

    parser = TagBalance()
    parser.feed(source)
    for problem in parser.finish():
        problems.append(f"{rel}: {problem}")

    title = re.search(r"<title>(.*?)</title>", source, re.S)
    if not title:
        problems.append(f"{rel}: no <title>")
    elif not 15 <= len(title.group(1)) <= 70:
        problems.append(
            f"{rel}: title is {len(title.group(1))} chars — aim for 15-70 so it is not "
            f"truncated in results")

    description = meta(source, "name", "description")
    if not description:
        problems.append(f"{rel}: no meta description")
    elif not 70 <= len(description) <= 165:
        problems.append(f"{rel}: meta description is {len(description)} chars — aim for 70-165")

    canonical = re.search(r'<link\s+rel=["\']canonical["\']\s+href=["\'](.*?)["\']', source)
    if not canonical:
        problems.append(f"{rel}: no canonical link")
    elif not canonical.group(1).startswith(BASE):
        problems.append(f"{rel}: canonical does not point at {BASE}")

    for key in ("og:title", "og:description", "og:image", "og:url"):
        if not meta(source, "property", key):
            problems.append(f"{rel}: missing {key}")

    if source.count("<h1") > 1:
        problems.append(f"{rel}: more than one <h1>")

    for index, block in enumerate(re.findall(
            r'<script type="application/ld\+json">(.*?)</script>', source, re.S)):
        try:
            json.loads(block)
        except json.JSONDecodeError as error:
            problems.append(f"{rel}: JSON-LD block {index + 1} is invalid — {error}")

    # Internal links must resolve to something that exists on disk.
    for href in re.findall(r'href=["\'](.*?)["\']', source):
        if href.startswith(("http://", "https://", "mailto:", "#", "data:")):
            continue
        target = (path.parent / urllib.parse.urlparse(href).path).resolve()
        if target.is_dir():
            target = target / "index.html"
        if not target.exists():
            problems.append(f"{rel}: link '{href}' resolves to nothing")

    for src in re.findall(r'(?:src|href)=["\'](?!http|mailto|#|data:)([^"\']+\.(?:png|jpg|svg|ico))["\']',
                          source):
        if not (path.parent / src).exists():
            problems.append(f"{rel}: asset '{src}' is missing")


def main():
    problems = []
    pages = sorted(WEB.rglob("index.html"))
    if not pages:
        sys.exit("no pages found in web/")

    for page in pages:
        check_page(page, problems)

    for required in ("robots.txt", "sitemap.xml", "og.png", "favicon.png", "apple-touch-icon.png"):
        if not (WEB / required).exists():
            problems.append(f"web/{required} is missing")

    # The sitemap and the pages on disk must be the same set.
    sitemap = (WEB / "sitemap.xml")
    if sitemap.exists():
        listed = set(re.findall(r"<loc>(.*?)</loc>", sitemap.read_text()))
        on_disk = {
            BASE + "/" + str(p.parent.relative_to(WEB)).replace(".", "").strip("/")
            for p in pages
        }
        on_disk = {url if url.endswith("/") else url + "/" for url in on_disk}
        for missing in sorted(on_disk - listed):
            problems.append(f"sitemap.xml does not list {missing}")
        for extra in sorted(listed - on_disk):
            problems.append(f"sitemap.xml lists {extra}, which has no page")

    print(f"checked {len(pages)} pages")
    if problems:
        print("\nFAILED")
        for problem in problems:
            print("  - " + problem)
        return 1
    print("OK — metadata, structured data, links and sitemap all consistent")
    return 0


if __name__ == "__main__":
    sys.exit(main())
