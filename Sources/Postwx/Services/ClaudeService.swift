import Foundation

/// 调用 Claude API（Anthropic 或兼容服务）
struct ClaudeService {

    private static let defaultApiBase = "https://api.anthropic.com"
    private static let defaultModel = "claude-sonnet-4-20250514"

    // MARK: - 凭证管理

    struct Config {
        var apiBase: String
        var apiKey: String
        var model: String

        var resolvedBase: String {
            let base = apiBase.isEmpty ? defaultApiBase : apiBase
            var url = base.hasSuffix("/") ? String(base.dropLast()) : base
            if !url.hasSuffix("/v1") {
                url += "/v1"
            }
            return url
        }

        var resolvedModel: String {
            model.isEmpty ? defaultModel : model
        }
    }

    /// 从 AppState 获取配置
    static func config(from state: AppState) -> Config {
        Config(
            apiBase: state.claudeApiBase,
            apiKey: state.claudeApiKey,
            model: state.claudeModel
        )
    }

    /// 检查是否有可用凭证
    static func isAvailable(state: AppState) -> Bool {
        !state.claudeApiKey.isEmpty
    }

    // MARK: - 调用 Claude API

    private static func callClaude(config: Config, system: String, userMessage: String) async throws -> String {
        guard !config.apiKey.isEmpty else {
            throw ClaudeError.noCredentials
        }

        let urlStr = "\(config.resolvedBase)/messages"
        guard let url = URL(string: urlStr) else {
            throw ClaudeError.requestFailed("无效的 API URL: \(urlStr)")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue(config.apiKey, forHTTPHeaderField: "x-api-key")

        let body: [String: Any] = [
            "model": config.resolvedModel,
            "max_tokens": 4096,
            "system": system,
            "messages": [
                ["role": "user", "content": userMessage],
            ],
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClaudeError.requestFailed("无效的响应")
        }

        if httpResponse.statusCode != 200 {
            throw ClaudeError.requestFailed(friendlyError(httpResponse.statusCode, data: data))
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let first = content.first,
              let text = first["text"] as? String
        else {
            throw ClaudeError.requestFailed("无法解析 Claude 响应")
        }

        return text
    }

    // MARK: - 测试连接

    static func testConnection(apiBase: String, apiKey: String, model: String) async throws -> String {
        let config = Config(apiBase: apiBase, apiKey: apiKey, model: model)
        _ = try await callClaude(
            config: config,
            system: "回复[连接成功]四个字即可。",
            userMessage: "测试"
        )
        return "连接成功（模型: \(config.resolvedModel)）"
    }

    // MARK: - 去 AI 味

    static func deAI(config: Config, content: String) async throws -> String {
        let system = """
        你是一位资深中文编辑。你的任务是将 AI 生成的文章润色为自然、地道的人类写作风格。

        规则：
        1. 去除 AI 写作的典型特征：过度使用"首先/其次/最后"、"值得注意的是"、"总而言之"等套话
        2. 减少不必要的修饰词和冗余表达
        3. 让语言更简洁、直接、有个性
        4. 保持原文的核心信息和结构不变
        5. 保留所有 Markdown 格式标记
        6. 只输出润色后的全文，不要任何解释
        """

        return try await callClaude(config: config, system: system, userMessage: content)
    }

    // MARK: - 生成摘要

    static func generateSummary(config: Config, content: String, title: String) async throws -> String {
        let system = """
        你是一位公众号编辑。根据文章内容生成一句简短的摘要，用于微信公众号文章的摘要/描述字段。

        规则：
        1. 一句话概括文章核心内容，吸引读者点击
        2. 控制在 60 字以内
        3. 语言自然，不要用 AI 腔调
        4. 只输出摘要文本，不要任何标点符号以外的额外内容
        """

        let userMsg = "标题：\(title)\n\n文章内容：\n\(String(content.prefix(3000)))"
        return try await callClaude(config: config, system: system, userMessage: userMsg)
    }

    // MARK: - 自动提取/优化标题

    static func generateTitle(config: Config, content: String) async throws -> String {
        let system = """
        你是一位公众号编辑。根据文章内容生成一个吸引人的标题。

        规则：
        1. 简洁有力，控制在 30 字以内
        2. 适合微信公众号的阅读场景
        3. 不要用标题党，但要有吸引力
        4. 只输出标题文本，不要引号或其他额外内容
        """

        let userMsg = "文章内容：\n\(String(content.prefix(3000)))"
        return try await callClaude(config: config, system: system, userMessage: userMsg)
    }

    // MARK: - 错误映射

    private static func friendlyError(_ statusCode: Int, data: Data) -> String {
        switch statusCode {
        case 401: return "API Key 无效，请检查后重新输入"
        case 403: return "API Key 权限不足"
        case 429: return "请求过于频繁，请稍后再试"
        case 404: return "API 地址不正确，请检查 Base URL"
        case 500...599: return "Claude 服务暂时不可用，请稍后再试"
        default:
            let errText = String(data: data, encoding: .utf8) ?? ""
            return "HTTP \(statusCode): \(errText.prefix(200))"
        }
    }
}

// MARK: - Errors

enum ClaudeError: LocalizedError {
    case noCredentials
    case requestFailed(String)

    var errorDescription: String? {
        switch self {
        case .noCredentials: "未配置 Claude API Key，请在设置中填写"
        case .requestFailed(let msg): "Claude API 错误：\(msg)"
        }
    }
}
