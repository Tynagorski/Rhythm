#!/usr/bin/env python3
"""Generates Rhythm.xcodeproj/project.pbxproj.

The project file is checked in so the repo opens in Xcode with no extra tooling,
but it is generated rather than hand-edited: run this script after adding or
moving a source file. Object IDs are derived from a hash of each object's path
and role, so regenerating produces a byte-identical file and diffs stay readable.
"""

import hashlib
import os
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
PROJECT = ROOT / "Rhythm.xcodeproj"

APP_TARGET = "Rhythm"
WIDGET_TARGET = "RhythmWidgets"
TEST_TARGET = "RhythmTests"

BUNDLE_ID = "com.rhythm.app"
APP_GROUP = "group.com.rhythm.app"
DEPLOYMENT_TARGET = "17.0"
SWIFT_VERSION = "5.0"
MARKETING_VERSION = "1.0"
PROJECT_VERSION = "1"

# Sources under Rhythm/ that must NOT be compiled into the widget extension:
# they touch UIApplication or EventKit, neither of which belongs in an
# app-extension binary.
APP_ONLY_CORE = {
    "Rhythm/Core/Services/CalendarService.swift",
    "Rhythm/Core/Services/NotificationService.swift",
    "Rhythm/Core/Services/PushService.swift",
    "Rhythm/Core/Services/RhythmCoordinator.swift",
}


def uid(*parts: str) -> str:
    """Deterministic 24-hex-character object identifier."""
    digest = hashlib.sha256("::".join(parts).encode()).hexdigest()
    return digest[:24].upper()


def swift_sources(directory: str):
    base = ROOT / directory
    return sorted(
        str(p.relative_to(ROOT))
        for p in base.rglob("*.swift")
    )


def collect():
    app_sources = swift_sources("Rhythm")
    widget_sources = swift_sources("RhythmWidgets")
    test_sources = swift_sources("RhythmTests")

    shared = [
        s for s in app_sources
        if (s.startswith("Rhythm/Core/") or s.startswith("Rhythm/Intents/"))
        and s not in APP_ONLY_CORE
    ]
    widget_compiled = shared + widget_sources
    return app_sources, widget_compiled, widget_sources, test_sources


class Project:
    def __init__(self):
        self.objects = []          # (uid, isa, body, section)
        self.file_refs = {}        # path -> uid

    def add(self, obj_uid, isa, body, section):
        self.objects.append((obj_uid, isa, body, section))

    def file_ref(self, path, explicit_type=None, name=None, source_tree="SOURCE_ROOT"):
        if path in self.file_refs:
            return self.file_refs[path]
        ref = uid("fileRef", path)
        self.file_refs[path] = ref
        ext = os.path.splitext(path)[1]
        types = {
            ".swift": "sourcecode.swift",
            ".plist": "text.plist.xml",
            ".entitlements": "text.plist.entitlements",
            ".xcassets": "folder.assetcatalog",
            ".md": "net.daringfireball.markdown",
        }
        ftype = explicit_type or types.get(ext, "text")
        display = name or os.path.basename(path)
        self.add(
            ref, "PBXFileReference",
            'isa = PBXFileReference; lastKnownFileType = {t}; name = "{n}"; path = "{p}"; sourceTree = "{s}";'.format(
                t=ftype, n=display, p=path, s=source_tree),
            "PBXFileReference",
        )
        return ref

    def product_ref(self, name, filename, ftype):
        ref = uid("product", name)
        self.add(
            ref, "PBXFileReference",
            'isa = PBXFileReference; explicitFileType = "{t}"; includeInIndex = 0; '
            'path = "{f}"; sourceTree = BUILT_PRODUCTS_DIR;'.format(t=ftype, f=filename),
            "PBXFileReference",
        )
        return ref

    def build_file(self, path, target, settings=""):
        bf = uid("buildFile", target, path)
        ref = self.file_refs[path]
        extra = " settings = {%s};" % settings if settings else ""
        self.add(
            bf, "PBXBuildFile",
            'isa = PBXBuildFile; fileRef = {r};{e}'.format(r=ref, e=extra),
            "PBXBuildFile",
        )
        return bf

    def group(self, name, children, path=None, key=None):
        gid = uid("group", key or name, *children)
        child_list = "\n".join("\t\t\t\t{c},".format(c=c) for c in children)
        path_line = '\n\t\t\tpath = "%s";' % path if path else ""
        self.add(
            gid, "PBXGroup",
            "isa = PBXGroup;\n\t\t\tchildren = (\n{ch}\n\t\t\t);\n\t\t\tname = \"{n}\";{p}\n\t\t\tsourceTree = \"<group>\";".format(
                ch=child_list, n=name, p=path_line),
            "PBXGroup",
        )
        return gid


def build_settings(lines, indent="\t\t\t\t"):
    return "\n".join("{i}{k} = {v};".format(i=indent, k=k, v=v) for k, v in lines)


def generate():
    app_sources, widget_compiled, widget_only, test_sources = collect()
    p = Project()

    # ---- File references -------------------------------------------------
    for path in app_sources + widget_only + test_sources:
        p.file_ref(path)

    app_plist = p.file_ref("Rhythm/App/Info.plist")
    app_privacy = p.file_ref("Rhythm/App/PrivacyInfo.xcprivacy", explicit_type="text.plist.xml")
    widget_privacy = p.file_ref("RhythmWidgets/PrivacyInfo.xcprivacy", explicit_type="text.plist.xml")
    app_entitlements = p.file_ref("Rhythm/App/Rhythm.entitlements")
    widget_plist = p.file_ref("RhythmWidgets/Info.plist")
    widget_entitlements = p.file_ref("RhythmWidgets/RhythmWidgets.entitlements")
    assets = p.file_ref("Rhythm/Resources/Assets.xcassets")

    app_product = p.product_ref(APP_TARGET, "Rhythm.app", "wrapper.application")
    widget_product = p.product_ref(WIDGET_TARGET, "RhythmWidgets.appex", "wrapper.app-extension")
    test_product = p.product_ref(TEST_TARGET, "RhythmTests.xctest", "wrapper.cfbundle")

    # ---- Groups ----------------------------------------------------------
    def tree_group(prefix, label):
        """Mirrors the on-disk folder layout one level deep, which is how the
        source is organised and how a reader expects to navigate it."""
        direct = [s for s in app_sources if s.startswith(prefix) and "/" not in s[len(prefix):]]
        subdirs = sorted({s[len(prefix):].split("/")[0]
                          for s in app_sources
                          if s.startswith(prefix) and "/" in s[len(prefix):]})
        children = []
        for sub in subdirs:
            sub_prefix = prefix + sub + "/"
            files = [p.file_refs[s] for s in app_sources if s.startswith(sub_prefix)]
            children.append(p.group(sub, files, key=sub_prefix))
        children += [p.file_refs[s] for s in direct]
        return p.group(label, children, key=prefix)

    app_group = p.group(
        "App",
        [p.file_refs[s] for s in app_sources if s.startswith("Rhythm/App/")]
        + [app_plist, app_entitlements, app_privacy],
        key="group/app",
    )
    core_group = tree_group("Rhythm/Core/", "Core")
    features_group = tree_group("Rhythm/Features/", "Features")
    intents_group = p.group(
        "Intents",
        [p.file_refs[s] for s in app_sources if s.startswith("Rhythm/Intents/")],
        key="group/intents",
    )
    resources_group = p.group("Resources", [assets], key="group/resources")
    rhythm_group = p.group(
        "Rhythm",
        [app_group, core_group, features_group, intents_group, resources_group],
        key="group/rhythm",
    )
    widgets_group = p.group(
        "RhythmWidgets",
        [p.file_refs[s] for s in widget_only] + [widget_plist, widget_entitlements, widget_privacy],
        key="group/widgets",
    )
    tests_group = p.group(
        "RhythmTests",
        [p.file_refs[s] for s in test_sources],
        key="group/tests",
    )
    products_group = p.group(
        "Products", [app_product, widget_product, test_product], key="group/products"
    )
    root_group = p.group(
        "", [rhythm_group, widgets_group, tests_group, products_group], key="group/root"
    )

    # ---- Build phases ----------------------------------------------------
    def sources_phase(target, paths):
        files = [p.build_file(path, target) for path in paths]
        pid = uid("sources", target)
        p.add(pid, "PBXSourcesBuildPhase",
              "isa = PBXSourcesBuildPhase;\n\t\t\tbuildActionMask = 2147483647;\n\t\t\tfiles = (\n"
              + "\n".join("\t\t\t\t{f},".format(f=f) for f in files)
              + "\n\t\t\t);\n\t\t\trunOnlyForDeploymentPostprocessing = 0;",
              "PBXSourcesBuildPhase")
        return pid

    def resources_phase(target, refs):
        files = []
        for path in refs:
            bf = uid("buildFile", target, path)
            p.add(bf, "PBXBuildFile",
                  "isa = PBXBuildFile; fileRef = {r};".format(r=p.file_refs[path]),
                  "PBXBuildFile")
            files.append(bf)
        pid = uid("resources", target)
        p.add(pid, "PBXResourcesBuildPhase",
              "isa = PBXResourcesBuildPhase;\n\t\t\tbuildActionMask = 2147483647;\n\t\t\tfiles = (\n"
              + "\n".join("\t\t\t\t{f},".format(f=f) for f in files)
              + "\n\t\t\t);\n\t\t\trunOnlyForDeploymentPostprocessing = 0;",
              "PBXResourcesBuildPhase")
        return pid

    def frameworks_phase(target):
        pid = uid("frameworks", target)
        p.add(pid, "PBXFrameworksBuildPhase",
              "isa = PBXFrameworksBuildPhase;\n\t\t\tbuildActionMask = 2147483647;\n\t\t\tfiles = (\n\t\t\t);"
              "\n\t\t\trunOnlyForDeploymentPostprocessing = 0;",
              "PBXFrameworksBuildPhase")
        return pid

    app_sources_phase = sources_phase(APP_TARGET, app_sources)
    app_resources_phase = resources_phase(
        APP_TARGET, ["Rhythm/Resources/Assets.xcassets", "Rhythm/App/PrivacyInfo.xcprivacy"]
    )
    app_frameworks = frameworks_phase(APP_TARGET)

    widget_sources_phase = sources_phase(WIDGET_TARGET, widget_compiled)
    # The extension ships its own privacy manifest; App Store Connect checks each
    # binary in the bundle, not just the app.
    widget_resources_phase = resources_phase(WIDGET_TARGET, ["RhythmWidgets/PrivacyInfo.xcprivacy"])
    widget_frameworks = frameworks_phase(WIDGET_TARGET)

    test_sources_phase = sources_phase(TEST_TARGET, test_sources)
    test_frameworks = frameworks_phase(TEST_TARGET)

    # Embedding the extension inside the app bundle.
    embed_ref = uid("buildFile", "embed", WIDGET_TARGET)
    p.add(embed_ref, "PBXBuildFile",
          'isa = PBXBuildFile; fileRef = {r}; settings = {{ATTRIBUTES = (RemoveHeadersOnCopy, ); }};'.format(r=widget_product),
          "PBXBuildFile")
    embed_phase = uid("copyFiles", "embedExtensions")
    p.add(embed_phase, "PBXCopyFilesBuildPhase",
          "isa = PBXCopyFilesBuildPhase;\n\t\t\tbuildActionMask = 2147483647;\n"
          '\t\t\tdstPath = "";\n\t\t\tdstSubfolderSpec = 13;\n\t\t\tfiles = (\n\t\t\t\t{f},\n\t\t\t);\n'
          '\t\t\tname = "Embed Foundation Extensions";\n\t\t\trunOnlyForDeploymentPostprocessing = 0;'.format(f=embed_ref),
          "PBXCopyFilesBuildPhase")

    # ---- Target dependencies --------------------------------------------
    project_id = uid("project", "Rhythm")

    def dependency(name, target_uid, product_ref_uid):
        proxy = uid("containerProxy", name)
        p.add(proxy, "PBXContainerItemProxy",
              "isa = PBXContainerItemProxy;\n\t\t\tcontainerPortal = {pr};\n\t\t\tproxyType = 1;\n"
              '\t\t\tremoteGlobalIDString = {t};\n\t\t\tremoteInfo = "{n}";'.format(
                  pr=project_id, t=target_uid, n=name),
              "PBXContainerItemProxy")
        dep = uid("dependency", name)
        p.add(dep, "PBXTargetDependency",
              'isa = PBXTargetDependency;\n\t\t\ttarget = {t};\n\t\t\ttargetProxy = {p};'.format(
                  t=target_uid, p=proxy),
              "PBXTargetDependency")
        return dep

    app_target_id = uid("target", APP_TARGET)
    widget_target_id = uid("target", WIDGET_TARGET)
    test_target_id = uid("target", TEST_TARGET)

    widget_dep = dependency(WIDGET_TARGET, widget_target_id, widget_product)
    app_dep = dependency(APP_TARGET, app_target_id, app_product)

    # ---- Build configurations -------------------------------------------
    common_project = [
        ("ALWAYS_SEARCH_USER_PATHS", "NO"),
        ("CLANG_ENABLE_MODULES", "YES"),
        ("CLANG_ENABLE_OBJC_ARC", "YES"),
        ("ENABLE_STRICT_OBJC_MSGSEND", "YES"),
        ("GCC_C_LANGUAGE_STANDARD", "gnu17"),
        ("IPHONEOS_DEPLOYMENT_TARGET", DEPLOYMENT_TARGET),
        ("SDKROOT", "iphoneos"),
        ("SWIFT_VERSION", SWIFT_VERSION),
        ("TARGETED_DEVICE_FAMILY", '"1,2"'),
        ("CLANG_WARN_DOCUMENTATION_COMMENTS", "YES"),
        ("CLANG_WARN_UNGUARDED_AVAILABILITY", "YES_AGGRESSIVE"),
        ("GCC_WARN_UNINITIALIZED_AUTOS", "YES_AGGRESSIVE"),
        ("SWIFT_EMIT_LOC_STRINGS", "YES"),
        ("ENABLE_USER_SCRIPT_SANDBOXING", "YES"),
        ("MARKETING_VERSION", MARKETING_VERSION),
        ("CURRENT_PROJECT_VERSION", PROJECT_VERSION),
    ]
    debug_project = common_project + [
        ("DEBUG_INFORMATION_FORMAT", "dwarf"),
        ("ENABLE_TESTABILITY", "YES"),
        ("GCC_OPTIMIZATION_LEVEL", "0"),
        ("SWIFT_ACTIVE_COMPILATION_CONDITIONS", '"DEBUG $(inherited)"'),
        ("SWIFT_OPTIMIZATION_LEVEL", '"-Onone"'),
        ("ONLY_ACTIVE_ARCH", "YES"),
    ]
    release_project = common_project + [
        ("DEBUG_INFORMATION_FORMAT", '"dwarf-with-dsym"'),
        ("ENABLE_NS_ASSERTIONS", "NO"),
        ("SWIFT_COMPILATION_MODE", "wholemodule"),
        ("VALIDATE_PRODUCT", "YES"),
    ]

    app_common = [
        ("ASSETCATALOG_COMPILER_APPICON_NAME", "AppIcon"),
        ("ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME", "AccentColor"),
        ("CODE_SIGN_ENTITLEMENTS", '"Rhythm/App/Rhythm.entitlements"'),
        ("CODE_SIGN_STYLE", "Automatic"),
        ("CURRENT_PROJECT_VERSION", PROJECT_VERSION),
        ("ENABLE_PREVIEWS", "YES"),
        ("GENERATE_INFOPLIST_FILE", "NO"),
        ("INFOPLIST_FILE", '"Rhythm/App/Info.plist"'),
        ("INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents", "YES"),
        ("LD_RUNPATH_SEARCH_PATHS", '"$(inherited) @executable_path/Frameworks"'),
        ("PRODUCT_BUNDLE_IDENTIFIER", BUNDLE_ID),
        ("PRODUCT_NAME", '"$(TARGET_NAME)"'),
        ("SWIFT_EMIT_LOC_STRINGS", "YES"),
    ]
    widget_common = [
        ("CODE_SIGN_ENTITLEMENTS", '"RhythmWidgets/RhythmWidgets.entitlements"'),
        ("CODE_SIGN_STYLE", "Automatic"),
        ("ENABLE_PREVIEWS", "YES"),
        ("GENERATE_INFOPLIST_FILE", "NO"),
        ("INFOPLIST_FILE", '"RhythmWidgets/Info.plist"'),
        ("INFOPLIST_KEY_CFBundleDisplayName", "Rhythm"),
        ("INFOPLIST_KEY_NSHumanReadableCopyright", '""'),
        ("LD_RUNPATH_SEARCH_PATHS", '"$(inherited) @executable_path/Frameworks @executable_path/../../Frameworks"'),
        ("PRODUCT_BUNDLE_IDENTIFIER", BUNDLE_ID + ".widgets"),
        ("PRODUCT_NAME", '"$(TARGET_NAME)"'),
        ("SKIP_INSTALL", "YES"),
    ]
    test_common = [
        ("BUNDLE_LOADER", '"$(TEST_HOST)"'),
        ("CODE_SIGN_STYLE", "Automatic"),
        ("GENERATE_INFOPLIST_FILE", "YES"),
        ("PRODUCT_BUNDLE_IDENTIFIER", BUNDLE_ID + ".tests"),
        ("PRODUCT_NAME", '"$(TARGET_NAME)"'),
        ("TEST_HOST", '"$(BUILT_PRODUCTS_DIR)/Rhythm.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/Rhythm"'),
    ]

    def config(name, key, settings):
        cid = uid("config", key, name)
        p.add(cid, "XCBuildConfiguration",
              "isa = XCBuildConfiguration;\n\t\t\tbuildSettings = {{\n{s}\n\t\t\t}};\n\t\t\tname = {n};".format(
                  s=build_settings(settings), n=name),
              "XCBuildConfiguration")
        return cid

    def config_list(key, debug_id, release_id):
        lid = uid("configList", key)
        p.add(lid, "XCConfigurationList",
              "isa = XCConfigurationList;\n\t\t\tbuildConfigurations = (\n\t\t\t\t{d},\n\t\t\t\t{r},\n\t\t\t);\n"
              "\t\t\tdefaultConfigurationIsVisible = 0;\n\t\t\tdefaultConfigurationName = Release;".format(
                  d=debug_id, r=release_id),
              "XCConfigurationList")
        return lid

    project_configs = config_list(
        "project",
        config("Debug", "project", debug_project),
        config("Release", "project", release_project),
    )
    app_configs = config_list(
        "app",
        config("Debug", "app", app_common),
        config("Release", "app", app_common),
    )
    widget_configs = config_list(
        "widget",
        config("Debug", "widget", widget_common),
        config("Release", "widget", widget_common),
    )
    test_configs = config_list(
        "tests",
        config("Debug", "tests", test_common),
        config("Release", "tests", test_common),
    )

    # ---- Targets ---------------------------------------------------------
    p.add(app_target_id, "PBXNativeTarget",
          "isa = PBXNativeTarget;\n\t\t\tbuildConfigurationList = {c};\n\t\t\tbuildPhases = (\n"
          "\t\t\t\t{s},\n\t\t\t\t{f},\n\t\t\t\t{r},\n\t\t\t\t{e},\n\t\t\t);\n"
          "\t\t\tbuildRules = (\n\t\t\t);\n\t\t\tdependencies = (\n\t\t\t\t{d},\n\t\t\t);\n"
          '\t\t\tname = "{n}";\n\t\t\tproductName = "{n}";\n\t\t\tproductReference = {pr};\n'
          '\t\t\tproductType = "com.apple.product-type.application";'.format(
              c=app_configs, s=app_sources_phase, f=app_frameworks, r=app_resources_phase,
              e=embed_phase, d=widget_dep, n=APP_TARGET, pr=app_product),
          "PBXNativeTarget")

    p.add(widget_target_id, "PBXNativeTarget",
          "isa = PBXNativeTarget;\n\t\t\tbuildConfigurationList = {c};\n\t\t\tbuildPhases = (\n"
          "\t\t\t\t{s},\n\t\t\t\t{f},\n\t\t\t\t{r},\n\t\t\t);\n"
          "\t\t\tbuildRules = (\n\t\t\t);\n\t\t\tdependencies = (\n\t\t\t);\n"
          '\t\t\tname = "{n}";\n\t\t\tproductName = "{n}";\n\t\t\tproductReference = {pr};\n'
          '\t\t\tproductType = "com.apple.product-type.app-extension";'.format(
              c=widget_configs, s=widget_sources_phase, f=widget_frameworks,
              r=widget_resources_phase, n=WIDGET_TARGET, pr=widget_product),
          "PBXNativeTarget")

    p.add(test_target_id, "PBXNativeTarget",
          "isa = PBXNativeTarget;\n\t\t\tbuildConfigurationList = {c};\n\t\t\tbuildPhases = (\n"
          "\t\t\t\t{s},\n\t\t\t\t{f},\n\t\t\t);\n"
          "\t\t\tbuildRules = (\n\t\t\t);\n\t\t\tdependencies = (\n\t\t\t\t{d},\n\t\t\t);\n"
          '\t\t\tname = "{n}";\n\t\t\tproductName = "{n}";\n\t\t\tproductReference = {pr};\n'
          '\t\t\tproductType = "com.apple.product-type.bundle.unit-test";'.format(
              c=test_configs, s=test_sources_phase, f=test_frameworks,
              d=app_dep, n=TEST_TARGET, pr=test_product),
          "PBXNativeTarget")

    # ---- Project ---------------------------------------------------------
    project_body = "\n".join([
        "isa = PBXProject;",
        "\t\t\tattributes = {",
        "\t\t\t\tBuildIndependentTargetsInParallel = 1;",
        "\t\t\t\tLastSwiftUpdateCheck = 1620;",
        "\t\t\t\tLastUpgradeCheck = 1620;",
        "\t\t\t\tTargetAttributes = {",
        "\t\t\t\t\t" + app_target_id + " = {CreatedOnToolsVersion = 16.2;};",
        "\t\t\t\t\t" + widget_target_id + " = {CreatedOnToolsVersion = 16.2;};",
        "\t\t\t\t\t" + test_target_id + " = {CreatedOnToolsVersion = 16.2; TestTargetID = " + app_target_id + ";};",
        "\t\t\t\t};",
        "\t\t\t};",
        "\t\t\tbuildConfigurationList = " + project_configs + ";",
        '\t\t\tcompatibilityVersion = "Xcode 15.0";',
        "\t\t\tdevelopmentRegion = en;",
        "\t\t\thasScannedForEncodings = 0;",
        "\t\t\tknownRegions = (",
        "\t\t\t\ten,",
        "\t\t\t\tBase,",
        "\t\t\t);",
        "\t\t\tmainGroup = " + root_group + ";",
        "\t\t\tproductRefGroup = " + products_group + ";",
        '\t\t\tprojectDirPath = "";',
        '\t\t\tprojectRoot = "";',
        "\t\t\ttargets = (",
        "\t\t\t\t" + app_target_id + ",",
        "\t\t\t\t" + widget_target_id + ",",
        "\t\t\t\t" + test_target_id + ",",
        "\t\t\t);",
    ])
    p.add(project_id, "PBXProject", project_body, "PBXProject")

    return p, project_id


SECTION_ORDER = [
    "PBXBuildFile", "PBXContainerItemProxy", "PBXCopyFilesBuildPhase", "PBXFileReference",
    "PBXFrameworksBuildPhase", "PBXGroup", "PBXNativeTarget", "PBXProject",
    "PBXResourcesBuildPhase", "PBXSourcesBuildPhase", "PBXTargetDependency",
    "XCBuildConfiguration", "XCConfigurationList",
]


def render(p, project_id):
    out = ["// !$*UTF8*$!", "{", "\tarchiveVersion = 1;", "\tclasses = {", "\t};",
           "\tobjectVersion = 60;", "\tobjects = {"]

    seen = set()
    for section in SECTION_ORDER:
        entries = [(u, body) for (u, isa, body, sec) in p.objects if sec == section]
        # Deduplicate: shared build phases can register the same object twice.
        unique = {}
        for u, body in entries:
            unique[u] = body
        if not unique:
            continue
        out.append("")
        out.append("/* Begin {s} section */".format(s=section))
        for u in sorted(unique):
            if u in seen:
                continue
            seen.add(u)
            out.append("\t\t{u} = {{".format(u=u))
            out.append("\t\t\t" + unique[u].replace("\n", "\n"))
            out.append("\t\t};")
        out.append("/* End {s} section */".format(s=section))

    out.append("\t};")
    out.append("\trootObject = {r};".format(r=project_id))
    out.append("}")
    return "\n".join(out) + "\n"


SCHEME_TEMPLATE = '''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion = "1620" version = "1.7">
   <BuildAction parallelizeBuildables = "YES" buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry buildForTesting = "YES" buildForRunning = "YES" buildForProfiling = "YES" buildForArchiving = "YES" buildForAnalyzing = "YES">
{app_ref}
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction buildConfiguration = "Debug" selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv = "YES">
      <Testables>
         <TestableReference skipped = "NO">
{test_ref}
         </TestableReference>
      </Testables>
   </TestAction>
   <LaunchAction buildConfiguration = "Debug" selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB" launchStyle = "0" useCustomWorkingDirectory = "NO" ignoresPersistentStateOnLaunch = "NO" debugDocumentVersioning = "YES" debugServiceExtension = "internal" allowLocationSimulation = "YES">
      <BuildableProductRunnable runnableDebuggingMode = "0">
{app_ref}
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction buildConfiguration = "Release" shouldUseLaunchSchemeArgsEnv = "YES" savedToolIdentifier = "" useCustomWorkingDirectory = "NO" debugDocumentVersioning = "YES">
      <BuildableProductRunnable runnableDebuggingMode = "0">
{app_ref}
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction buildConfiguration = "Debug">
   </AnalyzeAction>
   <ArchiveAction buildConfiguration = "Release" revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
'''


def main():
    p, project_id = generate()
    text = render(p, project_id)
    PROJECT.mkdir(parents=True, exist_ok=True)
    (PROJECT / "project.pbxproj").write_text(text)

    shared = PROJECT / "project.xcworkspace" / "xcshareddata"
    shared.mkdir(parents=True, exist_ok=True)
    (PROJECT / "project.xcworkspace" / "contents.xcworkspacedata").write_text(
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<Workspace version = "1.0">\n'
        '   <FileRef location = "self:"></FileRef>\n'
        '</Workspace>\n'
    )
    (shared / "IDEWorkspaceChecks.plist").write_text(
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n'
        '<plist version="1.0">\n<dict>\n\t<key>IDEDidComputeMac32BitWarning</key>\n\t<true/>\n</dict>\n</plist>\n'
    )
    write_scheme()
    print("wrote {} ({} objects)".format(PROJECT / "project.pbxproj", len(p.objects)))
    return 0


def write_scheme():
    """A shared scheme, so `xcodebuild -scheme Rhythm` works on a fresh clone."""
    app = uid("target", APP_TARGET)
    tests = uid("target", TEST_TARGET)

    def buildable(blueprint, name, product):
        return (
            '            <BuildableReference\n'
            '               BuildableIdentifier = "primary"\n'
            '               BlueprintIdentifier = "{b}"\n'
            '               BuildableName = "{p}"\n'
            '               BlueprintName = "{n}"\n'
            '               ReferencedContainer = "container:Rhythm.xcodeproj">\n'
            '            </BuildableReference>'
        ).format(b=blueprint, n=name, p=product)

    app_ref = buildable(app, APP_TARGET, "Rhythm.app")
    test_ref = buildable(tests, TEST_TARGET, "RhythmTests.xctest")

    scheme = SCHEME_TEMPLATE.format(app_ref=app_ref, test_ref=test_ref)
    directory = PROJECT / "xcshareddata" / "xcschemes"
    directory.mkdir(parents=True, exist_ok=True)
    (directory / "Rhythm.xcscheme").write_text(scheme)


if __name__ == "__main__":
    sys.exit(main())
