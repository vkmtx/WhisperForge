import Foundation

/// Known LLM providers with sensible default endpoints and models.
/// Stored in preferences as `rawValue` (a plain String) for plist compatibility.
enum LLMProvider: String, CaseIterable, Identifiable, Sendable {
    case ollama      // local
    case lmstudio    // local
    case openai
    case openrouter
    case groq
    case anthropic
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .ollama: return "Ollama (local)"
        case .lmstudio: return "LM Studio (local)"
        case .openai: return "OpenAI"
        case .openrouter: return "OpenRouter"
        case .groq: return "Groq"
        case .anthropic: return "Anthropic"
        case .custom: return "Custom (OpenAI-compatible)"
        }
    }

    var defaultBaseURL: String {
        switch self {
        case .ollama: return "http://localhost:11434/v1"
        case .lmstudio: return "http://localhost:1234/v1"
        case .openai: return "https://api.openai.com/v1"
        case .openrouter: return "https://openrouter.ai/api/v1"
        case .groq: return "https://api.groq.com/openai/v1"
        case .anthropic: return "https://api.anthropic.com/v1"
        case .custom: return ""
        }
    }

    var defaultModel: String {
        switch self {
        case .ollama: return "qwen2.5:3b-instruct"
        case .lmstudio: return ""
        case .openai: return "gpt-4o-mini"
        case .openrouter: return "anthropic/claude-3.5-haiku"
        case .groq: return "llama-3.3-70b-versatile"
        case .anthropic: return "claude-3-5-haiku-latest"
        case .custom: return ""
        }
    }

    var requiresAPIKey: Bool {
        switch self {
        case .ollama, .lmstudio, .custom: return false
        default: return true
        }
    }

    var isLocal: Bool {
        switch self {
        case .ollama, .lmstudio: return true
        default: return false
        }
    }

    /// Picks the wire-protocol client for this provider.
    func makeClient() -> any LLMClient {
        switch self {
        case .anthropic: return AnthropicClient()
        default: return OpenAICompatibleClient()
        }
    }
}
