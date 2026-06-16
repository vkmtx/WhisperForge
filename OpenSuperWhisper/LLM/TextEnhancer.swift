import Foundation
import os

/// Orchestrates the optional LLM post-processing stage: turns a raw transcript into
/// rewritten/translated text before it is pasted. Reads configuration from
/// `AppPreferences` directly (mirroring how `applyPostProcessing` works) so callers
/// only pass a String in and get a String back.
///
/// `enhance` never throws: on any failure it returns the original text so a
/// transcription is never lost to a network/model error.
final class TextEnhancer: Sendable {
    static let shared = TextEnhancer()

    private let logger = Logger(subsystem: "com.opensuperwhisper", category: "TextEnhancer")

    private init() {}

    /// The provider currently selected in preferences.
    private var provider: LLMProvider {
        LLMProvider(rawValue: AppPreferences.shared.llmProvider) ?? .ollama
    }

    private func resolvedBaseURL(_ provider: LLMProvider) -> String {
        let value = AppPreferences.shared.llmBaseURL.trimmingCharacters(in: .whitespaces)
        return value.isEmpty ? provider.defaultBaseURL : value
    }

    private func resolvedModel(_ provider: LLMProvider) -> String {
        let value = AppPreferences.shared.llmModel.trimmingCharacters(in: .whitespaces)
        return value.isEmpty ? provider.defaultModel : value
    }

    private func resolvedSystemPrompt() -> String {
        let value = AppPreferences.shared.llmSystemPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? PromptPreset.defaultPrompt : value
    }

    /// Whether enhancement is enabled and minimally configured to run.
    var isEnabled: Bool {
        guard AppPreferences.shared.llmEnhanceEnabled else { return false }
        let provider = self.provider
        return !resolvedBaseURL(provider).isEmpty && !resolvedModel(provider).isEmpty
    }

    /// Enhances `text` via the configured LLM. Returns the original text unchanged
    /// when disabled, when the input is blank, or when the call fails — a
    /// transcription is never lost to a network/model error.
    func enhance(_ text: String) async -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isEnabled, !trimmed.isEmpty else { return text }

        let provider = self.provider
        let baseURL = resolvedBaseURL(provider)

        // Only allow http/https — never file://, gopher://, etc. from a stray pref.
        guard let parsed = URL(string: baseURL),
              let scheme = parsed.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            logger.error("LLM base URL must use http or https; using raw transcript")
            return text
        }

        let config = LLMConfig(
            baseURL: baseURL,
            model: resolvedModel(provider),
            apiKey: provider.requiresAPIKey ? KeychainHelper.get(account: provider.rawValue) : nil,
            temperature: AppPreferences.shared.llmTemperature,
            timeout: AppPreferences.shared.llmTimeout
        )
        let system = resolvedSystemPrompt()
        let client = provider.makeClient()

        do {
            // Hard wall-clock bound: even if URLSession fails to honor its own
            // timeout, the request loses the race and we fall back to raw text.
            return try await withThrowingTaskGroup(of: String.self) { group -> String in
                group.addTask {
                    try await client.complete(system: system, user: trimmed, config: config)
                }
                group.addTask {
                    let grace = (config.timeout + 5) * 1_000_000_000
                    try await Task.sleep(nanoseconds: UInt64(grace))
                    throw LLMError.transport("client timed out after \(Int(config.timeout))s")
                }
                guard let first = try await group.next() else {
                    throw LLMError.emptyResponse
                }
                group.cancelAll()
                return first
            }
        } catch {
            logger.error("LLM enhance failed, using raw transcript: \(error.localizedDescription, privacy: .private)")
            return text
        }
    }
}
