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

    static func publish(
        filePath: String,
        theme: Theme,
        color: ThemeColor,
        title: String?,
        summary: String?,
        author: String?,
        envPath: String?,
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

        // 设置环境变量
        var env = ProcessInfo.processInfo.environment
        if let envPath {
            loadEnvFile(path: envPath, into: &env)
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

    // MARK: - Helpers

    private static func generateSlug(from text: String) -> String {
        let words = text
            .lowercased()
            .components(separatedBy: .alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .prefix(4)

        let slug = words.joined(separator: "-")
        return slug.isEmpty ? "untitled" : slug
    }

    private static func loadEnvFile(path: String, into env: inout [String: String]) {
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else { return }
        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }
            let parts = trimmed.split(separator: "=", maxSplits: 1)
            if parts.count == 2 {
                env[String(parts[0])] = String(parts[1])
            }
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
