#!/usr/bin/env python3
"""Guards the app / extension source split.

The widget extension is built with -application-extension, so a single stray
reference to a UIApplication-touching type breaks the build in a way that only
shows up at link time. This checks the rule directly: nothing compiled into the
extension may name a type that only the app target declares.
"""

import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent

APP_ONLY_CORE = {
    "Rhythm/Core/Services/CalendarService.swift",
    "Rhythm/Core/Services/NotificationService.swift",
    "Rhythm/Core/Services/PushService.swift",
    "Rhythm/Core/Services/RhythmCoordinator.swift",
}

DECLARATION = re.compile(
    r"^(?:@\w+(?:\([^)]*\))?\s+)*"
    r"(?:public |internal |private |fileprivate |final |\s)*"
    r"(?:struct|class|enum|protocol|actor)\s+([A-Z]\w*)",
    re.M,
)


def strip_comments(text):
    """Comments mention app-only types legitimately; only code counts."""
    text = re.sub(r"/\*.*?\*/", " ", text, flags=re.S)
    return re.sub(r"//[^\n]*", "", text)


def classify():
    all_swift = sorted(
        str(p.relative_to(ROOT))
        for base in ("Rhythm", "RhythmWidgets")
        for p in (ROOT / base).rglob("*.swift")
    )
    shared = [
        s for s in all_swift
        if (s.startswith("Rhythm/Core/") or s.startswith("Rhythm/Intents/"))
        and s not in APP_ONLY_CORE
    ]
    widget_only = [s for s in all_swift if s.startswith("RhythmWidgets/")]
    app_only = [s for s in all_swift if s not in shared and s not in widget_only]
    return shared, widget_only, app_only


def declared_types(files):
    found = {}
    for f in files:
        for match in DECLARATION.finditer(strip_comments((ROOT / f).read_text())):
            found.setdefault(match.group(1), f)
    return found


def main():
    shared, widget_only, app_only = classify()
    app_types = declared_types(app_only)
    extension_types = declared_types(shared + widget_only)
    app_exclusive = {k: v for k, v in app_types.items() if k not in extension_types}

    problems = []
    for f in shared + widget_only:
        code = strip_comments((ROOT / f).read_text())
        for name, source in app_exclusive.items():
            if re.search(r"\b%s\b" % re.escape(name), code):
                problems.append("%s references %s, which only %s declares" % (f, name, source))

    print("extension compiles %d shared + %d widget sources; %d are app-only"
          % (len(shared), len(widget_only), len(app_only)))
    if problems:
        print("\nFAILED")
        for problem in problems:
            print("  - " + problem)
        return 1
    print("OK - the extension depends on nothing app-only")
    return 0


if __name__ == "__main__":
    sys.exit(main())
