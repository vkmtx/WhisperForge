#!/usr/bin/env python3
"""Patch the resolved FluidAudio 0.11.0 checkout to build in Swift 5 language mode.

FluidAudio 0.11.0 declares swift-tools-version 6.0, so Xcode 26 / Swift 6.3 compiles
it under strict concurrency and rejects pre-existing data races in its *streaming*
code (StreamingAsrManager.swift) — code this app does not use (it only calls the
batch AsrManager/AsrModels API). Forcing just that target to Swift 5 mode keeps the
build green without touching any other package (e.g. swift-jinja needs Swift 6 mode).

This runs from run.sh after `xcodebuild -resolvePackageDependencies`. It is idempotent
and fails loudly if the upstream manifest layout changes (so the build never silently
regresses). Durable alternative: fork FluidAudio with this one line, or bump to >=0.15.
"""
import pathlib
import sys

DEFAULT = "SourcePackages/checkouts/FluidAudio/Package.swift"

NEEDLE = '''            path: "Sources/FluidAudio",
            exclude: [
                "Frameworks"
            ]
        ),'''

REPLACEMENT = '''            path: "Sources/FluidAudio",
            exclude: [
                "Frameworks"
            ],
            // Xcode 26 / Swift 6 data-race workaround in unused streaming code.
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),'''


def main() -> int:
    path = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else DEFAULT)
    if not path.exists():
        print(f"FluidAudio checkout not found at {path}; "
              "run `xcodebuild -resolvePackageDependencies` first.", file=sys.stderr)
        return 1

    source = path.read_text()
    if "swiftLanguageMode(.v5)" in source:
        print("FluidAudio already in Swift 5 mode — no-op.")
        return 0
    if NEEDLE not in source:
        print("FluidAudio Package.swift layout changed; cannot apply the Swift 5 "
              "patch automatically. Review the manifest manually.", file=sys.stderr)
        return 1

    path.write_text(source.replace(NEEDLE, REPLACEMENT, 1))
    print("Patched FluidAudio target to Swift 5 language mode.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
