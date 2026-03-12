import Foundation

struct PublishService {
    /// scripts 目录路径
    private static var scriptsDir: String {
        let executableURL = Bundle.main.executableURL ?? URL(fileURLWithPath: ProcessInfo.processInfo.arguments[0])
        // 开发时直接使用项目目录
        let projectDir = findProjectDir(from: executableURL)
        return projectDir + "/scripts"
    }

    /// 向上查找项目根目录（包含 scripts/ 的目录）
    private static func findProjectDir(from url: URL) -> String {
        var dir = url.deletingLastPathComponent()
        for _ in 0..<10 {
            let candidate = dir.appendingPathComponent("scripts/wechat-api.ts")
            if FileManager.default.fileExists(atPath: candidate.path) {
                return dir.path
            }
            dir = dir.deletingLastPathComponent()
        }
        // Fallback: 使用已知路径
        return "/Users/ziheng/Projects/Postwx"
    }

    // MARK: - 保存内容到临时 Markdown 文件

    static func saveTempMarkdown(content: String, title: String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateStr = dateFormatter.string(from: Date())

        let slug = generateSlug(from: title.isEmpty ? String(content.prefix(50)) : title)
        let dir = "/tmp/postwx/\(dateStr)"

        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)

        let filePath = "\(dir)/\(slug).md"

        var md = ""
        if !title.isEmpty {
            md += "# \(title)\n\n"
        }
        md += content

        try? md.write(toFile: filePath, atomically: true, encoding: .utf8)
        return filePath
    }

    // MARK: - 调用现有 TS 脚本发布

    struct Credentials {
        var wechatAppId: String
        var wechatAppSecret: String
        var imageApiBase: String
        var imageApiKey: String
        var imageModel: String
    }

    static func publish(
        filePath: String,
        theme: Theme,
        color: ThemeColor,
        title: String?,
        summary: String?,
        author: String?,
        credentials: Credentials,
        onLog: @escaping @Sendable (String) -> Void
    ) async throws -> String {
        var args = [
            "npx", "-y", "bun",
            "\(scriptsDir)/wechat-api.ts",
            filePath,
            "--theme", theme.rawValue,
            "--color", color.rawValue,
        ]

        if let title, !title.isEmpty { args += ["--title", title] }
        if let summary, !summary.isEmpty { args += ["--summary", summary] }
        if let author, !author.isEmpty { args += ["--author", author] }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = args
        process.currentDirectoryURL = URL(fileURLWithPath: scriptsDir)

        // 只从应用设置传入凭证，不读取 .env 文件
        var env = ProcessInfo.processInfo.environment
        env["WECHAT_APP_ID"] = credentials.wechatAppId
        env["WECHAT_APP_SECRET"] = credentials.wechatAppSecret
        if !credentials.imageApiKey.isEmpty {
            env["IMAGE_API_KEY"] = credentials.imageApiKey
        }
        if !credentials.imageApiBase.isEmpty {
            env["IMAGE_API_BASE"] = normalizeApiBase(credentials.imageApiBase)
        }
        if !credentials.imageModel.isEmpty {
            env["IMAGE_MODEL"] = credentials.imageModel
        }
        process.environment = env

        let pipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = pipe
        process.standardError = errPipe

        try process.run()

        let outputData = pipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errPipe.fileHandleForReading.readDataToEndOfFile()

        process.waitUntilExit()

        let output = String(data: outputData, encoding: .utf8) ?? ""
        let errorOutput = String(data: errorData, encoding: .utf8) ?? ""

        if !output.isEmpty { onLog(output) }
        if !errorOutput.isEmpty { onLog(errorOutput) }

        if process.terminationStatus != 0 {
            throw PublishError.scriptFailed(errorOutput.isEmpty ? output : errorOutput)
        }

        return output
    }

    // MARK: - 测试微信凭证

    static func testWechatCredentials(appId: String, appSecret: String) async throws -> String {
        let urlStr = "https://api.weixin.qq.com/cgi-bin/token?grant_type=client_credential&appid=\(appId)&secret=\(appSecret)"
        guard let url = URL(string: urlStr) else {
            throw TestError.invalidConfig("无效的 App ID 格式")
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw TestError.invalidResponse("无法解析响应")
        }

        if let errcode = json["errcode"] as? Int, errcode != 0 {
            throw TestError.apiFailed(friendlyWechatError(errcode))
        }

        if json["access_token"] is String {
            return "连接成功"
        }

        throw TestError.invalidResponse("响应中无 access_token")
    }

    // MARK: - 测试 AI 配图

    static func testImageGeneration(apiBase: String, apiKey: String, model: String) async throws -> String {
        let base = normalizeApiBase(apiBase.isEmpty ? "https://api.tu-zi.com" : apiBase)

        // 用 /models 接口验证连通性和 API Key，不实际生图，秒级完成
        let urlStr = "\(base)/models"

        guard let url = URL(string: urlStr) else {
            throw TestError.invalidConfig("无效的 API Base URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TestError.invalidResponse("无效的 HTTP 响应")
        }

        if httpResponse.statusCode != 200 {
            throw TestError.apiFailed(friendlyImageError(httpResponse.statusCode))
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw TestError.invalidResponse("无法解析服务端响应")
        }

        if let error = json["error"] as? [String: Any], let message = error["message"] as? String {
            throw TestError.apiFailed(friendlyImageErrorMessage(message))
        }

        // 检查目标模型是否可用
        let modelName = model.isEmpty ? "gpt-image-1" : model
        if let models = json["data"] as? [[String: Any]] {
            let ids = models.compactMap { $0["id"] as? String }
            if ids.contains(modelName) {
                return "连接成功，模型 \(modelName) 可用"
            }
            if !ids.isEmpty {
                return "连接成功（未找到模型 \(modelName)，可用: \(ids.prefix(3).joined(separator: ", "))...）"
            }
        }

        return "连接成功"
    }

    // MARK: - 微信错误码映射

    private static func friendlyWechatError(_ code: Int) -> String {
        switch code {
        case -1: "微信系统繁忙，请稍后再试"
        case 40001: "App Secret 不正确，请检查后重新输入"
        case 40002: "请求的接口类型不正确"
        case 40013: "App ID 不正确，请检查后重新输入"
        case 40014: "Access Token 无效"
        case 40125: "App Secret 格式不正确，请检查是否有多余空格"
        case 41002: "缺少 App ID，请填写后重试"
        case 41004: "缺少 App Secret，请填写后重试"
        case 50001: "该公众号未开通接口权限，请在公众号后台开启"
        case 50002: "用户受限，请检查公众号状态是否正常"
        case 61024: "该公众号未绑定此 IP 的白名单，请在公众号后台添加服务器 IP"
        default: "微信接口错误（\(code)），请检查配置"
        }
    }

    // MARK: - AI 配图错误映射

    private static func friendlyImageError(_ statusCode: Int) -> String {
        switch statusCode {
        case 401: "API Key 无效或已过期，请检查后重新输入"
        case 403: "API Key 权限不足，请确认是否有生图权限"
        case 404: "API 地址不正确，请检查 Base URL"
        case 429: "请求过于频繁，请稍后再试"
        case 500...599: "生图服务暂时不可用，请稍后再试"
        default: "生图服务异常（HTTP \(statusCode)），请检查配置"
        }
    }

    private static func friendlyImageErrorMessage(_ message: String) -> String {
        if message.lowercased().contains("invalid api key") || message.lowercased().contains("incorrect api key") {
            return "API Key 无效，请检查后重新输入"
        }
        if message.lowercased().contains("quota") || message.lowercased().contains("billing") {
            return "账户额度不足，请充值后重试"
        }
        if message.lowercased().contains("model") {
            return "模型不可用，请检查模型名称是否正确"
        }
        return message
    }

    // MARK: - Helpers

    /// 自动补全 API Base URL，确保以 /v1 结尾
    private static func normalizeApiBase(_ base: String) -> String {
        var url = base.hasSuffix("/") ? String(base.dropLast()) : base
        if !url.hasSuffix("/v1") {
            url += "/v1"
        }
        return url
    }

    private static func generateSlug(from text: String) -> String {
        let words = text
            .lowercased()
            .components(separatedBy: .alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .prefix(4)

        let slug = words.joined(separator: "-")
        return slug.isEmpty ? "untitled" : slug
    }

}

enum TestError: LocalizedError {
    case invalidConfig(String)
    case invalidResponse(String)
    case apiFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidConfig(let msg): msg
        case .invalidResponse(let msg): msg
        case .apiFailed(let msg): msg
        }
    }
}

enum PublishError: LocalizedError {
    case scriptFailed(String)
    case noContent

    var errorDescription: String? {
        switch self {
        case .scriptFailed(let msg): "脚本执行失败: \(msg)"
        case .noContent: "没有内容可发布"
        }
    }
}
