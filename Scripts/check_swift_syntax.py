#!/usr/bin/env python3
"""A cheap structural check on the Swift sources.

This is not a compiler. It catches the class of mistake that is easy to make in
a large edit and expensive to discover later: unbalanced braces, brackets or
parentheses, and unterminated string literals. Run it before pushing when a
Swift toolchain is not available.
"""

import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
PAIRS = {"{": "}", "(": ")", "[": "]"}
CLOSERS = {v: k for k, v in PAIRS.items()}


def scan(path):
    text = path.read_text()
    stack = []
    i = 0
    line = 1
    n = len(text)
    problems = []

    while i < n:
        ch = text[i]

        if ch == "\n":
            line += 1
            i += 1
            continue

        # Comments
        if text.startswith("//", i):
            while i < n and text[i] != "\n":
                i += 1
            continue
        if text.startswith("/*", i):
            depth = 1
            i += 2
            while i < n and depth:
                if text.startswith("/*", i):
                    depth += 1
                    i += 2
                elif text.startswith("*/", i):
                    depth -= 1
                    i += 2
                else:
                    if text[i] == "\n":
                        line += 1
                    i += 1
            continue

        # Multi-line string literal
        if text.startswith('"""', i):
            i += 3
            while i < n and not text.startswith('"""', i):
                if text[i] == "\n":
                    line += 1
                i += 1
            i += 3
            continue

        # Single-line string, including \( ) interpolation which can nest.
        if ch == '"':
            start_line = line
            i += 1
            while i < n and text[i] != '"':
                if text[i] == "\\":
                    if i + 1 < n and text[i + 1] == "(":
                        depth = 1
                        i += 2
                        while i < n and depth:
                            if text[i] == "(":
                                depth += 1
                            elif text[i] == ")":
                                depth -= 1
                            elif text[i] == '"':
                                # A nested literal inside interpolation.
                                i += 1
                                while i < n and text[i] != '"':
                                    i += 1 if text[i] != "\\" else 2
                            i += 1
                        continue
                    i += 2
                    continue
                if text[i] == "\n":
                    problems.append("%s:%d: unterminated string literal" % (path, start_line))
                    break
                i += 1
            i += 1
            continue

        # Character-literal-looking escapes outside strings do not exist in Swift,
        # so anything left is structure.
        if ch in PAIRS:
            stack.append((ch, line))
        elif ch in CLOSERS:
            if not stack:
                problems.append("%s:%d: unexpected '%s'" % (path, line, ch))
            else:
                opener, opened_at = stack.pop()
                if PAIRS[opener] != ch:
                    problems.append(
                        "%s:%d: '%s' closes '%s' opened at line %d"
                        % (path, line, ch, opener, opened_at)
                    )
        i += 1

    for opener, opened_at in stack:
        problems.append("%s:%d: unclosed '%s'" % (path, opened_at, opener))
    return problems


def main():
    files = sorted(
        p for base in ("Rhythm", "RhythmWidgets", "RhythmTests")
        for p in (ROOT / base).rglob("*.swift")
    )
    all_problems = []
    for path in files:
        all_problems += scan(path)

    print("checked %d Swift files" % len(files))
    if all_problems:
        print("\nFAILED")
        for problem in all_problems:
            print("  - " + problem.replace(str(ROOT) + "/", ""))
        return 1
    print("OK - delimiters balanced, no unterminated literals")
    return 0


if __name__ == "__main__":
    sys.exit(main())
