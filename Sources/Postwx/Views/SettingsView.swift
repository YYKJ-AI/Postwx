import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    var state: AppState?

    @AppStorage("wechatAppId") private var appId = ""
    @AppStorage("wechatAppSecret") private var appSecret = ""
    @AppStorage("imageApiKey") private var imageApiKey = ""
    @AppStorage("creatorRole") private var creatorRole = "tech-blogger"
    @AppStorage("writingStyle") private var writingStyle = "professional"
    @AppStorage("targetAudience") private var targetAudience = "general"
    @AppStorage("defaultAuthor") private var defaultAuthor = ""
    @AppStorage("needOpenComment") private var needOpenComment = true
    @AppStorage("onlyFansCanComment") private var onlyFansCanComment = false

    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            // 顶部标题栏 + 关闭按钮
            HStack {
                Spacer()
                Text("设置")
                    .font(.headline)
                Spacer()
            }
            .overlay(alignment: .trailing) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            // Tab 切换
            Picker("", selection: $selectedTab) {
                Text("凭证").tag(0)
                Text("偏好").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 24)
            .padding(.bottom, 8)

            Divider()

            // 内容区
            Group {
                if selectedTab == 0 {
                    credentialsTab
                } else {
                    preferencesTab
                }
            }
        }
        .frame(width: 400, height: 360)
        .onDisappear { syncToState() }
    }

    // MARK: - Credentials Tab

    private var credentialsTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 微信公众号
                sectionHeader("微信公众号")

                VStack(spacing: 10) {
                    settingsTextField("App ID", text: $appId)
                    settingsTextField("App Secret", text: $appSecret)
                }

                // AI 配图
                sectionHeader("AI 配图（可选）")

                VStack(spacing: 6) {
                    settingsTextField("Image API Key", text: $imageApiKey)
                    Text("用于 AI 自动生成封面和插图")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                // 导入按钮
                Button("从 .env 文件导入") {
                    importFromEnv()
                }
                .buttonStyle(.link)
                .font(.caption)
            }
            .padding(20)
        }
    }

    // MARK: - Preferences Tab

    private var preferencesTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                sectionHeader("创作角色")

                VStack(spacing: 10) {
                    settingsPicker("角色", selection: $creatorRole) {
                        ForEach(CreatorRole.allCases) { role in
                            Text(role.displayName).tag(role.rawValue)
                        }
                    }
                    settingsPicker("风格", selection: $writingStyle) {
                        ForEach(WritingStyle.allCases) { style in
                            Text(style.displayName).tag(style.rawValue)
                        }
                    }
                    settingsPicker("受众", selection: $targetAudience) {
                        ForEach(TargetAudience.allCases) { audience in
                            Text(audience.displayName).tag(audience.rawValue)
                        }
                    }
                }

                sectionHeader("发布设置")

                VStack(spacing: 10) {
                    settingsTextField("默认作者", text: $defaultAuthor)
                    settingsToggle("开启评论", isOn: $needOpenComment)
                    settingsToggle("仅粉丝可评论", isOn: $onlyFansCanComment)
                }
            }
            .padding(20)
        }
    }

    // MARK: - Components

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.secondary)
    }

    private func settingsTextField(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .textFieldStyle(.roundedBorder)
            .textContentType(.none)
            .autocorrectionDisabled()
    }

    private func settingsPicker<Content: View>(
        _ label: String,
        selection: Binding<String>,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack {
            Text(label)
                .frame(width: 40, alignment: .leading)
            Picker("", selection: selection) {
                content()
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity)
        }
    }

    private func settingsToggle(_ label: String, isOn: Binding<Bool>) -> some View {
        Toggle(label, isOn: isOn)
            .toggleStyle(.switch)
    }

    // MARK: - Actions

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
                let value = String(parts[1]).trimmingCharacters(in: .whitespaces)

                switch key {
                case "WECHAT_APP_ID": appId = value
                case "WECHAT_APP_SECRET": appSecret = value
                case "IMAGE_API_KEY": imageApiKey = value
                default: break
                }
            }
            break
        }
    }

    private func syncToState() {
        guard let state else { return }
        state.wechatAppId = appId
        state.wechatAppSecret = appSecret
        state.imageApiKey = imageApiKey
        state.defaultAuthor = defaultAuthor
    }
}
