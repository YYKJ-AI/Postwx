import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    var state: AppState?

    @AppStorage("username") private var username = ""
    @AppStorage("wechatAppId") private var appId = ""
    @AppStorage("wechatAppSecret") private var appSecret = ""
    @AppStorage("imageApiBase") private var imageApiBase = ""
    @AppStorage("imageApiKey") private var imageApiKey = ""
    @AppStorage("imageModel") private var imageModel = ""
    @AppStorage("creatorRole") private var creatorRole = "tech-blogger"
    @AppStorage("writingStyle") private var writingStyle = "professional"
    @AppStorage("targetAudience") private var targetAudience = "general"
    @AppStorage("defaultAuthor") private var defaultAuthor = ""
    @AppStorage("needOpenComment") private var needOpenComment = true
    @AppStorage("onlyFansCanComment") private var onlyFansCanComment = false

    @State private var selectedTab = 0
    @State private var wechatTestState: TestState = .idle
    @State private var imageTestState: TestState = .idle
    @State private var claudeTestState: TestState = .idle

    private let accentGradient = LinearGradient(
        colors: [Color(hue: 0.72, saturation: 0.65, brightness: 0.95),
                 Color(hue: 0.58, saturation: 0.70, brightness: 0.90)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    var body: some View {
        VStack(spacing: 0) {
            // 顶部标题栏
            header

            // Tab 切换
            tabPicker

            Divider().opacity(0.5)

            // 内容区
            Group {
                if selectedTab == 0 {
                    credentialsTab
                } else {
                    preferencesTab
                }
            }
        }
        .frame(width: 440, height: 600)
        .background(Color(nsColor: .windowBackgroundColor))
        .onDisappear { syncToState() }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(accentGradient)
                Text("设置")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
            }
            Spacer()
        }
        .overlay(alignment: .trailing) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
                    .background(.quaternary.opacity(0.5), in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 10)
    }

    // MARK: - Tab Picker

    private var tabPicker: some View {
        HStack(spacing: 4) {
            TabButton(title: "凭证", icon: "key.fill", isSelected: selectedTab == 0) {
                withAnimation(.snappy(duration: 0.2)) { selectedTab = 0 }
            }
            TabButton(title: "偏好", icon: "slider.horizontal.3", isSelected: selectedTab == 1) {
                withAnimation(.snappy(duration: 0.2)) { selectedTab = 1 }
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 10)
    }

    // MARK: - Credentials Tab

    private var credentialsTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 用户信息
                SettingsCard(title: "用户信息", icon: "person.circle.fill", color: .blue) {
                    SettingsTextField("用户名", text: $username)
                }

                // 微信公众号
                SettingsCard(title: "微信公众号", icon: "message.fill", color: .green) {
                    VStack(spacing: 10) {
                        SettingsTextField("App ID", text: $appId)
                        SettingsSecureField("App Secret", text: $appSecret)
                    }

                    SettingsTestButton(
                        state: wechatTestState,
                        label: "测试连接",
                        disabled: appId.isEmpty || appSecret.isEmpty
                    ) {
                        testWechat()
                    }
                }

                // AI 配图
                SettingsCard(title: "AI 配图", icon: "photo.artframe", color: .purple, badge: "可选") {
                    VStack(spacing: 10) {
                        SettingsTextField("API Base URL", text: $imageApiBase, placeholder: "https://api.tu-zi.com")
                        SettingsSecureField("API Key", text: $imageApiKey)
                        SettingsTextField("模型", text: $imageModel, placeholder: "gpt-image-1")
                    }

                    Text("兼容 OpenAI Images API 格式的服务均可使用")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)

                    SettingsTestButton(
                        state: imageTestState,
                        label: "测试生图",
                        disabled: imageApiKey.isEmpty
                    ) {
                        testImage()
                    }
                }

                // Claude AI
                SettingsCard(title: "AI 润色", icon: "sparkles", color: .indigo) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(AIService.isAvailable() ? .green : .orange)
                            .frame(width: 7, height: 7)
                            .shadow(color: AIService.isAvailable() ? .green.opacity(0.4) : .orange.opacity(0.4), radius: 3)
                        Text(AIService.isAvailable()
                             ? "Claude Code 已就绪"
                             : "未检测到 claude CLI")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }

                    if AIService.isAvailable() {
                        Text("自动使用系统级认证，无需额外配置")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)

                        SettingsTestButton(
                            state: claudeTestState,
                            label: "测试 AI",
                            disabled: false
                        ) {
                            testClaude()
                        }
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "terminal")
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                            Text("npm install -g @anthropic-ai/claude-code")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.tertiary)
                                .textSelection(.enabled)
                        }
                    }
                }

                // 导入按钮
                HStack {
                    Spacer()
                    Button {
                        importFromEnv()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "square.and.arrow.down")
                                .font(.system(size: 11))
                            Text("从 .env 文件导入")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
            }
            .padding(20)
        }
    }

    // MARK: - Preferences Tab

    private var preferencesTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SettingsCard(title: "创作角色", icon: "person.text.rectangle.fill", color: .orange) {
                    VStack(spacing: 10) {
                        SettingsPickerField("角色", selection: $creatorRole) {
                            ForEach(CreatorRole.allCases) { role in
                                Text(role.displayName).tag(role.rawValue)
                            }
                        }
                        SettingsPickerField("风格", selection: $writingStyle) {
                            ForEach(WritingStyle.allCases) { style in
                                Text(style.displayName).tag(style.rawValue)
                            }
                        }
                        SettingsPickerField("受众", selection: $targetAudience) {
                            ForEach(TargetAudience.allCases) { audience in
                                Text(audience.displayName).tag(audience.rawValue)
                            }
                        }
                    }
                }

                SettingsCard(title: "发布设置", icon: "paperplane.fill", color: .teal) {
                    VStack(spacing: 10) {
                        SettingsTextField("默认作者", text: $defaultAuthor)

                        VStack(spacing: 8) {
                            Toggle(isOn: $needOpenComment) {
                                HStack(spacing: 6) {
                                    Image(systemName: "bubble.left.and.bubble.right")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                    Text("开启评论")
                                        .font(.system(size: 13))
                                }
                            }
                            .toggleStyle(.switch)

                            Toggle(isOn: $onlyFansCanComment) {
                                HStack(spacing: 6) {
                                    Image(systemName: "heart.circle")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                    Text("仅粉丝可评论")
                                        .font(.system(size: 13))
                                }
                            }
                            .toggleStyle(.switch)
                        }
                    }
                }
            }
            .padding(20)
        }
    }

    // MARK: - Actions

    private func testWechat() {
        wechatTestState = .testing
        Task {
            do {
                let msg = try await PublishService.testWechatCredentials(appId: appId, appSecret: appSecret)
                wechatTestState = .success(msg)
            } catch {
                wechatTestState = .failure(friendlyNetworkError(error))
            }
        }
    }

    private func testImage() {
        imageTestState = .testing
        Task {
            do {
                let msg = try await PublishService.testImageGeneration(
                    apiBase: imageApiBase,
                    apiKey: imageApiKey,
                    model: imageModel
                )
                imageTestState = .success(msg)
            } catch {
                imageTestState = .failure(friendlyNetworkError(error))
            }
        }
    }

    private func testClaude() {
        claudeTestState = .testing
        Task {
            do {
                let msg = try await AIService.testConnection()
                claudeTestState = .success(msg)
            } catch {
                claudeTestState = .failure(error.localizedDescription)
            }
        }
    }

    private func friendlyNetworkError(_ error: Error) -> String {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorNotConnectedToInternet: return "无网络连接，请检查网络"
            case NSURLErrorTimedOut: return "连接超时，请稍后再试"
            case NSURLErrorCannotFindHost: return "无法找到服务器，请检查 URL"
            case NSURLErrorCannotConnectToHost: return "无法连接到服务器"
            case NSURLErrorSecureConnectionFailed: return "SSL 连接失败，请检查 URL"
            default: return "网络错误：\(nsError.localizedDescription)"
            }
        }
        return error.localizedDescription
    }

    private func importFromEnv() {
        let candidates = [
            FileManager.default.currentDirectoryPath + "/.baoyu-skills/.env",
            NSHomeDirectory() + "/.baoyu-skills/.env",
        ]

        for path in candidates {
            guard let content = try? String(contentsOfFile: path, encoding: .utf8) else { continue }

            for line in content.components(separatedBy: .newlines) {
                let parts = line.split(separator: "=", maxSplits: 1)
                guard parts.count == 2 else { continue }
                let key = String(parts[0]).trimmingCharacters(in: .whitespaces)
                var value = String(parts[1]).trimmingCharacters(in: .whitespaces)
                if (value.hasPrefix("\"") && value.hasSuffix("\"")) ||
                    (value.hasPrefix("'") && value.hasSuffix("'")) {
                    value = String(value.dropFirst().dropLast())
                }

                switch key {
                case "WECHAT_APP_ID": appId = value
                case "WECHAT_APP_SECRET": appSecret = value
                case "IMAGE_API_KEY": imageApiKey = value
                case "IMAGE_API_BASE": imageApiBase = value
                case "IMAGE_MODEL": imageModel = value
                default: break
                }
            }
            break
        }
    }

    private func syncToState() {
        guard let state else { return }
        state.username = username
        state.wechatAppId = appId
        state.wechatAppSecret = appSecret
        state.imageApiBase = imageApiBase
        state.imageApiKey = imageApiKey
        state.imageModel = imageModel
        state.defaultAuthor = defaultAuthor

        let fallbackAuthor = defaultAuthor.isEmpty ? username : defaultAuthor
        if state.author.isEmpty || state.author == state.defaultAuthor || state.author == state.username {
            state.author = fallbackAuthor
        }

        if let r = CreatorRole(rawValue: creatorRole) { state.creatorRole = r }
        if let s = WritingStyle(rawValue: writingStyle) { state.writingStyle = s }
        if let a = TargetAudience(rawValue: targetAudience) { state.targetAudience = a }
        state.needOpenComment = needOpenComment
        state.onlyFansCanComment = onlyFansCanComment
    }
}

// MARK: - Test State

enum TestState: Equatable {
    case idle
    case testing
    case success(String)
    case failure(String)
}

// MARK: - Settings Components

struct TabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(isSelected ? .white : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                isSelected
                    ? AnyShapeStyle(LinearGradient(
                        colors: [Color(hue: 0.72, saturation: 0.65, brightness: 0.95),
                                 Color(hue: 0.58, saturation: 0.70, brightness: 0.90)],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    : AnyShapeStyle(Color.clear),
                in: RoundedRectangle(cornerRadius: 7)
            )
            .background(
                !isSelected
                    ? AnyShapeStyle(Color.primary.opacity(0.04))
                    : AnyShapeStyle(Color.clear),
                in: RoundedRectangle(cornerRadius: 7)
            )
        }
        .buttonStyle(.plain)
    }
}

struct SettingsCard<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    var badge: String? = nil
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(color)
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.8))

                if let badge {
                    Text(badge)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.quaternary.opacity(0.5), in: Capsule())
                }
            }

            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .controlBackgroundColor))
                .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        )
    }
}

struct SettingsTextField: View {
    let label: String
    @Binding var text: String
    var placeholder: String?

    init(_ label: String, text: Binding<String>, placeholder: String? = nil) {
        self.label = label
        self._text = text
        self.placeholder = placeholder
    }

    var body: some View {
        TextField(placeholder ?? label, text: $text)
            .textFieldStyle(.plain)
            .font(.system(size: 13))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(Color(nsColor: .textBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            )
            .textContentType(.none)
            .autocorrectionDisabled()
    }
}

struct SettingsSecureField: View {
    let label: String
    @Binding var text: String

    init(_ label: String, text: Binding<String>) {
        self.label = label
        self._text = text
    }

    var body: some View {
        SecureField(label, text: $text)
            .textFieldStyle(.plain)
            .font(.system(size: 13))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(Color(nsColor: .textBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            )
            .textContentType(.none)
    }
}

struct SettingsPickerField<Content: View>: View {
    let label: String
    @Binding var selection: String
    @ViewBuilder let content: Content

    init(_ label: String, selection: Binding<String>, @ViewBuilder content: () -> Content) {
        self.label = label
        self._selection = selection
        self.content = content()
    }

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .leading)
            Picker("", selection: $selection) {
                content
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity)
        }
    }
}

struct SettingsTestButton: View {
    let state: TestState
    let label: String
    let disabled: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: action) {
                HStack(spacing: 5) {
                    if state == .testing {
                        ProgressView()
                            .controlSize(.mini)
                    } else {
                        Image(systemName: "play.fill")
                            .font(.system(size: 8))
                    }
                    Text(state == .testing ? "测试中..." : label)
                        .font(.system(size: 11, weight: .medium))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(.ultraThinMaterial, in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(disabled || state == .testing)

            switch state {
            case .success(let msg):
                HStack(spacing: 3) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10))
                    Text(msg)
                        .font(.system(size: 10))
                }
                .foregroundStyle(.green)
                .transition(.scale.combined(with: .opacity))
            case .failure(let msg):
                HStack(spacing: 3) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 10))
                    Text(msg)
                        .font(.system(size: 10))
                }
                .foregroundStyle(.red)
                .lineLimit(2)
                .transition(.scale.combined(with: .opacity))
            default:
                EmptyView()
            }
        }
        .animation(.snappy(duration: 0.3), value: state == .testing)
    }
}
