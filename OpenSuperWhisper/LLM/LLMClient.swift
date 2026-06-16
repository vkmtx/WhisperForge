import Foundation

/// Configuration for a single LLM completion request.
struct LLMConfig: Sendable {
    let baseURL: String      // e.g. "http://localhost:11434/v1" or "https://api.openai.com/v1"
    let model: String        // e.g. "qwen2.5:3b-instruct" or "gpt-4o-mini"
    let apiKey: String?      // nil for local providers that need no key
    let temperature: Double
    let timeout: TimeInterval

    /// Joins the configured base URL with an API path, tolerating a trailing slash.
    func endpoint(_ path: String) -> String {
        let base = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        return base + path
    }
}

enum LLMError: LocalizedError, Sendable {
    case invalidBaseURL(String)
    case emptyModel
    case requestFailed(status: Int, body: String)
    case emptyResponse
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL(let url): return "Invalid LLM base URL: \(url)"
        case .emptyModel: return "No LLM model configured"
        case .requestFailed(let status, let body): return "LLM request failed (HTTP \(status)): \(body)"
        case .emptyResponse: return "LLM returned an empty response"
        case .transport(let message): return "LLM transport error: \(message)"
        }
    }
}

/// A provider-agnostic chat completion client. Implementations talk to a specific
/// wire protocol (OpenAI-compatible, Anthropic, ...) but expose the same surface.
protocol LLMClient: Sendable {
    func complete(system: String, user: String, config: LLMConfig) async throws -> String
}
