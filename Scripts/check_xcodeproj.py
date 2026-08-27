#!/usr/bin/env python3
"""Structural check on the generated project.pbxproj.

Xcode is not available in every environment this repo is worked on, so this
parses the OpenStep plist itself and verifies the things that actually break a
project: unparseable syntax, dangling object references, source files listed in
a build phase that do not exist on disk, and targets missing a phase.
"""

import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
PBXPROJ = ROOT / "Rhythm.xcodeproj" / "project.pbxproj"


class Parser:
    """Minimal OpenStep property-list reader — enough for a pbxproj."""

    def __init__(self, text):
        # Strip /* ... */ annotations, which are decoration, not data.
        self.text = re.sub(r"/\*.*?\*/", " ", text, flags=re.S)
        self.i = 0

    def ws(self):
        while self.i < len(self.text):
            if self.text[self.i] in " \t\r\n":
                self.i += 1
            elif self.text.startswith("//", self.i):
                while self.i < len(self.text) and self.text[self.i] != "\n":
                    self.i += 1
            else:
                break

    def parse(self):
        self.ws()
        value = self.value()
        self.ws()
        if self.i != len(self.text):
            raise ValueError("trailing content at offset %d: %r" % (self.i, self.text[self.i:self.i + 40]))
        return value

    def value(self):
        self.ws()
        ch = self.text[self.i]
        if ch == "{":
            return self.dictionary()
        if ch == "(":
            return self.array()
        if ch == '"':
            return self.quoted()
        return self.bare()

    def dictionary(self):
        assert self.text[self.i] == "{"
        self.i += 1
        result = {}
        while True:
            self.ws()
            if self.i >= len(self.text):
                raise ValueError("unterminated dictionary")
            if self.text[self.i] == "}":
                self.i += 1
                return result
            key = self.value()
            self.ws()
            if self.text[self.i] != "=":
                raise ValueError("expected = after key %r at %d" % (key, self.i))
            self.i += 1
            result[key] = self.value()
            self.ws()
            if self.i < len(self.text) and self.text[self.i] == ";":
                self.i += 1

    def array(self):
        assert self.text[self.i] == "("
        self.i += 1
        items = []
        while True:
            self.ws()
            if self.i >= len(self.text):
                raise ValueError("unterminated array")
            if self.text[self.i] == ")":
                self.i += 1
                return items
            items.append(self.value())
            self.ws()
            if self.i < len(self.text) and self.text[self.i] == ",":
                self.i += 1

    def quoted(self):
        self.i += 1
        out = []
        while self.text[self.i] != '"':
            if self.text[self.i] == "\\":
                self.i += 1
            out.append(self.text[self.i])
            self.i += 1
        self.i += 1
        return "".join(out)

    def bare(self):
        start = self.i
        while self.i < len(self.text) and self.text[self.i] not in " \t\r\n;,=(){}\"":
            self.i += 1
        if start == self.i:
            raise ValueError("empty token at %d: %r" % (self.i, self.text[self.i:self.i + 20]))
        return self.text[start:self.i]


UID = re.compile(r"^[0-9A-F]{24}$")


def main():
    problems = []
    root = Parser(PBXPROJ.read_text()).parse()
    objects = root["objects"]
    print("parsed %d objects" % len(objects))

    # 1. Every UID-shaped reference must resolve to a real object.
    def walk(node, path):
        if isinstance(node, dict):
            for k, v in node.items():
                walk(v, path + "/" + str(k))
        elif isinstance(node, list):
            for index, v in enumerate(node):
                walk(v, "%s[%d]" % (path, index))
        elif isinstance(node, str) and UID.match(node) and node not in objects:
            problems.append("dangling reference %s at %s" % (node, path))

    walk(objects, "objects")
    walk(root["rootObject"], "rootObject")

    # 2. Files in a sources phase must exist on disk.
    file_refs = {u: o for u, o in objects.items() if o.get("isa") == "PBXFileReference"}
    build_files = {u: o for u, o in objects.items() if o.get("isa") == "PBXBuildFile"}
    for u, obj in build_files.items():
        ref = obj.get("fileRef")
        target = file_refs.get(ref)
        if target is None:
            continue  # product references live in BUILT_PRODUCTS_DIR
        if target.get("sourceTree") != "SOURCE_ROOT":
            continue
        if not (ROOT / target["path"]).exists():
            problems.append("build file points at missing path: %s" % target["path"])

    # 3. Every Swift file on disk must be compiled by at least one target.
    compiled = set()
    for u, obj in objects.items():
        if obj.get("isa") != "PBXSourcesBuildPhase":
            continue
        for bf in obj.get("files", []):
            ref = build_files.get(bf, {}).get("fileRef")
            path = file_refs.get(ref, {}).get("path")
            if path:
                compiled.add(path)
    on_disk = {
        str(p.relative_to(ROOT))
        for base in ("Rhythm", "RhythmWidgets", "RhythmTests")
        for p in (ROOT / base).rglob("*.swift")
    }
    for path in sorted(on_disk - compiled):
        problems.append("source file is in no target: %s" % path)

    # 4. Targets must be complete.
    targets = {o["name"]: o for o in objects.values() if o.get("isa") == "PBXNativeTarget"}
    expected = {
        "Rhythm": ["PBXSourcesBuildPhase", "PBXFrameworksBuildPhase",
                   "PBXResourcesBuildPhase", "PBXCopyFilesBuildPhase"],
        "RhythmWidgets": ["PBXSourcesBuildPhase", "PBXFrameworksBuildPhase",
                          "PBXResourcesBuildPhase"],
        "RhythmTests": ["PBXSourcesBuildPhase", "PBXFrameworksBuildPhase"],
    }
    for name, phases in expected.items():
        if name not in targets:
            problems.append("missing target %s" % name)
            continue
        actual = [objects[u]["isa"] for u in targets[name]["buildPhases"]]
        for phase in phases:
            if phase not in actual:
                problems.append("%s is missing a %s" % (name, phase))

    # 5. The widget extension must not compile app-only sources.
    widget_phase = next(
        objects[u] for u in targets["RhythmWidgets"]["buildPhases"]
        if objects[u]["isa"] == "PBXSourcesBuildPhase"
    )
    widget_paths = {
        file_refs[build_files[bf]["fileRef"]]["path"] for bf in widget_phase["files"]
    }
    banned = {
        "Rhythm/Core/Services/CalendarService.swift",
        "Rhythm/Core/Services/NotificationService.swift",
        "Rhythm/Core/Services/PushService.swift",
        "Rhythm/Core/Services/RhythmCoordinator.swift",
    }
    for path in sorted(widget_paths & banned):
        problems.append("widget target compiles app-only source: %s" % path)
    for path in sorted(p for p in widget_paths if p.startswith("Rhythm/Features/") or p.startswith("Rhythm/App/")):
        problems.append("widget target compiles app source: %s" % path)

    print("app target sources:    %d" % len({
        file_refs[build_files[bf]["fileRef"]]["path"]
        for u in targets["Rhythm"]["buildPhases"]
        if objects[u]["isa"] == "PBXSourcesBuildPhase"
        for bf in objects[u]["files"]
    }))
    print("widget target sources: %d" % len(widget_paths))

    if problems:
        print("\nFAILED")
        for problem in problems:
            print("  - " + problem)
        return 1
    print("\nOK - project structure is consistent")
    return 0


if __name__ == "__main__":
    sys.exit(main())
