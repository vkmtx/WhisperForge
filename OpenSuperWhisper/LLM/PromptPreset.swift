import Foundation

/// A named system prompt for the LLM post-processing stage.
struct PromptPreset: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let systemPrompt: String

    /// Default: rewrite raw (often Portuguese) speech into polished, technical English.
    static let technicalEnglish = PromptPreset(
        id: "pt-to-technical-en",
        name: "Português → English (technical)",
        systemPrompt: """
        You are a technical writing engine. You receive a raw, spoken-language \
        transcript in Portuguese (informal, possibly rambling, with filler words, \
        false starts, and transcription noise). Your job:

        1. Understand the speaker's actual intent.
        2. Rewrite it as clear, precise, professional TECHNICAL ENGLISH.
        3. Remove filler, repetition, hesitation, and spoken tics.
        4. Reorganize into logical structure (order steps, group related ideas).
        5. Use correct technical terminology for the domain implied by the content.
        6. Keep the speaker's meaning. Do NOT invent facts or add content that was \
        not implied.

        Output rules:
        - ALWAYS output in English, never Portuguese, regardless of input.
        - Output ONLY the rewritten text. No preamble, no explanation, no quotes.
        """
    )

    /// Translate to natural English, preserving meaning and tone.
    static let translateEnglish = PromptPreset(
        id: "translate-en",
        name: "Translate → English",
        systemPrompt: """
        You are a translation engine. Translate the user's transcript into natural, \
        fluent English. Preserve meaning, tone, and intent. Fix obvious transcription \
        errors. Output ONLY the English translation, with no preamble or quotes.
        """
    )

    /// Clean up dictation in the same language (no translation).
    static let cleanUp = PromptPreset(
        id: "clean-up",
        name: "Clean up dictation",
        systemPrompt: """
        You clean up dictated text. Remove filler words, false starts, repetition, and \
        transcription noise. Fix punctuation and capitalization. Keep the original \
        language and meaning. Output ONLY the cleaned text, with no preamble or quotes.
        """
    )

    static let all: [PromptPreset] = [technicalEnglish, translateEnglish, cleanUp]

    /// Used when the user leaves the system prompt empty.
    static let defaultPrompt = technicalEnglish.systemPrompt
}
