# WhisperForge — Refinement Roadmap

This is the backlog of improvements identified by a full codebase audit (June 2026,
see [`CODEBASE_AUDIT.md`](CODEBASE_AUDIT.md)). The items below were **deferred** because
they need a working build/runtime to land safely (the audit machine could not compile:
submodules, `cmake`, `libomp`, `rust` were absent). Validate each with `./run.sh build`
before committing.

Items already shipped on the `rebrand-and-refine` branch are listed at the bottom.

---

## High priority — concurrency & correctness (validate with a build)

These are latent today because the app target builds in **Swift 5 language mode**
(`SWIFT_VERSION = 5.0`), so the compiler's data-race checking is off. They become hard
errors once Swift 6 is enabled, and some can already misbehave at runtime.

- **Serialize the shared transcription engine.** A single `currentEngine`
  (`TranscriptionService.swift:16`) is used by both the live-dictation flow
  (`Indicator/IndicatorWindow.swift`) and the file queue (`TranscriptionQueue.swift:239`)
  with no mutual exclusion; they stomp each other's `abortFlag`/`onProgressUpdate`/`progress`.
  Add a single in-flight gate (or make engines actors); scope `onProgressUpdate` per call
  and clear it on completion.
- **Make `AudioRecorder` `@MainActor`.** `startRecording()` is called from
  `Task.detached` (`IndicatorWindow.swift`, `ContentView.swift:173`) while it mutates
  `@Published` state and races main-thread `stopRecording()`. Push only the blocking device
  I/O into a `nonisolated async` helper; dispatch delegate `@Published` mutations to main.
- **Engines should be `Sendable`/`actor`.** `TranscriptionEngine` is `: AnyObject` only;
  `WhisperEngine`/`FluidAudioEngine` are non-Sendable and mutated cross-actor without locks
  (`onProgressUpdate`, `progressContext`). Convert to `actor` or lock all mutable state.
- **`FluidAudioEngine.cancelTranscription()` is a no-op** — `transcriptionTask` is never
  assigned (`Engines/FluidAudioEngine.swift:11,77,97`). Wrap the transcribe call in the
  task and check `Task.isCancelled`, or drop the dead field.
- **`loadEngine()` has no in-flight guard** (`TranscriptionService.swift:39`). Rapid
  Settings changes spawn concurrent detached inits; a stale engine can win. Add a load
  generation token; only assign if the completing load is still latest.
- **`WhisperEngine` parallel conversion races** (`Engines/WhisperEngine.swift:312-371`):
  unlocked `hasError`/`totalWritten`, plus index-based placement that can insert silent
  gaps for audio > 10s. Concatenate worker output in order, validate summed length, fall
  back to sequential on mismatch.
- **`AudioRecorder.stopRecording()` duration read races the flush**
  (`AudioRecorder.swift:178-195`): a second `AVAudioPlayer` on the just-stopped file can
  drop valid short recordings. Read duration via `AVURLAsset`/`AVAudioFile`, wait for
  `audioRecorderDidFinishRecording`, and stop `try?`-swallowing the distinction between
  "too short" and "read failed".
- **`RecordingStore` `fatalError` on DB init failure** (`Models/Recording.swift:93`).
  Recover (e.g. recreate the store / surface an error) instead of crashing.
- **Then enable Swift 6.** Stage `SWIFT_STRICT_CONCURRENCY = targeted` first to surface
  warnings, fix the above, then flip `SWIFT_VERSION = 6.0`. Independent of the FluidAudio
  package patch.

## Medium priority — security & behavior

- **LLM API-key host allowlist.** The key is sent to a user-editable `llmBaseURL` with no
  host check (`LLM/OpenAICompatibleClient.swift:16`, `LLM/AnthropicClient.swift:21`,
  `LLM/TextEnhancer.swift:56` only checks the scheme). For known cloud providers, attach the
  key only when the resolved host matches the provider's default host; treat a custom base
  URL as no-cloud-key and warn in Settings.
- **Narrow ATS.** `NSAllowsLocalNetworking = true` relaxes ATS for the whole LAN
  (`WhisperForge-Info.plist`). Replace with `NSExceptionDomains` scoped to
  `localhost`/`127.0.0.1`, and allow `http://` only for loopback hosts in `TextEnhancer`.
  ⚠️ This breaks pointing the app at an LLM on another LAN machine — confirm the intended
  use before narrowing.

## Dependencies & tooling

- **Bump within existing constraints** (re-resolve + commit the workspace `Package.resolved`):
  GRDB `7.5.0 → 7.11.1`, KeyboardShortcuts `3.0.0 → 3.0.1`.
- **FluidAudio `0.11.0 → 0.15.4` and delete the Swift-5 patch** (highest-value tooling win):
  removes `Scripts/patch_fluidaudio.py` and the patch block in `run.sh`. **Source-breaking** —
  `AsrManager` became an `actor` in 0.12.6; audit `Engines/FluidAudioEngine.swift` call sites
  and add `await`. The pbxproj constraint already permits it (`upToNextMajor 0.7.9`).
- **Release scripts miss the FluidAudio patch step.** Until the bump above lands,
  `notarize_app.sh` / `make_release.sh` must run `patch_fluidaudio.py` (+ `-resolvePackageDependencies`)
  like `run.sh` does, or a clean Release build fails while CI stays green.
- **Pin submodules + add bootstrap.** `asian-autocorrect` and `libwhisper/whisper.cpp` track
  default branches (`.gitmodules`); only CI checks them out. Add `git submodule update --init
  --recursive` to a `bootstrap.sh`/`run.sh` and pin to known-good commits for reproducibility.
- **CI determinism** (`.github/workflows/build.yml`): pin `runs-on: macos-15` (not
  `macos-latest`) and pin Xcode via `maxim-lobanov/setup-xcode`.
- **Align deployment target.** App configs say `14.0`, project-level + tests say `15.1`,
  CMake + README say `14.0`. Pick one floor and make pbxproj + CMake + README + cask agree.

## Refactor & cleanup

- **Unify the two record/decode pipelines** (`ContentViewModel` in `ContentView.swift` vs
  `IndicatorViewModel` in `IndicatorWindow.swift`) into a shared `RecordingSession`. Note the
  main-window path currently skips LLM/paste and ignores `saveDictationHistory` — unifying
  fixes that divergence too.
- **Unify model-download boilerplate** (`SettingsViewModel` vs `OnboardingViewModel`;
  `isFluidAudioModelDownloaded` is copied verbatim) into one `ModelDownloadCoordinator`.
- **Single model catalog.** `SettingsDownloadableModels`, `OnboardingUnifiedModels`, and
  `SettingsFluidAudioModels` duplicate the same Hugging Face URLs/sizes.
- **Split `Settings.swift` (~1700 lines)** into the `Settings` value struct (it is
  transcription config, not UI), the model-catalog structs, `SettingsViewModel`, and the views.
- **Remove remaining dead code:** the app-level `debugMode` toggle (`Settings.swift:108-112`,
  `:1276`, `AppPreferences.swift:92` — never read; distinct from the live whisper.cpp
  `debug_mode`), write-only `@Published` in `TranscriptionService` (`transcribedText`,
  `currentSegment`, `isConverting`, `conversionProgress`, `totalDuration`), grammar wrappers
  (`WhisperGrammarElement*`), the commented abort block (`Whis/Whis.swift:522`), and the
  duplicate `printRealtime` assignment in `WhisperFullParams`.
- **`Whis.swift mapWhisperFullParams` `free()`s static whisper.cpp strings** (~`:570`) — UB
  landmine. Currently unused; delete the function or remove the frees before it is wired.
- **Restore the system default input device** on stop/cancel — `startRecording()`
  permanently switches the macOS default input (`AudioRecorder.swift:131`) and never restores it.
- **Verify downloaded GGML models** (SHA-256) before native parsing
  (`WhisperModelManager.downloadModel`).
- **Guard `AutocorrectWrapper.format()`** with `isAvailable()` so a missing dylib degrades
  gracefully (`WhisperEngine.swift:204`, `FluidAudioEngine.swift:89`).
- **Status-bar click handler** re-invokes `performClick` on itself
  (`WhisperForgeApp.swift`) while a menu is already attached — redundant/confusing fork
  remnant; drop the custom action.

## Out of scope (by request)

- **DMG "unidentified developer" / notarization.** Fixing this requires notarizing under
  *your* paid Apple Developer ID. `notarize_app.sh` now has `<YOUR_TEAM_ID>` and
  `<YOUR_NOTARY_PROFILE>` placeholders and the project's `DEVELOPMENT_TEAM` is cleared — fill
  these in when you decide to ship a signed build. Until then, local builds are unsigned
  (`run.sh` uses ad-hoc signing).

---

## Shipped on `rebrand-and-refine`

- Full rebrand OpenSuperWhisper → WhisperForge (dirs, `.xcodeproj`, 3 targets, scheme,
  struct, tests, bundle id `com.vitorsolen.WhisperForge`, keychain service, Logger subsystems,
  scripts, Homebrew cask, LICENSE attribution, README). Cleared upstream Apple Team.
- Privacy: stopped logging transcripts; 74 `print()` routed through a Release-stripped
  `Log.debug`; ship-time errors via `os.Logger`.
- Correctness: cancellation race, download-progress divide-by-zero guard, `bundleIdentifier!`
  crashes, deprecated `AVAsset`/`activate`, Bluetooth transport-type magic number.
- Security: trimmed entitlements to what is used (dropped unused apple-events + legacy
  temporary-exception keys).
- De-noise: translated Russian debug strings; removed dead `getFocusedWindowScreen` and
  `insertTextUsingPasteboard`; deleted the stale root `Package.resolved`; fixed the `run.sh`
  derived-data path case and the README `cd` typo.
