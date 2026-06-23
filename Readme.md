# WhisperForge

Fast, private dictation for macOS — speak in any language and get polished
**technical English** pasted wherever you type.

On-device speech recognition (Parakeet v3 / Whisper) plus an optional LLM pass that
rewrites your rough dictation into sharp, professional English. Local or cloud.

**A free, open-source SuperWhisper alternative for macOS** — no subscription, runs fully
on-device, with an optional AI rewrite that turns rough multilingual speech into clean
technical English. A privacy-friendly alternative to SuperWhisper, Wispr Flow, and
MacWhisper.

> A fork of [OpenSuperWhisper](https://github.com/Starmel/OpenSuperWhisper), adding an
> AI post-processing pipeline.

## Highlights

- 🎙️ Real-time dictation with a global hotkey (hold-to-record)
- 🧠 On-device ASR — **Parakeet v3** (multilingual, ANE-accelerated) or Whisper
- 🤖 **AI post-processing** — rewrite/translate the transcript before pasting (e.g. rough Portuguese → polished technical English)
- ☁️ Pluggable LLM — local (Ollama / LM Studio) or cloud (Groq, OpenAI, OpenRouter, Anthropic) via an OpenAI-compatible base URL
- 🔒 Private by default — API keys in the Keychain; dictation audio is discarded right after transcription (no history pile-up)
- 📋 Auto-paste into the focused app; drag-and-drop file transcription

## How it works

```
speak → on-device ASR transcribes → (optional) LLM rewrites to polished English → pasted
```

History is off by default: the audio is deleted the moment it is transcribed, so nothing
accumulates on disk.

## AI post-processing setup

In **Settings → AI Post-processing**:

1. Toggle **Enhance with AI**.
2. Pick a **Provider** and paste an **API key** (stored in the Keychain, never on disk).
3. Leave **Model**, **Base URL**, and **System Prompt** empty to use sensible defaults.

**Recommended on low-RAM Macs:** cloud **Groq** (free tier) with `openai/gpt-oss-120b`
— near-zero local RAM and no model-load spike. A local LLM can exhaust a 16 GB Mac during
dictation, so prefer cloud on constrained hardware; the local ASR (Parakeet) stays
on-device and is light.

The built-in system prompt rewrites rough multilingual dictation into sharp,
senior-engineer technical English — adapting the form to the content (commit, message, or
spec) and dropping phrases the speaker retracts.

## Build from source

Requires Xcode 26+ and Homebrew packages `cmake`, `libomp`, `rust`.

```bash
git clone <this-repo-url>
cd WhisperForge
git submodule update --init --recursive
brew install cmake libomp rust
./run.sh build        # builds the app; `./run.sh` (no arg) also launches it
```

`run.sh` builds the whisper.cpp and Rust autocorrect dependencies, then the app. It also
applies an idempotent patch so the pinned FluidAudio (0.11.0) compiles under Xcode 26 /
Swift 6 (see `Scripts/patch_fluidaudio.py`).

## Requirements

- macOS 14+ (Apple Silicon / ARM64)

## Documentation

- [`docs/LLM_FEATURE_REVIEW.md`](docs/LLM_FEATURE_REVIEW.md) — design, code review, and
  rationale for the AI post-processing pipeline.

## Credits

This fork (**WhisperForge**) is built and maintained by [@vkmtx](https://github.com/vkmtx).

Built on [OpenSuperWhisper](https://github.com/Starmel/OpenSuperWhisper) by Starmel.
Speech models via [whisper.cpp](https://github.com/ggerganov/whisper.cpp) and
[FluidAudio](https://github.com/FluidInference/FluidAudio). Asian autocorrect via
[autocorrect](https://github.com/huacnlee/autocorrect).

## License

MIT — inherited from the upstream project. See [LICENSE](LICENSE).

---

<sub>**Keywords:** macOS dictation · voice to text · speech to text · open-source SuperWhisper alternative · free SuperWhisper alternative · Wispr Flow alternative · MacWhisper alternative · local Whisper dictation · Parakeet · on-device transcription · AI dictation · privacy-first speech-to-text for Mac.</sub>
