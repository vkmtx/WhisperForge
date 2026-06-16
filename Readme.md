# OpenSuperWhisper

OpenSuperWhisper is a macOS application that provides real-time audio transcription using the Whisper model. It offers a seamless way to record and transcribe audio with customizable settings and keyboard shortcuts.

<p align="center">
<img src="docs/image.png" width="400" /> <img src="docs/image_indicator.png" width="400" />
</p>

## Features

- 🎙️ Real-time audio recording and transcription
- 🧠 Two transcription engines: [Whisper](https://github.com/ggerganov/whisper.cpp) and [Parakeet](https://github.com/AntinomyCollective/FluidAudio) — download models directly from the app
- ⌨️ Global keyboard shortcuts — key combination or single modifier key (e.g. Left ⌘, Right ⌥, Fn)
- ✊ Hold-to-record mode — hold the shortcut to record, release to stop
- 📁 Drag & drop audio files for transcription with queue processing
- 🎤 Microphone selection — switch between built-in, external, Bluetooth and iPhone (Apple Continuity) mics from the menu bar
- 🌍 Support for multiple languages with auto-detection
- 🇯🇵🇨🇳🇰🇷 Asian language autocorrect ([autocorrect](https://github.com/huacnlee/autocorrect))
- 🤖 **AI post-processing (fork)** — rewrite/translate the transcript with an LLM before pasting (speak Portuguese → polished technical English)

## Fork: AI Post-Processing (speak PT → sharp technical English)

This fork adds an optional LLM stage: after transcription, the raw (often Portuguese)
speech is rewritten/translated into sharp technical English and pasted. Configure in
**Settings → AI Post-processing**.

- **Provider:** pluggable, OpenAI-compatible — local (Ollama, LM Studio) or cloud
  (Groq, OpenAI, OpenRouter, Anthropic) via a base-URL toggle. API keys live in the Keychain.
- **Recommended on low-RAM Macs:** cloud **Groq** (free tier) with `openai/gpt-oss-120b`
  — near-zero local RAM, no model-load spike. A local LLM (Ollama) can exhaust 16 GB and
  freeze the machine, so prefer cloud on constrained hardware.
- **Default ASR engine:** Parakeet v3 (multilingual, on-device, fast).
- **Prompt:** a senior-engineer system prompt tuned empirically (form-adaptation +
  retraction handling). Leave the Settings prompt field empty to use the built-in default.
- **History:** off by default — dictation audio is deleted right after transcription so it
  never accumulates on disk. Toggle in Settings.

See [`docs/LLM_FEATURE_REVIEW.md`](docs/LLM_FEATURE_REVIEW.md) for the full design, review,
and rationale.

> **Build note:** `./run.sh build` patches the pinned FluidAudio (0.11.0) to Swift 5
> language mode — its streaming code fails to compile under Xcode 26 / Swift 6. The patch
> is idempotent (`Scripts/patch_fluidaudio.py`).

## Installation

```shell
brew update # Optional
brew install opensuperwhisper
```

Or from [GitHub releases page](https://github.com/Starmel/OpenSuperWhisper/releases).

## Requirements

- macOS (Apple Silicon/ARM64)

## Support

If you encounter any issues or have questions, please:
1. Check the existing issues in the repository
2. Create a new issue with detailed information about your problem
3. Include system information and logs when reporting bugs

## Building locally

To build locally, you'll need:

    git clone git@github.com:Starmel/OpenSuperWhisper.git
    cd OpenSuperWhisper
    git submodule update --init --recursive
    brew install cmake libomp rust ruby
    gem install xcpretty
    ./run.sh build

In case of problems, consult `.github/workflows/build.yml` which is our CI workflow
where the app gets built automatically on GitHub's CI.

## Contributing

Contributions are welcome! Please feel free to submit pull requests or create issues for bugs and feature requests.

### Contribution TODO list

- [ ] Streaming transcription
- [ ] Custom dictionary / keyword boosting ([#19](https://github.com/Starmel/OpenSuperWhisper/issues/19))
- [ ] Intel macOS compatibility ([#15](https://github.com/Starmel/OpenSuperWhisper/issues/15))
- [ ] Agent mode ([#14](https://github.com/Starmel/OpenSuperWhisper/issues/14))
- [x] Background app ([#8](https://github.com/Starmel/OpenSuperWhisper/issues/8))
- [x] Support long-press single key audio recording ([#18](https://github.com/Starmel/OpenSuperWhisper/issues/18))

## License

OpenSuperWhisper is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

## Whisper Models

You can download Whisper model files (`.bin`) from the [Whisper.cpp Hugging Face repository](https://huggingface.co/ggerganov/whisper.cpp/tree/main). Place the downloaded `.bin` files in the app's models directory. On first launch, the app will attempt to copy a default model automatically, but you can add more models manually.
