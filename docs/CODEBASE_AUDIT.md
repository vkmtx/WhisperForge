
# WhisperForge — Rebrand & Refinement Engineering Plan

## 1. Executive summary

- **Functionally complete fork, but identity is ~50% upstream.** The app runs and the rebrand to "WhisperForge" is half-done: bundle id is still `ru.starmel.OpenSuperWhisper`, Apple Team is the upstream author's `8LLDD7HWZK`, all four top-level dirs / the `.xcodeproj` / scheme / 3 targets / test classes still say `OpenSuperWhisper`, and release scripts push to `Starmel/OpenSuperWhisper`. The git remote is already correctly `vkmtx/WhisperForge`. **The rebrand is the single biggest, lowest-risk win.**
- **One critical security leak ships today:** the full transcript and LLM-enhanced output are written in cleartext via raw `print()` (IndicatorWindow.swift:166, ContentView.swift:236) into the macOS unified log in Release builds — verbatim speech-to-text persisted off the app's trust boundary even though the history feature is off by default. Fix first.
- **Concurrency correctness is held together by Swift 5 language mode.** `SWIFT_VERSION = 5.0` on every config (confirmed pbxproj:837/901/924/948/965/982) means Swift 6 race checking is OFF for the app's own code. Real races exist (shared non-Sendable engine across two flows, `AudioRecorder.startRecording()` off-main, `cancelTranscription()` resetting `isCancelled` synchronously). These are latent today, hard errors after migration.
- **Build reproducibility rests on floating inputs:** uninitialized submodules (confirmed `-` for both `asian-autocorrect` and `libwhisper/whisper.cpp`), an in-place FluidAudio 0.11.0 Swift-5 monkeypatch that newer FluidAudio removes the need for, and a stale root `Package.resolved` that disagrees with the workspace. The release scripts (`notarize_app.sh`/`make_release.sh`) never apply the FluidAudio patch, so a clean Release build can fail where CI stays green.
- **Biggest wins, in order:** (1) redact transcript logging; (2) complete the rebrand so signing/notarization/releases work at all; (3) fix the cancellation + shared-engine races; (4) bump deps & retire the FluidAudio patch; (5) de-duplicate the two record/decode pipelines and download boilerplate.

---

## 2. Rebrand / de-noise checklist (ordered to keep the build green)

Target identity: product **WhisperForge**, bundle id **com.vitorsolen.WhisperForge**, repo **vkmtx/WhisperForge**, your own Apple Team ID (you must supply `<YOUR_TEAM_ID>`) and your own notarytool keychain profile (`<YOUR_NOTARY_PROFILE>`).

> Do steps in this order. Steps 1–3 are content-only edits that don't move files (build stays green). Steps 4–7 are the directory/target/scheme rename (the **risky** block — do it as one atomic commit and rebuild immediately). Steps 8–9 are scripts/docs (no build impact).

### Phase A — In-place identifier edits (no file moves; build stays green)

1. **Bundle identifiers** (pbxproj lines 831, 894, 920, 944, 962, 979):
   - `ru.starmel.OpenSuperWhisper` → `com.vitorsolen.WhisperForge`
   - `ru.starmel.OpenSuperWhisperTests` → `com.vitorsolen.WhisperForgeTests`
   - `ru.starmel.OpenSuperWhisperUITests` → `com.vitorsolen.WhisperForgeUITests`
   - **CRITICAL / risky:** changing the bundle id resets the user's TCC grants (mic + accessibility recorded under the old id). Expected for a rebrand; note in release notes.
2. **DEVELOPMENT_TEAM** (pbxproj lines 794, 795, 855, 856, 912, 936, 959, 976): `8LLDD7HWZK` → `<YOUR_TEAM_ID>`. **Risky:** signing fails until this is your real team. If signing locally only, consider `CODE_SIGN_STYLE = Automatic`.
3. **Keychain service + Logger subsystems** (string identifiers, not auto-renamed):
   - `KeychainHelper.swift:9` `com.opensuperwhisper.llm` → `com.vitorsolen.WhisperForge.llm` — **risky:** orphans any existing stored LLM API key (acceptable for fresh rebrand; one-line migration note in README).
   - `KeychainHelper.swift:31` and `TextEnhancer.swift:14` Logger subsystem `com.opensuperwhisper` → `com.vitorsolen.WhisperForge`.
4. **User-facing UI strings → "WhisperForge":**
   - `OpenSuperWhisperApp.swift:165` (accessibilityDescription), `:178` (status-bar menu title)
   - `OnboardingView.swift:332` (`Text("OpenSuperWhisper")`)
   - `OpenSuperWhisper-Info.plist:23,25,27` (mic/accessibility usage strings)
   - pbxproj INFOPLIST_KEY usage strings `811, 813, 873, 875`
5. **Settings GitHub link** `Settings.swift:649` → `https://github.com/vkmtx/WhisperForge`.
6. **LICENSE:1-3** → `Copyright (c) 2026 Vitor Solen (WhisperForge)`; add a second line crediting `Copyright (c) 2024 Starmel (OpenSuperWhisper)` to preserve MIT attribution.
7. **README:** fix the broken `cd OpenWhisper` (Readme.md:58 → `cd WhisperForge`).
8. **Comment banners** (cosmetic, low priority): `//  OpenSuperWhisper` → `//  WhisperForge` in the 8 Swift files + Bridge.h:3 (ContentView, OnboardingView, OpenSuperWhisperApp, FocusUtils, Whis, the 3 test files); delete/replace the `Created by user` lines across the `Whis/*.swift` set.

> Build + run here. Everything still compiles because no files/targets moved.

### Phase B — Source struct + entry point rename (still no file moves yet)

9. **`@main` struct:** `OpenSuperWhisperApp.swift` — rename `struct OpenSuperWhisperApp` → `WhisperForgeApp` (lines 15, 57, 102 incl. `OpenSuperWhisperApp.startTranscriptionQueue()`). Build to confirm before moving the file.

### Phase C — The rename block (RISKY — do atomically, rebuild immediately)

10. **`git mv` directories:**
    - `OpenSuperWhisper/` → `WhisperForge/`
    - `OpenSuperWhisper.xcodeproj/` → `WhisperForge.xcodeproj/`
    - `OpenSuperWhisperTests/` → `WhisperForgeTests/`
    - `OpenSuperWhisperUITests/` → `WhisperForgeUITests/`
11. **`git mv` the source/config files inside:**
    - `OpenSuperWhisperApp.swift` → `WhisperForgeApp.swift`
    - `OpenSuperWhisper-Info.plist` → `WhisperForge-Info.plist`
    - `OpenSuperWhisper.entitlements` → `WhisperForge.entitlements`
    - `OpenSuperWhisperTests.swift` → `WhisperForgeTests.swift`
    - `OpenSuperWhisperUITests.swift` → `WhisperForgeUITests.swift`
    - `OpenSuperWhisperUITestsLaunchTests.swift` → `WhisperForgeUITestsLaunchTests.swift`
    - `OpenSuperWhisper.xcscheme` → `WhisperForge.xcscheme`
12. **Rename the 3 targets in pbxproj** (`OpenSuperWhisper`→`WhisperForge`, `…Tests`, `…UITests`) and fix every dependent: target name, group `path`, product `.app`/`.xctest` names, `remoteInfo`, build-config-list names, `PBXProject` name, Exceptions-folder entry, `INFOPLIST_FILE` (785→ new plist path; 809), `CODE_SIGN_ENTITLEMENTS` (785, 846), `DEVELOPMENT_ASSET_PATHS`, `TEST_HOST`, `TEST_TARGET_NAME`. `PRODUCT_NAME = "$(TARGET_NAME)"` means the `.app` auto-renames — no override needed.
13. **Delete the stale absolute DerivedData path** at pbxproj:157 (`OpenSuperWhisper-hahlbuibzstrsfgaftshbjlrlesk/...`) — dead, machine-specific; SPM regenerates linking via subproject proxies.
14. **Fix the scheme** `WhisperForge.xcscheme`: `BuildableName`/`BlueprintName`/`ReferencedContainer` for all three targets (lines 19-21, 39-41, 50-52, 63, 83-85, 100-102).
15. **`@testable import`:** `WhisperForgeTests.swift:12` `import OpenSuperWhisper` → `import WhisperForge`; rename the 3 test classes.
16. **`DevConfig.swift:13`** — update the `// OpenSuperWhisper` path-component comment to `// WhisperForge` (the `#filePath` walk still works; comment-only).

> **Rebuild + run the test target now.** This is the make-or-break step. If the project won't open, the pbxproj target rename is the likely culprit.

### Phase D — Build/release scripts & artifacts (no build impact)

17. **run.sh:** scheme `OpenSuperWhisper`→`WhisperForge` (lines 36, 46), echo (45), entitlements path → `WhisperForge/WhisperForge.entitlements` (46), built-app paths/executable → `WhisperForge.app/.../WhisperForge` (64, 66). Also fix the case-sensitivity bug: `-derivedDataPath build` (lowercase) vs `./Build/Build/...` (capital) — unify to one casing.
18. **notarize_app.sh:** `APP_NAME="WhisperForge"` (5), `APP_PATH=./build/Build/Products/Release/WhisperForge.app` (6), `ZIP_PATH=./build/WhisperForge.zip` (7), `BUNDLE_ID="com.vitorsolen.WhisperForge"` (8), `KEYCHAIN_PROFILE=<YOUR_NOTARY_PROFILE>` (9), `DEVELOPMENT_TEAM=<YOUR_TEAM_ID>` (11), `-scheme "WhisperForge"` (31). **Also add the missing FluidAudio patch step** (see §4) so clean Release builds don't fail.
19. **make_release.sh:** repoint all `api.github.com`/`uploads.github.com` endpoints `Starmel/OpenSuperWhisper` → `vkmtx/WhisperForge` (145, 174, 201, 220, 225); sed targets `OpenSuperWhisper.xcodeproj` → `WhisperForge.xcodeproj` (55, 58, 60, 120); DMG/dSYM names `OpenSuperWhisper.dmg`/`.app.dSYM.zip` → `WhisperForge.*` (67-69, 88, 97-98); cask block (246-258) → cask `whisperforge`, url/homepage `vkmtx/WhisperForge`, name/app `WhisperForge.app`, zap paths → `com.vitorsolen.WhisperForge`; brew line in release body (150); fix default version `0.0.4` → align to `MARKETING_VERSION 0.1.0` (line 5). **Risky:** with a valid token these scripts will create real releases on `vkmtx/WhisperForge`.
20. **.gitignore:123** `OpenSuperWhisper.dmg.sha256` → `WhisperForge.dmg.sha256` (or generalize to `*.dmg.sha256`).

---

## 3. Critical & high-severity fixes

| # | Severity | Issue | Fix |
|---|---|---|---|
| 1 | **CRITICAL (privacy)** | Transcript/LLM output logged in cleartext in Release. `IndicatorWindow.swift:166` `print("Transcription result: \(outputText)")`, `ContentView.swift:236`. ~75 unguarded `print()` total leak file paths (`FileDropHandler.swift:37`) and DB path (`Recording.swift:85`). | Delete the transcript/output prints outright. Migrate remaining diagnostics to `os.Logger` with `privacy: .private`, or gate behind `#if DEBUG`. Never log `text`/`outputText`. |
| 2 | **HIGH (race)** | `cancelTranscription()` sets `isCancelled = true` then synchronously `isCancelled = false` (`TranscriptionService.swift:34`) before the detached task observes it — Swift-side cancellation is dead. | Remove the reset on line 34. Leave `isCancelled` true; it is already cleared at the start of the next `transcribeAudio()` (line 88). |
| 3 | **HIGH (race)** | Shared single `currentEngine` (`TranscriptionService.swift:16`) used by both live (IndicatorWindow:115) and queue (TranscriptionQueue:239) flows with no mutual exclusion; they stomp `abortFlag`/`onProgressUpdate`/`progress`. The per-call `onProgressUpdate` (lines 118-132) is never cleared, so a stale closure fires for the wrong job. | Serialize transcription in `TranscriptionService` (one in-flight op; the queue should respect the same busy gate as the indicator). Scope `onProgressUpdate` per-call and clear it on completion. Long-term: make engines `actor`s. |
| 4 | **HIGH (concurrency)** | `AudioRecorder.startRecording()` called from `Task.detached` (IndicatorWindow:93, ContentView:173) while it mutates `@Published` state, `currentRecordingURL`, `audioRecorder`, and races main-thread `stopRecording()`. Delegate callbacks set `@Published` off-main. | Make `AudioRecorder` `@MainActor`; push only the blocking device I/O into an explicit `nonisolated async` helper. Dispatch delegate `@Published` mutations to main. |
| 5 | **HIGH (Swift 6 blocker)** | Whole app target is Swift 5 language mode (pbxproj SWIFT_VERSION=5.0 ×6) — race checking off. | Stage: set `SWIFT_STRICT_CONCURRENCY = targeted` (still Swift 5) to surface warnings, fix #2–#4 + #6–#9, then flip `SWIFT_VERSION = 6.0`. Independent of the FluidAudio package patch. |
| 6 | **HIGH (data-race)** | `TranscriptionEngine` is `: AnyObject` (not Sendable); `WhisperEngine`/`FluidAudioEngine` non-Sendable, mutated cross-actor. WhisperEngine doesn't lock `onProgressUpdate`/`progressContext`; FluidAudioEngine has **no** sync. | Convert engines to `actor` or mark protocol `: AnyObject, Sendable` and lock all mutable state (incl. `onProgressUpdate`). |
| 7 | **MEDIUM** | `FluidAudioEngine.transcriptionTask` never assigned → `cancelTranscription()` is a no-op; in-flight `transcribe(url)` cannot be interrupted (FluidAudioEngine.swift:11, 77, 97-103). | Wrap the transcribe call in `transcriptionTask` and check `Task.isCancelled`, or drop the dead field and rely on structured cancellation. |
| 8 | **MEDIUM** | `loadEngine()` has no in-flight guard; rapid Settings changes spawn concurrent detached inits, a stale engine can win (`TranscriptionService.swift:37-67`). | Add a load generation token; only assign `currentEngine`/`isLoading` if the completing load is still latest. |
| 9 | **MEDIUM** | WhisperEngine parallel conversion (`WhisperEngine.swift:312-371`) has data races (`hasError`/`totalWritten` unlocked) and index-based placement that can insert silent gaps for audio >10s. | Concatenate worker outputs in order instead of index math; validate summed length, fall back to sequential on mismatch; lock shared counters. Compute active-channel mixing once per file. |
| 10 | **MEDIUM (privacy)** | Over-broad entitlements: `automation.apple-events` + `temporary-exception.apple-events`/`.accessibility` granted but **no** AppleEvents/AppleScript usage exists in source. | Remove the apple-events automation entitlement, the temporary-exception arrays, and the 3 temporary-exception.accessibility keys. Keep only `device.microphone`/`audio-input` + `accessibility`. Re-verify paste works. |
| 11 | **MEDIUM (secrets)** | LLM API key sent to user-editable `llmBaseURL` with no host allowlist (`OpenAICompatibleClient.swift:16-18`, `AnthropicClient.swift:21-23`, `TextEnhancer.swift:56-61` only checks scheme). | For known cloud providers, only attach the key if resolved host matches the provider default host; treat custom baseURL as no-cloud-key; warn in Settings on host mismatch. |
| 12 | **MEDIUM (file-resource)** | `AudioRecorder.stopRecording()` opens a 2nd `AVAudioPlayer` on the just-stopped file to read duration, racing the async flush → valid short recordings silently dropped (`AudioRecorder.swift:178-195`). | Read duration via `AVURLAsset`/`AVAudioFile`; wait for `audioRecorderDidFinishRecording`; distinguish "too short" from "read failed" (don't `try?`-swallow). |
| 13 | LOW→MED (privacy) | `NSAllowsLocalNetworking = true` relaxes ATS for the whole LAN, not just loopback (Info.plist). | Replace with `NSExceptionDomains` scoped to `localhost`/`127.0.0.1`; in `TextEnhancer` allow `http://` only for loopback hosts. |
| 14 | LOW (crash) | `Bundle.main.bundleIdentifier!` force-unwraps (`Recording.swift:40,82`, `WhisperModelManager.swift:52`) crash in test/unsigned contexts; `fatalError` on DB init (Recording.swift:93). | Nil-coalesce the identifier; recover from DB failure instead of `fatalError`. |
| 15 | LOW | `updateStatusBarMenu()` adds an `.appPreferencesLanguageChanged` observer every call (OpenSuperWhisperApp.swift:197-202), invoked on every mic change → accumulating duplicate observers. | Register the observer once in `applicationDidFinishLaunching`/`setupStatusBarItem`. |
| 16 | LOW | `WhisperDownloadDelegate` divides by `expectedContentLength` without guarding `-1`/`0` (`WhisperModelManager.swift:19-30`) → NaN/garbage progress when Content-Length absent. | Only compute progress when `expectedContentLength > 0`; update whenever a valid (>0) value arrives. |
| 17 | LOW | Live-dictation errors swallowed with `print` + temp file deleted (`IndicatorWindow.swift:167-170`) → silent data loss, no retry. | Surface an error state in the indicator; don't delete source audio on failure; log via `os.Logger`. |

---

## 4. Dependency & tooling updates

1. **Delete stale root `/Package.resolved`** (pins GRDB 6.29.3, KeyboardShortcuts 1.17.0, omits FluidAudio — dead, not read by the Xcode-project build). Authoritative file is `…/swiftpm/Package.resolved` (confirmed: FluidAudio 0.11.0, GRDB 7.5.0, KeyboardShortcuts 3.0.0).
2. **Bump GRDB 7.5.0 → 7.11.1** (within existing `upToNextMajor 7.5.0`; minor/patch, low risk). Run `xcodebuild -resolvePackageDependencies`, commit updated workspace `Package.resolved`.
3. **Bump KeyboardShortcuts 3.0.0 → 3.0.1** (patch; within `upToNextMajor 3.0.0`). Trivial.
4. **Bump FluidAudio 0.11.0 → 0.15.4 and DELETE the Swift-5 patch.** This is the highest-value tooling change: removes `Scripts/patch_fluidaudio.py` and the patch block in run.sh (~lines 37-42). **SOURCE-BREAKING:** `AsrManager` became an `actor` in 0.12.6 — audit all `AsrManager`/`AsrModels` call sites in `FluidAudioEngine.swift` and add `await` where flagged. Constraint already permits it (`upToNextMajor 0.7.9`, confirmed pbxproj:1048-1049).
   - **If you do NOT bump yet:** add the patch step (`patch_fluidaudio.py` + `-resolvePackageDependencies`) to `notarize_app.sh`/`make_release.sh` — currently only `run.sh` applies it (confirmed: grep finds the reference only in run.sh), so clean Release builds fail.
5. **Initialize & pin submodules.** Both `asian-autocorrect` (203fd5f) and `libwhisper/whisper.cpp` (f3ff80e) show `-` (not checked out). Add a bootstrap step and document it: `git submodule update --init --recursive`. No script currently runs this; only CI does via `actions/checkout submodules:recursive`. Add it to `run.sh`/`notarize_app.sh` or a `bootstrap.sh` and reference from README.
6. **CI determinism (`.github/workflows/build.yml`):** pin `runs-on: macos-15` (not `macos-latest`) and pin Xcode via `maxim-lobanov/setup-xcode`. Optional: pin/cache `cmake`/`libomp`/`rust`.
7. **Deployment-target inconsistency:** app configs say 14.0 but project-level + Tests say 15.1 (confirmed pbxproj:711/768 = 15.1, 824/887 = 14.0); CMake says 14.0; README claims 14.0. Decide one floor (15.1 is simplest) and make all configs + README + cask agree, or actually validate 14.x.

---

## 5. Refinement / simplification

- **De-dup the two record/decode pipelines** (`ContentViewModel` ContentView.swift:15-292 vs `IndicatorViewModel` IndicatorWindow.swift:21-257) — extract a shared `RecordingSession` service (observers, blink timers, transcribe→persist Recording). Note the main-window path skips LLM/paste and ignores `saveDictationHistory`; unifying also fixes that divergence.
- **De-dup model-download boilerplate** (`SettingsViewModel` Settings.swift:282-499 vs `OnboardingViewModel` OnboardingView.swift:114-280; `isFluidAudioModelDownloaded` copied verbatim) → one `ModelDownloadCoordinator`.
- **Single model catalog:** `SettingsDownloadableModels` (529-553), `OnboardingUnifiedModels` (1458-1500), `SettingsFluidAudioModels` (1427-1442) duplicate the same HF URLs/sizes — collapse to one source of truth.
- **Remove dead code:** `debugMode` setting (Settings.swift:108-112, toggle 1273-1280, AppPreferences:92-93 — never read); write-only `@Published` in TranscriptionService (`transcribedText`/`currentSegment`/`isConverting`/`conversionProgress`/`totalDuration`, lines 9-17, incl. the wasted AVAsset duration load 103-111); `FocusUtils.getFocusedWindowScreen()` (96-135, zero callers); `ClipboardUtil.insertTextUsingPasteboard` (183-186); grammar wrappers `WhisperGrammarElement`/`WhisperGrammarElementType`; commented abort block Whis.swift:522-526; duplicate `printRealtime`/`print_realtime` in WhisperFullParams (keep one; toC assigns twice, lines 78/85).
- **`Whis.swift:570-587` (`mapWhisperFullParams`) `free()`s static whisper.cpp strings** — UB landmine. Currently unused; either delete the function or remove the frees before it's ever wired.
- **Deprecated APIs:** `AVAsset(url:)` → `AVURLAsset(url:)` (TranscriptionService:104, TranscriptionQueue:102); `NSApplication.activate(ignoringOtherApps:)` → `activate()` (OpenSuperWhisperApp:323).
- **Translate/remove Russian debug strings** in FocusUtils.swift (lines 34,39,52,63,65,105,117,124).
- **Split Settings.swift (1704 lines)** into: the `Settings` value struct (it's transcription config, not UI), model-catalog structs, `SettingsViewModel`, and `SettingsView`+rows.
- **Replace magic `1651275109`** with `kAudioDeviceTransportTypeBluetooth` (MicrophoneService.swift:192,210).
- **Add SHA-256 verification** for downloaded GGML models (WhisperModelManager.downloadModel:170-173) — defense-in-depth before native parsing.
- **`AutocorrectWrapper` has no availability guard** before `format()` (WhisperEngine:204, FluidAudioEngine:89) — call `isAvailable()` or wrap to degrade gracefully if the dylib is missing.
- **Restore system default input device** on stop/cancel: `startRecording()` permanently switches the macOS default input (AudioRecorder.swift:131) and never restores it — capture the prior default and restore.

---

## 6. Suggested commit sequence

Work on a branch off `master` (e.g. `rebrand-and-refine`); land as a clean series so each commit builds.

1. **`fix(privacy): redact transcript logging`** — §3 #1. Smallest, highest-severity, no rename dependency. Ship first.
2. **`chore(rebrand): in-place identifiers + UI strings`** — Phase A (steps 1–8) + B (step 9). Bundle id, team id, keychain/logger, UI strings, GitHub link, LICENSE, README, struct rename. Build stays green; no file moves. *(Risky bits: team id, keychain service — verify signing + that LLM key re-entry works.)*
3. **`chore(rebrand): rename dirs, project, targets, scheme, tests`** — Phase C (steps 10–16) as ONE atomic commit. Use `git mv`. Rebuild + run tests before committing.
4. **`chore(rebrand): update build/release scripts and artifacts`** — Phase D (steps 17–20).
5. **`fix(transcription): cancellation + shared-engine races`** — §3 #2, #3, #7, #8.
6. **`fix(audio): main-actor AudioRecorder + duration read`** — §3 #4, #12.
7. **`fix(security): trim entitlements, LLM host allowlist, ATS scope`** — §3 #10, #11, #13.
8. **`fix: misc correctness`** — §3 #9, #14, #15, #16, #17.
9. **`build(deps): bump GRDB/KeyboardShortcuts, delete stale Package.resolved`** — §4 #1–#3.
10. **`build(deps): bump FluidAudio to 0.15.4, remove Swift-5 patch`** — §4 #4 (source-breaking `await` audit; isolate so it's revertable).
11. **`build: pin submodules + CI runner, align deployment target`** — §4 #5–#7.
12. **`refactor: extract RecordingSession + ModelDownloadCoordinator + model catalog`** — §5 dedup.
13. **`chore: remove dead code + deprecated APIs + split Settings.swift`** — §5 cleanup.
14. **`chore(swift6): enable strict concurrency targeted` then `flip SWIFT_VERSION=6.0`** — §3 #5/#6, last, after the race fixes land. Two commits if you want the warning pass separate from the flip.

**Risk flags:** commits 3 (project/target rename — most likely to break project open), 4 (release scripts can push real GitHub releases with a token), 10 (FluidAudio actor migration), and 14 (Swift 6 flip) are the ones to validate hardest. Everything before commit 3 keeps the build green without moving any files.

Key files referenced: `/Users/vkmtx/orca/WhisperForge/OpenSuperWhisper.xcodeproj/project.pbxproj`, `/Users/vkmtx/orca/WhisperForge/run.sh`, `/Users/vkmtx/orca/WhisperForge/notarize_app.sh`, `/Users/vkmtx/orca/WhisperForge/make_release.sh`, `/Users/vkmtx/orca/WhisperForge/OpenSuperWhisper/TranscriptionService.swift`, `/Users/vkmtx/orca/WhisperForge/OpenSuperWhisper/AudioRecorder.swift`, `/Users/vkmtx/orca/WhisperForge/OpenSuperWhisper/Indicator/IndicatorWindow.swift`, `/Users/vkmtx/orca/WhisperForge/OpenSuperWhisper/Engines/FluidAudioEngine.swift`, `/Users/vkmtx/orca/WhisperForge/OpenSuperWhisper/OpenSuperWhisper.entitlements`, `/Users/vkmtx/orca/WhisperForge/Package.resolved` (delete), `/Users/vkmtx/orca/WhisperForge/Scripts/patch_fluidaudio.py` (delete after FluidAudio bump).