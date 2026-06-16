import Foundation

/// Talks to any OpenAI-compatible `/chat/completions` endpoint.
/// Covers Ollama and LM Studio (local), OpenAI, OpenRouter, Groq, Together, etc.
struct OpenAICompatibleClient: LLMClient {
    func complete(system: String, user: String, config: LLMConfig) async throws -> String {
        guard !config.model.isEmpty else { throw LLMError.emptyModel }
        guard let url = URL(string: config.endpoint("/chat/completions")) else {
            throw LLMError.invalidBaseURL(config.baseURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = config.timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let key = config.apiKey, !key.isEmpty {
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        }

        let body: [String: Any] = [
            "model": config.model,
            "temperature": config.temperature,
            "stream": false,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": user],
            ],
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

    /// Extracts `choices[0].message.content` from an OpenAI-style response.
    static func parseContent(from data: Data) throws -> String {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw LLMError.emptyResponse
        }
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw LLMError.emptyResponse }
        return trimmed
    }
}
