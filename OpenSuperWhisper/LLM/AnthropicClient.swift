import Foundation

/// Talks to the Anthropic Messages API (`/messages`), which is NOT OpenAI-compatible:
/// the system prompt is a top-level field, auth uses `x-api-key`, and the response
/// shape is `content[0].text`.
struct AnthropicClient: LLMClient {
    static let apiVersion = "2023-06-01"
    static let maxTokens = 2048

    func complete(system: String, user: String, config: LLMConfig) async throws -> String {
        guard !config.model.isEmpty else { throw LLMError.emptyModel }
        guard let url = URL(string: config.endpoint("/messages")) else {
            throw LLMError.invalidBaseURL(config.baseURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = config.timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Self.apiVersion, forHTTPHeaderField: "anthropic-version")
        if let key = config.apiKey, !key.isEmpty {
            request.setValue(key, forHTTPHeaderField: "x-api-key")
        }

        let body: [String: Any] = [
            "model": config.model,
            "max_tokens": Self.maxTokens,
            "temperature": config.temperature,
            "system": system,
            "messages": [["role": "user", "content": user]],
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw LLMError.transport(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw LLMError.transport("No HTTP response")
        }
        guard (200..<300).contains(http.statusCode) else {
            let bodyText = String(data: data, encoding: .utf8) ?? ""
            throw LLMError.requestFailed(status: http.statusCode, body: String(bodyText.prefix(500)))
        }

        return try Self.parseContent(from: data)
    }

    /// Extracts the first text block from an Anthropic `content` array.
    static func parseContent(from data: Data) throws -> String {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]] else {
            throw LLMError.emptyResponse
        }
        let text = content
            .compactMap { $0["text"] as? String }
            .joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw LLMError.emptyResponse }
        return text
    }
}
