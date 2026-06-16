# LLM Post-Processing — Code Review & Analysis

**Date:** 2026-06-16
**Branch:** `feature/llm-enhancer` → `master`
**Scope:** the LLM text-enhancement feature (speak Portuguese → polished technical English before paste) and the files it touches.

## Method

- **Build reproducibility:** full from-clean build (`rm -rf build SourcePackages libwhisper/build asian-autocorrect/target` → `./run.sh build`).
- **Bug review:** 5 independent review passes (concurrency, LLM/network, security, UI/Settings, robustness), each finding adversarially re-verified by a second pass. 16 findings confirmed, then triaged by hand against the actual code.

## Verification status

| Check | Result |
|---|---|
| Clean from-scratch build (`./run.sh build`) | ✅ `Building successful!` after fixing the patcher bug below |
| Release build | ✅ self-contained, installed to `/Applications` |
| Functional PT→EN (live Ollama, OpenAI-compatible path) | ✅ verified earlier |
| Installed app independent of `build/` | ✅ verified (no load-command/dylib refs to build dir) |

## Issues fixed

| # | Severity | File | Issue | Fix |
|---|---|---|---|---|
| B1 | High | `Scripts/patch_fluidaudio.py` | SPM marks the resolved `FluidAudio/Package.swift` **read-only**, so the Swift-5-mode patch failed with `Permission denied` on a fresh checkout — `./run.sh build` would break for anyone cloning fresh. | `chmod +w` the file before writing. Re-tested against the read-only file. |
| B2 | High | `Settings.swift` (llmProvider didSet) | Switching provider kept the **previous** provider's Base URL / Model, so e.g. an OpenAI URL leaked into an Ollama session. | On provider change, clear `llmBaseURL`/`llmModel` → the new provider's defaults apply (empty → default). |
| B3 | High | `Settings.swift` (advanced/shortcut tabs) | The window height cap (560) was added for all tabs, but only the Transcription tab scrolled — other tabs could clip if their content grew. | Wrapped `advancedSettings` and `shortcutSettings` in `ScrollView` (they fit today; this future-proofs). `modelSettings` already has internal scroll and fits. |
| B4 | Medium | `LLM/KeychainHelper.swift` | `SecItemAdd` status was ignored — a failed key write would be silent. | Check `OSStatus`; log a warning on failure (account name only, never the key). |
| B5 | Medium | `LLM/AnthropicClient.swift` | `max_tokens` of 2048 could truncate long rewrites. | Raised to 4096 (a cap, not a target — no cost). |
| B6 | Low | `Indicator/IndicatorWindow.swift` | The error-path `Task` (record-url-not-found) captured `self` strongly, unlike the main path. | Added `[weak self]` for symmetry. |

## Findings reviewed and **not** changed (with reasoning)

**False positives / already handled:**
- *"Anthropic API version 2023-06-01 is obsolete"* — Incorrect. `2023-06-01` is the current, stable `anthropic-version` request header (unrelated to model release dates). No change.
- *"OpenAI client crashes on null `content`"* — Not a crash. `message["content"] as? String` returns `nil` on JSON null → the `guard` throws `emptyResponse` → `TextEnhancer` catches it and returns the raw transcript. Graceful by design.
- *"API key logged in plaintext"* — Incorrect. The `print` at `IndicatorWindow.swift` logs the **transcription text**, not the API key (the key only ever sits in a request header). Logging transcription content to the debug console is a pre-existing, app-wide pattern, not introduced by this feature.
- *"Anthropic silently drops non-text blocks"* — Correct behavior for this use case (no tools/images are sent, so only text blocks are expected).

**Pre-existing (in the upstream app, not introduced by this feature) — documented, not fixed to keep scope tight:**
- The transcription `Task` in `startDecoding` is unstructured and not stored/cancellable. Mitigated by the existing `isTranscriptionBusy` guard, which blocks a second decode from starting. Hardening it (store + cancel) would be a worthwhile upstream change.
- Recording filenames use second-level timestamp precision (`Int(timeIntervalSince1970).wav`), so two recordings in the same second could collide. Pre-existing; rare in practice.
- `cleanup()`/`cancelRecording()` are not wired to a SwiftUI `.onDisappear`, so state can persist if the window is torn down mid-flight.

**By design:**
- History stores the **raw** transcript while the **enhanced** text is what gets pasted. This is intentional: history stays a faithful record of what was said; the polished version is for the destination app. Documented in `IndicatorWindow.swift`.

## Storage / disk accumulation

**Investigated on request.** Every live dictation previously saved an uncompressed
`.wav` to `~/Library/Application Support/<bundle-id>/recordings/` with no retention.

| Fact | Value |
|---|---|
| Format | WAV, 32-bit float, 512 kbit/s ≈ **3.8 MB/min** |
| Existing cleanup | **None.** `cleanupMissingFiles` only drops orphaned DB rows; `deleteRecording`/`deleteAllRecordings` are manual. |
| Projection (heavy use) | ≈ 1.4 GB/month, ≈ 17 GB/year |

**Resolved:** added a `Save dictation history` setting (default **off**). When off,
the dictation audio is deleted the moment it has been transcribed/pasted — nothing is
persisted, so audio cannot accumulate. When on, the previous save-to-history behavior
applies. A periodic timer-based sweep was considered and verified harmless (a 5-minute
`Timer` + small DB query is negligible on CPU/memory), but immediate deletion is
strictly better: zero accumulation window and no background timer. (`AppPreferences.saveDictationHistory`, `IndicatorWindow.startDecoding`.)

Note: the drag-and-drop / file-queue path still persists recordings, since those are
user-initiated file imports rather than continuous dictation.

## Notes on robustness already in place

- `TextEnhancer.enhance` never throws: any failure (network down, bad URL scheme, timeout, empty response) falls back to the raw transcript, so a transcription is never lost.
- A structured `withThrowingTaskGroup` timeout bounds the LLM call even if `URLSession` ignores its own timeout.
- The user-supplied Base URL is scheme-validated (`http`/`https` only).
- API keys live in the Keychain (`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`), never in `UserDefaults`. Error logs use `.private`.
