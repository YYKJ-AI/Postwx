import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var state = AppState()
    @State private var droppedFileURL: URL?
    @State private var showSettings = false

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
        .sheet(isPresented: $showSettings) {
            SettingsView(state: state)
                .interactiveDismissDisabled(false)
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
                // 保存内容到临时文件
                let filePath: String
                if let url = droppedFileURL {
                    filePath = url.path
                } else {
                    filePath = PublishService.saveTempMarkdown(
                        content: state.content,
                        title: state.title
                    )
                }

                state.publishProgress = .publishing

                // 查找 .env 文件
                let envPath = findEnvPath()

                let result = try await PublishService.publish(
                    filePath: filePath,
                    theme: state.selectedTheme,
                    color: state.selectedColor,
                    title: state.title.isEmpty ? nil : state.title,
                    summary: state.summary.isEmpty ? nil : state.summary,
                    author: state.author.isEmpty ? nil : state.author,
                    envPath: envPath,
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
            }

            try? await Task.sleep(for: .seconds(2))
            state.isPublishing = false
            state.publishProgress = .idle
        }
    }

    private func findEnvPath() -> String? {
        let candidates = [
            FileManager.default.currentDirectoryPath + "/.baoyu-skills/.env",
            NSHomeDirectory() + "/.baoyu-skills/.env",
        ]
        return candidates.first { FileManager.default.fileExists(atPath: $0) }
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
