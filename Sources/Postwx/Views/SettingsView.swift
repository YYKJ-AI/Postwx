import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
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

    var body: some View {
        VStack(spacing: 0) {
            settingsHeader
            settingsTabBar
            Rectangle().fill(Color.white.opacity(0.06)).frame(height: 0.5)

            Group {
                if selectedTab == 0 {
                    credentialsTab
                } else {
                    preferencesTab
                }
            }
        }
        .frame(width: 480, height: 640)
        .background(Color(nsColor: .windowBackgroundColor))
        .onDisappear { syncToState() }
    }

    // MARK: - Header

    private var settingsHeader: some View {
        HStack {
            Spacer()
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(LinearGradient(
                            colors: [Color(hex: 0x07C160), Color(hex: 0x06AD56)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                        .frame(width: 26, height: 26)
                        .shadow(color: Color(hex: 0x07C160).opacity(0.25), radius: 6, y: 2)
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                }
                Text("设置")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
            }
            Spacer()
        }
        .overlay(alignment: .trailing) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 26, height: 26)
                    .background(.quaternary.opacity(0.5), in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 22)
        .padding(.top, 20)
        .padding(.bottom, 14)
    }

    // MARK: - Tab Bar

    private var settingsTabBar: some View {
        HStack(spacing: 4) {
            SettingsTabButton(title: "凭证", icon: "key.fill", isSelected: selectedTab == 0) {
                withAnimation(.spring(duration: 0.3)) { selectedTab = 0 }
            }
            SettingsTabButton(title: "偏好", icon: "slider.horizontal.3", isSelected: selectedTab == 1) {
                withAnimation(.spring(duration: 0.3)) { selectedTab = 1 }
            }
        }
        .padding(.horizontal, 26)
        .padding(.bottom, 14)
    }

    // MARK: - Credentials Tab

    private var credentialsTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SCard(title: "用户信息", icon: "person.circle.fill", color: Color(hex: 0x07C160)) {
                    STextField("用户名", text: $username)
                }

                SCard(title: "微信公众号", icon: "message.fill", color: Color(hex: 0x10B981)) {
                    VStack(spacing: 10) {
                        STextField("App ID", text: $appId)
                        SSecureField("App Secret", text: $appSecret)
                    }
                    STestButton(state: wechatTestState, label: "测试连接",
                                disabled: appId.isEmpty || appSecret.isEmpty) { testWechat() }
                }

                SCard(title: "AI 配图", icon: "photo.artframe", color: Color(hex: 0x06AD56), badge: "可选") {
                    VStack(spacing: 10) {
                        STextField("API Base URL", text: $imageApiBase, placeholder: "https://api.tu-zi.com")
                        SSecureField("API Key", text: $imageApiKey)
                        STextField("模型", text: $imageModel, placeholder: "gpt-image-1")
                    }
                    Text("兼容 OpenAI Images API 格式的服务均可使用")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                    STestButton(state: imageTestState, label: "测试生图",
                                disabled: imageApiKey.isEmpty) { testImage() }
                }

                SCard(title: "AI 润色", icon: "sparkles", color: Color(hex: 0x06AD56)) {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(AIService.isAvailable() ? Color(hex: 0x10B981).opacity(0.12) : Color.orange.opacity(0.12))
                                .frame(width: 28, height: 28)
                            Circle()
                                .fill(AIService.isAvailable() ? Color(hex: 0x10B981) : .orange)
                                .frame(width: 7, height: 7)
                                .shadow(color: AIService.isAvailable() ? Color(hex: 0x10B981).opacity(0.5) : .orange.opacity(0.5), radius: 4)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(AIService.isAvailable() ? "Claude Code 已就绪" : "未检测到 claude CLI")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.primary.opacity(0.8))
                            Text(AIService.isAvailable() ? "自动使用系统级认证" : "需要安装 claude CLI")
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                        }
                    }

                    if AIService.isAvailable() {
                        STestButton(state: claudeTestState, label: "测试 AI", disabled: false) { testClaude() }
                    } else {
                        HStack(spacing: 5) {
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

                HStack {
                    Spacer()
                    Button { importFromEnv() } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "square.and.arrow.down")
                                .font(.system(size: 11))
                            Text("从 .env 文件导入")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
            }
            .padding(22)
        }
    }

    // MARK: - Preferences Tab

    private var preferencesTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SCard(title: "创作角色", icon: "person.text.rectangle.fill", color: Color(hex: 0xF59E0B)) {
                    VStack(spacing: 12) {
                        SPickerField("角色", selection: $creatorRole) {
                            ForEach(CreatorRole.allCases) { role in Text(role.displayName).tag(role.rawValue) }
                        }
                        SPickerField("风格", selection: $writingStyle) {
                            ForEach(WritingStyle.allCases) { style in Text(style.displayName).tag(style.rawValue) }
                        }
                        SPickerField("受众", selection: $targetAudience) {
                            ForEach(TargetAudience.allCases) { audience in Text(audience.displayName).tag(audience.rawValue) }
                        }
                    }
                }

                SCard(title: "发布设置", icon: "paperplane.fill", color: Color(hex: 0x06B6D4)) {
                    VStack(spacing: 12) {
                        STextField("默认作者", text: $defaultAuthor)

                        VStack(spacing: 10) {
                            Toggle(isOn: $needOpenComment) {
                                HStack(spacing: 6) {
                                    Image(systemName: "bubble.left.and.bubble.right")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                    Text("开启评论")
                                        .font(.system(size: 14))
                                }
                            }
                            .toggleStyle(.switch)

                            Toggle(isOn: $onlyFansCanComment) {
                                HStack(spacing: 6) {
                                    Image(systemName: "heart.circle")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                    Text("仅粉丝可评论")
                                        .font(.system(size: 14))
                                }
                            }
                            .toggleStyle(.switch)
                        }
                    }
                }
            }
            .padding(22)
        }
    }

    // MARK: - Actions

    private func testWechat() {
        wechatTestState = .testing
        Task {
            do {
                let msg = try await PublishService.testWechatCredentials(appId: appId, appSecret: appSecret)
                wechatTestState = .success(msg)
            } catch { wechatTestState = .failure(friendlyNetworkError(error)) }
        }
    }

    private func testImage() {
        imageTestState = .testing
        Task {
            do {
                let msg = try await PublishService.testImageGeneration(apiBase: imageApiBase, apiKey: imageApiKey, model: imageModel)
                imageTestState = .success(msg)
            } catch { imageTestState = .failure(friendlyNetworkError(error)) }
        }
    }

    private func testClaude() {
        claudeTestState = .testing
        Task {
            do {
                let msg = try await AIService.testConnection()
                claudeTestState = .success(msg)
            } catch { claudeTestState = .failure(error.localizedDescription) }
        }
    }

    private func friendlyNetworkError(_ error: Error) -> String {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorNotConnectedToInternet: return "无网络连接"
            case NSURLErrorTimedOut: return "连接超时"
            case NSURLErrorCannotFindHost: return "无法找到服务器"
            case NSURLErrorCannotConnectToHost: return "无法连接到服务器"
            case NSURLErrorSecureConnectionFailed: return "SSL 连接失败"
            default: return "网络错误"
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
                if (value.hasPrefix("\"") && value.hasSuffix("\"")) || (value.hasPrefix("'") && value.hasSuffix("'")) {
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
    case idle, testing
    case success(String)
    case failure(String)
}

// MARK: - Settings Components

struct SettingsTabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                Text(title)
                    .font(.system(size: 12, weight: .bold))
            }
            .foregroundStyle(isSelected ? .white : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                isSelected
                    ? AnyShapeStyle(LinearGradient(
                        colors: [Color(hex: 0x07C160), Color(hex: 0x06AD56)],
                        startPoint: .leading, endPoint: .trailing))
                    : AnyShapeStyle(Color.primary.opacity(isHovered ? 0.06 : 0.03)),
                in: RoundedRectangle(cornerRadius: 8)
            )
            .shadow(color: isSelected ? Color(hex: 0x07C160).opacity(0.2) : .clear, radius: 6, y: 2)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

struct SCard<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    var badge: String? = nil
    @ViewBuilder let content: Content
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(color.opacity(0.12))
                        .frame(width: 26, height: 26)
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(color)
                }
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.primary.opacity(0.85))

                if let badge {
                    Text(badge)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Color.primary.opacity(0.05), in: Capsule())
                }
            }
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(nsColor: .controlBackgroundColor))
                .shadow(color: colorScheme == .dark ? .black.opacity(0.25) : .black.opacity(0.05), radius: 8, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(colorScheme == .dark ? 0.06 : 0.0), lineWidth: 0.5)
        )
    }
}

struct STextField: View {
    let label: String
    @Binding var text: String
    var placeholder: String?
    @FocusState private var isFocused: Bool

    init(_ label: String, text: Binding<String>, placeholder: String? = nil) {
        self.label = label
        self._text = text
        self.placeholder = placeholder
    }

    var body: some View {
        TextField(placeholder ?? label, text: $text)
            .textFieldStyle(.plain)
            .font(.system(size: 14))
            .focused($isFocused)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .textBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isFocused ? Color(hex: 0x07C160).opacity(0.4) : Color.white.opacity(0.06), lineWidth: isFocused ? 1.5 : 0.5)
            )
            .textContentType(.none)
            .autocorrectionDisabled()
            .animation(.easeOut(duration: 0.15), value: isFocused)
    }
}

struct SSecureField: View {
    let label: String
    @Binding var text: String
    @FocusState private var isFocused: Bool

    init(_ label: String, text: Binding<String>) {
        self.label = label
        self._text = text
    }

    var body: some View {
        SecureField(label, text: $text)
            .textFieldStyle(.plain)
            .font(.system(size: 14))
            .focused($isFocused)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .textBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isFocused ? Color(hex: 0x07C160).opacity(0.4) : Color.white.opacity(0.06), lineWidth: isFocused ? 1.5 : 0.5)
            )
            .textContentType(.none)
            .animation(.easeOut(duration: 0.15), value: isFocused)
    }
}

struct SPickerField<Content: View>: View {
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
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .leading)
            Picker("", selection: $selection) { content }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity)
        }
    }
}

struct STestButton: View {
    let state: TestState
    let label: String
    let disabled: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            Button(action: action) {
                HStack(spacing: 5) {
                    if state == .testing {
                        ProgressView().controlSize(.mini)
                    } else {
                        Image(systemName: "play.fill")
                            .font(.system(size: 8))
                    }
                    Text(state == .testing ? "测试中..." : label)
                        .font(.system(size: 11, weight: .semibold))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(isHovered ? Color.primary.opacity(0.08) : Color.primary.opacity(0.04))
                )
            }
            .buttonStyle(.plain)
            .disabled(disabled || state == .testing)
            .onHover { isHovered = $0 }

            switch state {
            case .success(let msg):
                HStack(spacing: 3) {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 10))
                    Text(msg).font(.system(size: 10))
                }
                .foregroundStyle(Color(hex: 0x10B981))
                .transition(.scale.combined(with: .opacity))
            case .failure(let msg):
                HStack(spacing: 3) {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 10))
                    Text(msg).font(.system(size: 10))
                }
                .foregroundStyle(Color(hex: 0xEF4444))
                .lineLimit(2)
                .transition(.scale.combined(with: .opacity))
            default:
                EmptyView()
            }
        }
        .animation(.spring(duration: 0.3), value: state == .testing)
    }
}
