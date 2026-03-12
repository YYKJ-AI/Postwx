import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var state = AppState()
    @State private var droppedFileURL: URL?
    @State private var showSettings = false
    @State private var publishError: String?

    var body: some View {
        VStack(spacing: 0) {
            // 顶部工具栏
            toolbar
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

            Divider()

            // 主内容区
            HSplitView {
                // 左侧：编辑区
                editorPanel
                    .frame(minWidth: 300)

                // 右侧：元数据 + 发布
                sidePanel
                    .frame(width: 220)
            }
        }
        .onAppear { loadCredentials() }
        .sheet(isPresented: $showSettings) {
            SettingsView(state: state)
                .interactiveDismissDisabled(false)
        }
        .alert("发布失败", isPresented: Binding(
            get: { publishError != nil },
            set: { if !$0 { publishError = nil } }
        )) {
            Button("好的") { publishError = nil }
        } message: {
            Text(publishError ?? "")
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleDrop(providers)
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack {
            Text("Postwx")
                .font(.headline)
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                openFile()
            } label: {
                Label("打开文件", systemImage: "doc")
            }
            .buttonStyle(.borderless)

            Button {
                showSettings = true
            } label: {
                Label("设置", systemImage: "gearshape")
            }
            .buttonStyle(.borderless)
        }
    }

    // MARK: - Editor

    private var editorPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            if state.content.isEmpty {
                emptyState
            } else {
                TextEditor(text: $state.content)
                    .font(.system(.body, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .padding(12)
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.system(size: 36))
                .foregroundStyle(.quaternary)
            Text("拖拽 Markdown 文件到此处")
                .foregroundStyle(.secondary)
            Text("或粘贴文本内容")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            // 点击后聚焦到编辑区
            state.content = " "
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                state.content = ""
            }
        }
    }

    // MARK: - Side Panel

    private var sidePanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 元数据
            Group {
                LabeledField("标题", text: $state.title, prompt: "自动提取")
                LabeledField("作者", text: $state.author, prompt: state.defaultAuthor.isEmpty ? "可选" : state.defaultAuthor)
                LabeledField("摘要", text: $state.summary, prompt: "自动生成", axis: .vertical)
            }

            Divider()

            // 主题选择
            Group {
                Picker("主题", selection: $state.selectedTheme) {
                    ForEach(Theme.allCases) { t in
                        Text(t.displayName).tag(t)
                    }
                }
                .pickerStyle(.menu)

                Picker("配色", selection: $state.selectedColor) {
                    ForEach(ThemeColor.allCases) { c in
                        Text(c.rawValue).tag(c)
                    }
                }
                .pickerStyle(.menu)
            }

            Divider()

            // AI 状态
            HStack(spacing: 4) {
                Circle()
                    .fill(AIService.isAvailable() ? .green : .orange)
                    .frame(width: 6, height: 6)
                Text(AIService.isAvailable() ? "Claude AI 已就绪" : "Claude CLI 未安装")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            // 发布状态
            if state.isPublishing {
                VStack(alignment: .leading, spacing: 6) {
                    ProgressView()
                        .controlSize(.small)
                    Text(state.publishProgress.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // 发布按钮
            publishButton
        }
        .padding(16)
    }

    private var publishButton: some View {
        Button {
            publish()
        } label: {
            HStack {
                if state.isPublishing {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "paperplane.fill")
                }
                Text(state.isPublishing ? "发布中..." : "发布到草稿箱")
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(state.content.isEmpty || state.isPublishing || !state.hasCredentials)
        .help(state.hasCredentials ? "" : "请先在设置中配置微信凭证")
    }

    // MARK: - Actions

    private func openFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [
            UTType(filenameExtension: "md")!,
            UTType(filenameExtension: "html")!,
            .plainText,
        ]
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let url = panel.url else { return }
        loadFile(url)
    }

    private func loadFile(_ url: URL) {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return }
        state.content = content
        droppedFileURL = url

        // 尝试从文件名提取标题
        if state.title.isEmpty {
            let filename = url.deletingPathExtension().lastPathComponent
            if filename != "index" && filename != "README" {
                state.title = filename
            }
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { data, _ in
            guard let data = data as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
            DispatchQueue.main.async { loadFile(url) }
        }
        return true
    }

    private func publish() {
        guard !state.content.isEmpty else { return }

        state.isPublishing = true
        state.publishProgress = .loadingPrefs
        state.publishLog = []

        Task {
            do {
                var content = state.content
                var title = state.title
                var summary = state.summary

                // AI 处理（通过本地 claude CLI，复用系统认证）
                if AIService.isAvailable() {
                    // 自动提取标题
                    if title.isEmpty {
                        state.publishProgress = .detectingInput
                        title = try await AIService.generateTitle(content: content)
                        state.title = title
                    }

                    // 去 AI 味
                    state.publishProgress = .deAI
                    content = try await AIService.deAI(content: content)
                    state.content = content

                    // 自动生成摘要
                    if summary.isEmpty {
                        state.publishProgress = .adaptingRole
                        summary = try await AIService.generateSummary(content: content, title: title)
                        state.summary = summary
                    }
                }

                // 保存内容到临时文件（AI 处理后内容已更新）
                state.publishProgress = .loadingPrefs
                let filePath = PublishService.saveTempMarkdown(
                    content: content,
                    title: title
                )

                state.publishProgress = .publishing

                let credentials = PublishService.Credentials(
                    wechatAppId: state.wechatAppId,
                    wechatAppSecret: state.wechatAppSecret,
                    imageApiBase: state.imageApiBase,
                    imageApiKey: state.imageApiKey,
                    imageModel: state.imageModel
                )

                let result = try await PublishService.publish(
                    filePath: filePath,
                    theme: state.selectedTheme,
                    color: state.selectedColor,
                    title: title.isEmpty ? nil : title,
                    summary: summary.isEmpty ? nil : summary,
                    author: state.author.isEmpty ? nil : state.author,
                    credentials: credentials,
                    onLog: { log in
                        Task { @MainActor in
                            state.publishLog.append(log)
                        }
                    }
                )

                state.publishProgress = .done
                state.publishLog.append(result)
            } catch {
                state.publishProgress = .failed
                state.publishLog.append("错误: \(error.localizedDescription)")
                publishError = error.localizedDescription
            }

            if state.publishProgress == .done {
                try? await Task.sleep(for: .seconds(2))
            }
            state.isPublishing = false
            state.publishProgress = .idle
        }
    }

    private func loadCredentials() {
        let defaults = UserDefaults.standard
        state.username = defaults.string(forKey: "username") ?? ""
        state.wechatAppId = defaults.string(forKey: "wechatAppId") ?? ""
        state.wechatAppSecret = defaults.string(forKey: "wechatAppSecret") ?? ""
        state.imageApiBase = defaults.string(forKey: "imageApiBase") ?? ""
        state.imageApiKey = defaults.string(forKey: "imageApiKey") ?? ""
        state.imageModel = defaults.string(forKey: "imageModel") ?? ""
        state.defaultAuthor = defaults.string(forKey: "defaultAuthor") ?? ""
    }
}

// MARK: - Components

struct LabeledField: View {
    let label: String
    @Binding var text: String
    var prompt: String = ""
    var axis: Axis = .horizontal

    init(_ label: String, text: Binding<String>, prompt: String = "", axis: Axis = .horizontal) {
        self.label = label
        self._text = text
        self.prompt = prompt
        self.axis = axis
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField(prompt, text: $text, axis: axis)
                .textFieldStyle(.roundedBorder)
                .controlSize(.small)
        }
    }
}
