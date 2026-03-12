import Foundation

/// 通过本地 claude CLI 调用 AI，复用系统级 Claude Code 认证
struct AIService {

    /// claude CLI 的模型别名（sonnet 更快更便宜，适合这些轻量任务）
    private static let defaultModel = "sonnet"

    // MARK: - 查找 claude CLI

    private static func findCLI() -> String? {
        let candidates = [
            "/opt/homebrew/bin/claude",
            "/opt/homebrew/Caskroom/miniconda/base/bin/claude",
            "/usr/local/bin/claude",
            NSHomeDirectory() + "/.claude/local/claude",
        ]
        for path in candidates {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }
        // 尝试 which
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["which", "claude"]
        process.environment = ProcessInfo.processInfo.environment
        // 清除嵌套检测
        process.environment?["CLAUDECODE"] = nil
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return path.isEmpty ? nil : path
    }

    /// 检查 claude CLI 是否可用
    static func isAvailable() -> Bool {
        findCLI() != nil
    }

    // MARK: - 调用 claude CLI

    private static func callClaude(system: String, userMessage: String, model: String? = nil) async throws -> String {
        guard let cliPath = findCLI() else {
            throw AIError.cliNotFound
        }

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: cliPath)
                    process.arguments = [
                        "-p",
                        "--output-format", "json",
                        "--model", model ?? defaultModel,
                        "--system-prompt", system,
                        "--no-session-persistence",
                        userMessage,
                    ]

                    // 继承用户环境，但清除嵌套检测标记
                    var env = ProcessInfo.processInfo.environment
                    env["CLAUDECODE"] = nil
                    process.environment = env

                    let stdout = Pipe()
                    let stderr = Pipe()
                    process.standardOutput = stdout
                    process.standardError = stderr

                    try process.run()
                    process.waitUntilExit()

                    let outData = stdout.fileHandleForReading.readDataToEndOfFile()

                    if process.terminationStatus != 0 {
                        let errText = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                        let outText = String(data: outData, encoding: .utf8) ?? ""
                        continuation.resume(throwing: AIError.requestFailed(
                            errText.isEmpty ? outText.prefix(300).description : errText.prefix(300).description
                        ))
                        return
                    }

                    // 解析 JSON 输出: { "result": "..." }
                    guard let json = try? JSONSerialization.jsonObject(with: outData) as? [String: Any],
                          let result = json["result"] as? String
                    else {
                        // 可能是纯文本输出
                        let text = String(data: outData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                        if text.isEmpty {
                            continuation.resume(throwing: AIError.requestFailed("Claude CLI 返回空结果"))
                        } else {
                            continuation.resume(returning: text)
                        }
                        return
                    }

                    continuation.resume(returning: result.trimmingCharacters(in: .whitespacesAndNewlines))
                } catch {
                    continuation.resume(throwing: AIError.requestFailed("启动 Claude CLI 失败：\(error.localizedDescription)"))
                }
            }
        }
    }

    // MARK: - 测试连接

    static func testConnection() async throws -> String {
        let result = try await callClaude(
            system: "回复[连接成功]四个字即可。",
            userMessage: "测试"
        )
        return "连接成功：\(result)"
    }

    // MARK: - 去 AI 味

    static func deAI(content: String) async throws -> String {
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

        return try await callClaude(system: system, userMessage: content)
    }

    // MARK: - 生成摘要

    static func generateSummary(content: String, title: String) async throws -> String {
        let system = """
        你是一位公众号编辑。根据文章内容生成一句简短的摘要，用于微信公众号文章的摘要/描述字段。

        规则：
        1. 一句话概括文章核心内容，吸引读者点击
        2. 控制在 60 字以内
        3. 语言自然，不要用 AI 腔调
        4. 只输出摘要文本，不要任何标点符号以外的额外内容
        """

        let userMsg = "标题：\(title)\n\n文章内容：\n\(String(content.prefix(3000)))"
        return try await callClaude(system: system, userMessage: userMsg)
    }

    // MARK: - 自动提取/优化标题

    static func generateTitle(content: String) async throws -> String {
        let system = """
        你是一位公众号编辑。根据文章内容生成一个吸引人的标题。

        规则：
        1. 简洁有力，控制在 30 字以内
        2. 适合微信公众号的阅读场景
        3. 不要用标题党，但要有吸引力
        4. 只输出标题文本，不要引号或其他额外内容
        """

        let userMsg = "文章内容：\n\(String(content.prefix(3000)))"
        return try await callClaude(system: system, userMessage: userMsg)
    }
}

// MARK: - Errors

enum AIError: LocalizedError {
    case cliNotFound
    case requestFailed(String)

    var errorDescription: String? {
        switch self {
        case .cliNotFound: "未找到 claude CLI，请先安装 Claude Code（npm install -g @anthropic-ai/claude-code）"
        case .requestFailed(let msg): "AI 调用失败：\(msg)"
        }
    }
}
