import SwiftUI
import UniformTypeIdentifiers

// MARK: - Design System

private enum DS {
    // 微信品牌色
    static let wechatGreen = Color(hex: 0x07C160)
    static let brandGradient = LinearGradient(
        colors: [Color(hex: 0x07C160), Color(hex: 0x06AD56)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let brandGlow = Color(hex: 0x07C160)

    static let successGradient = LinearGradient(
        colors: [Color(hex: 0x10B981), Color(hex: 0x34D399)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    static let warningGradient = LinearGradient(
        colors: [Color(hex: 0xF59E0B), Color(hex: 0xFBBF24)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    static let dangerGradient = LinearGradient(
        colors: [Color(hex: 0xEF4444), Color(hex: 0xF87171)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    // 表面层级
    static let surfacePrimary = Color(nsColor: .windowBackgroundColor)
    static let surfaceElevated = Color(nsColor: .controlBackgroundColor)
    static let surfaceInput = Color(nsColor: .textBackgroundColor)

    // 边框
    static let borderDefault = Color.white.opacity(0.08)
    static let borderSubtle = Color.white.opacity(0.04)
    static let borderActive = Color(hex: 0x07C160).opacity(0.3)

    // 圆角
    static let r16: CGFloat = 16
    static let r12: CGFloat = 12
    static let r10: CGFloat = 10
    static let r8: CGFloat = 8
    static let r6: CGFloat = 6
}

// MARK: - Color Extension

extension Color {
    init(hex: UInt, opacity: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

// MARK: - Content View

struct ContentView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var state = AppState()
    @State private var droppedFileURL: URL?
    @State private var showSettings = false
    @State private var publishError: String?
    @State private var showOriginalContent = false
    @State private var isHoveringDrop = false
    @AppStorage("username") private var storedUsername = ""
    @AppStorage("defaultAuthor") private var storedDefaultAuthor = ""

    var body: some View {
        HSplitView {
            editorPanel
                .frame(minWidth: 380)
            workflowPanel
                .frame(width: 320)
        }
        .background(DS.surfacePrimary)
        .navigationTitle("Postwx")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                if state.isReviewing {
                    LiveStatusBadge(label: "审核中", icon: "eye.fill", color: Color(hex: 0xF59E0B), isAnimated: false)
                } else if state.isProcessing {
                    LiveStatusBadge(label: "处理中", icon: "bolt.fill", color: DS.brandGlow, isAnimated: true)
                }
            }

            ToolbarItemGroup(placement: .automatic) {
                if state.isReviewing {
                    Button {
                        showOriginalContent.toggle()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: showOriginalContent ? "doc.on.doc.fill" : "doc.on.doc")
                                .font(.system(size: 15))
                            Text(showOriginalContent ? "隐藏原文" : "对比原文")
                                .font(.system(size: 13, weight: .medium))
                        }
                    }
                    .controlSize(.large)
                }

                Button { openFile() } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "doc.badge.plus")
                            .font(.system(size: 15))
                        Text("打开")
                            .font(.system(size: 13, weight: .medium))
                    }
                }
                .controlSize(.large)
                .disabled(state.isBusy)

                Button { showSettings = true } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 15))
                        Text("设置")
                            .font(.system(size: 13, weight: .medium))
                    }
                }
                .controlSize(.large)
            }
        }
        .onAppear {
            loadCredentials()
            if state.author.isEmpty {
                let fallback = storedDefaultAuthor.isEmpty ? storedUsername : storedDefaultAuthor
                if !fallback.isEmpty { state.author = fallback }
            }
        }
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
        .onDrop(of: [.fileURL], isTargeted: $isHoveringDrop) { providers in
            handleDrop(providers)
        }
    }

    // MARK: - Editor Panel

    private var editorPanel: some View {
        ZStack {
            if state.isReviewing && showOriginalContent {
                originalContentView
            } else if state.content.isEmpty {
                emptyState
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    if state.isReviewing {
                        reviewHeader
                    }
                    TextEditor(text: $state.content)
                        .font(.body.monospaced())  // 13pt monospaced — macOS body
                        .scrollContentBackground(.hidden)
                        .padding(16)
                }
            }

            if isHoveringDrop {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(DS.brandGlow.opacity(0.6), lineWidth: 2)
                    .background(DS.brandGlow.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
                    .padding(6)
                    .allowsHitTesting(false)
            }
        }
        .background(DS.surfaceInput)
        .animation(.easeOut(duration: 0.2), value: isHoveringDrop)
    }

    private var originalContentView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "doc.text")
                        .font(.subheadline)  // 11pt
                    Text("原文内容")
                        .font(.headline)  // 13pt semibold
                }
                .foregroundStyle(.secondary)
                Spacer()
                IconButton(icon: "xmark", size: .small) {
                    showOriginalContent = false
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            ScrollView {
                Text(state.originalContent)
                    .font(.body.monospaced())  // 13pt
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
            }
            .background(Color.orange.opacity(0.02))
        }
    }

    private var reviewHeader: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Circle()
                    .fill(DS.brandGradient)
                    .frame(width: 7, height: 7)
                Text("AI 处理后（可编辑）")
                    .font(.headline)  // 13pt semibold
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let score = state.deAIScore {
                ScoreBadge(score: score)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 6)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 28) {
            ZStack {
                // 外圈脉冲
                Circle()
                    .stroke(DS.brandGlow.opacity(0.08), lineWidth: 1)
                    .frame(width: 120, height: 120)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [DS.brandGlow.opacity(0.10), DS.brandGlow.opacity(0.02)],
                            center: .center,
                            startRadius: 10,
                            endRadius: 55
                        )
                    )
                    .frame(width: 100, height: 100)

                // 内圈
                Circle()
                    .fill(DS.brandGlow.opacity(0.08))
                    .frame(width: 64, height: 64)

                Image(systemName: "doc.text.fill")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(DS.brandGradient)
            }

            VStack(spacing: 10) {
                Text("拖拽文件到此处")
                    .font(.title2)  // 18pt
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary.opacity(0.8))

                HStack(spacing: 8) {
                    ForEach(["Markdown", "HTML", "纯文本"], id: \.self) { format in
                        Text(format)
                            .font(.subheadline)  // 11pt
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.primary.opacity(0.04), in: Capsule())
                    }
                }
            }

            Button {
                openFile()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "folder.fill")
                        .font(.body)  // 13pt
                    Text("选择文件")
                        .font(.body.weight(.semibold))  // 13pt semibold
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 9)
                .background(DS.brandGradient, in: Capsule())
                .shadow(color: DS.brandGlow.opacity(0.25), radius: 10, y: 4)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            state.content = " "
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                state.content = ""
            }
        }
    }

    // MARK: - Workflow Panel

    private var workflowPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // 进度总览
                    if state.isProcessing || state.isReviewing || state.isPublishing {
                        progressOverview
                    }

                    if !state.isProcessing {
                        metadataFields
                    }

                    workflowTimeline

                    if state.isProcessing && !state.aiStreamingText.isEmpty {
                        aiStreamingOutput
                    }

                    if state.workflowState == .idle {
                        aiStatusCard
                    }

                    if case .done(let mediaId) = state.workflowState {
                        doneSection(mediaId: mediaId)
                    }
                }
                .padding(18)
            }

            Spacer(minLength: 0)

            // 底部操作
            VStack(spacing: 0) {
                Rectangle().fill(DS.borderDefault).frame(height: 0.5)
                actionButtons
                    .padding(18)
            }
        }
        .background(DS.surfaceElevated.opacity(0.5))
    }

    // MARK: - Progress Overview

    private var progressOverview: some View {
        let total = WorkflowStep.allCases.count
        let completed = WorkflowStep.allCases.filter {
            if case .completed = state.stepStatus($0) { return true }
            if case .skipped = state.stepStatus($0) { return true }
            return false
        }.count
        let progress = Double(completed) / Double(total)

        return HStack(spacing: 14) {
            // 环形进度
            ZStack {
                Circle()
                    .stroke(Color.primary.opacity(0.06), lineWidth: 4)
                    .frame(width: 48, height: 48)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(DS.brandGradient, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 48, height: 48)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(duration: 0.6), value: progress)

                Text("\(completed)/\(total)")
                    .font(.headline.monospacedDigit())  // 13pt bold
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(state.isReviewing ? "等待审核" : state.isPublishing ? "发布中" : "处理中")
                    .font(.title3.weight(.semibold))  // 16pt
                    .foregroundStyle(.primary)

                Text("\(Int(progress * 100))% 完成")
                    .font(.body)  // 13pt
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: DS.r12)
                .fill(.ultraThinMaterial)
                .shadow(color: DS.brandGlow.opacity(0.06), radius: 12, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.r12)
                .stroke(DS.borderActive, lineWidth: 1)
        )
    }

    // MARK: - Metadata Fields

    private var metadataFields: some View {
        VStack(spacing: 12) {
            InputField(label: "标题", icon: "textformat", text: $state.title, prompt: "自动提取")
                .disabled(state.isBusy)
            InputField(label: "作者", icon: "person.fill", text: $state.author, prompt: {
                if !storedDefaultAuthor.isEmpty { return storedDefaultAuthor }
                if !storedUsername.isEmpty { return storedUsername }
                return "可选"
            }())
                .disabled(state.isBusy)
            InputField(label: "摘要", icon: "text.alignleft", text: $state.summary, prompt: "自动生成", axis: .vertical)
                .disabled(state.isBusy)
        }
    }

    // MARK: - Workflow Timeline

    private var workflowTimeline: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 7) {
                Image(systemName: "bolt.circle.fill")
                    .font(.body)  // 13pt
                    .foregroundStyle(DS.brandGradient)
                Text("工作流")
                    .font(.headline)  // 13pt semibold
                    .foregroundStyle(.primary.opacity(0.7))
            }
            .padding(.bottom, 12)

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(WorkflowStep.allCases.enumerated()), id: \.element.id) { index, step in
                    TimelineStepRow(
                        step: step,
                        status: state.stepStatus(step),
                        isLast: index == WorkflowStep.allCases.count - 1
                    )
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: DS.r12)
                    .fill(DS.surfacePrimary)
                    .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.06), radius: 8, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.r12)
                    .stroke(DS.borderDefault, lineWidth: 0.5)
            )
        }
    }

    // MARK: - AI Streaming

    private var aiStreamingOutput: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "waveform")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(DS.brandGradient)
                    .symbolEffect(.variableColor.iterative, options: .repeating)
                Text(state.aiCurrentStep.isEmpty ? "AI 输出" : state.aiCurrentStep)
                    .font(.headline)  // 13pt semibold
                    .foregroundStyle(.secondary)
                Spacer()
                ProgressView()
                    .controlSize(.mini)
            }

            ScrollViewReader { proxy in
                ScrollView {
                    Text(state.aiStreamingText.suffix(1500))
                        .font(.callout.monospaced())  // 12pt
                        .foregroundStyle(.secondary.opacity(0.8))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .id("bottom")
                }
                .frame(maxHeight: 160)
                .background(
                    RoundedRectangle(cornerRadius: DS.r8)
                        .fill(DS.surfaceInput.opacity(0.5))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DS.r8)
                        .stroke(DS.brandGlow.opacity(0.10), lineWidth: 1)
                )
                .onChange(of: state.aiStreamingText) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: DS.r12)
                .fill(DS.surfacePrimary)
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.05), radius: 6, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.r12)
                .stroke(DS.borderDefault, lineWidth: 0.5)
        )
    }

    // MARK: - AI Status Card

    private var aiStatusCard: some View {
        let available = AIService.isAvailable()
        return HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(available ? Color(hex: 0x10B981).opacity(0.12) : Color.orange.opacity(0.12))
                    .frame(width: 32, height: 32)
                Circle()
                    .fill(available ? Color(hex: 0x10B981) : .orange)
                    .frame(width: 8, height: 8)
                    .shadow(color: available ? Color(hex: 0x10B981).opacity(0.5) : .orange.opacity(0.5), radius: 6)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(available ? "Claude AI" : "Claude CLI")
                    .font(.headline)  // 13pt semibold
                    .foregroundStyle(.primary.opacity(0.8))
                Text(available ? "已就绪" : "未安装")
                    .font(.callout)  // 12pt
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            Circle()
                .fill(available ? Color(hex: 0x10B981) : .orange)
                .frame(width: 6, height: 6)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: DS.r10)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.r10)
                .stroke(DS.borderSubtle, lineWidth: 0.5)
        )
    }

    // MARK: - Done Section

    private func doneSection(mediaId: String) -> some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color(hex: 0x10B981).opacity(0.08))
                    .frame(width: 64, height: 64)
                Circle()
                    .fill(Color(hex: 0x10B981).opacity(0.12))
                    .frame(width: 48, height: 48)
                Image(systemName: "checkmark")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(DS.successGradient)
            }

            Text("发布成功！")
                .font(.title2.bold())  // 18pt
                .foregroundStyle(.primary)

            if !mediaId.isEmpty {
                Text(mediaId)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .textSelection(.enabled)
                    .lineLimit(2)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: DS.r6))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: DS.r12)
                .fill(DS.surfacePrimary)
                .shadow(color: Color(hex: 0x10B981).opacity(0.08), radius: 12, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.r12)
                .stroke(Color(hex: 0x10B981).opacity(0.15), lineWidth: 1)
        )
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 10) {
            if state.isReviewing {
                ActionButton(
                    label: "确认发布",
                    icon: "paperplane.fill",
                    style: .brand
                ) {
                    confirmPublish()
                }

                ActionButton(label: "返回编辑", icon: "arrow.uturn.left", style: .ghost) {
                    cancelReview()
                }
            } else if state.isPublishing {
                HStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)
                    Text("正在发布到草稿箱...")
                        .font(.body)  // 13pt
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            } else if case .done = state.workflowState {
                ActionButton(label: "新建文章", icon: "plus.circle.fill", style: .ghost) {
                    resetAll()
                }
            } else if case .failed = state.workflowState {
                ActionButton(label: "重试", icon: "arrow.clockwise", style: .warning) {
                    startWorkflow()
                }
                ActionButton(label: "重置", icon: "xmark", style: .ghost) {
                    state.resetWorkflow()
                }
            } else {
                ActionButton(
                    label: state.isProcessing ? "处理中..." : "开始处理",
                    icon: state.isProcessing ? nil : "wand.and.stars",
                    style: .brand,
                    isLoading: state.isProcessing
                ) {
                    startWorkflow()
                }
                .disabled(state.content.isEmpty || state.isBusy || !state.hasCredentials)
                .help(state.hasCredentials ? "" : "请先在设置中配置微信凭证")
            }
        }
    }

    // MARK: - File Actions

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

    // MARK: - Workflow Execution

    private func startWorkflow() {
        guard !state.content.isEmpty else { return }
        state.workflowState = .processing
        state.stepStatuses = [:]
        state.publishLog = []
        state.originalContent = state.content
        showOriginalContent = false

        Task {
            do {
                var content = state.content
                var title = state.title
                var summary = state.summary

                state.updateStep(.inputDetection, status: .running)
                let format = PublishService.detectInputFormat(content: content, fileURL: droppedFileURL)
                state.inputFormat = format
                state.updateStep(.inputDetection, status: .completed(format.rawValue))

                if format == .html {
                    state.updateStep(.roleAdaptation, status: .skipped("HTML 直接发布"))
                    state.updateStep(.deAI, status: .skipped("HTML 直接发布"))
                    state.updateStep(.themeSelection, status: .skipped("HTML 直接发布"))
                    state.updateStep(.imageGeneration, status: .skipped("HTML 直接发布"))
                    state.processedContent = content
                    state.workflowState = .reviewing
                    return
                }

                if AIService.isAvailable() {
                    state.updateStep(.roleAdaptation, status: .running)
                    state.aiCurrentStep = "角色适配"
                    state.aiStreamingText = ""
                    do {
                        content = try await AIService.adaptRole(
                            content: content, role: state.creatorRole,
                            style: state.writingStyle, audience: state.targetAudience,
                            onStream: { [state] chunk in Task { @MainActor in state.aiStreamingText += chunk } }
                        )
                        state.content = content
                        state.updateStep(.roleAdaptation, status: .completed(
                            "\(state.creatorRole.displayName) · \(state.writingStyle.displayName)"
                        ))
                    } catch {
                        state.updateStep(.roleAdaptation, status: .failed(error.localizedDescription))
                    }

                    state.updateStep(.deAI, status: .running)
                    state.aiCurrentStep = "去 AI 味"
                    state.aiStreamingText = ""
                    do {
                        let deAIResult = try await AIService.deAI(
                            content: content, writingStyle: state.writingStyle,
                            onStream: { [state] chunk in Task { @MainActor in state.aiStreamingText += chunk } }
                        )
                        content = deAIResult.content
                        state.content = content
                        state.deAIScore = deAIResult.score
                        state.deAIRating = deAIResult.rating
                        let scoreText = deAIResult.score.map { "\($0)/50" } ?? ""
                        let ratingText = deAIResult.rating ?? ""
                        state.updateStep(.deAI, status: .completed(
                            [scoreText, ratingText].filter { !$0.isEmpty }.joined(separator: " ")
                        ))
                    } catch {
                        state.updateStep(.deAI, status: .failed(error.localizedDescription))
                    }

                    if title.isEmpty {
                        title = try await AIService.generateTitle(content: content)
                        state.title = title
                    }
                    if summary.isEmpty {
                        summary = try await AIService.generateSummary(content: content, title: title)
                        state.summary = summary
                    }

                    state.updateStep(.themeSelection, status: .running)
                    do {
                        let themeResult = try await AIService.selectTheme(content: content, role: state.creatorRole)
                        state.selectedTheme = themeResult.theme
                        state.selectedColor = themeResult.color
                        state.updateStep(.themeSelection, status: .completed(
                            "\(themeResult.theme.displayName) · \(themeResult.color.rawValue)"
                        ))
                    } catch {
                        state.updateStep(.themeSelection, status: .failed(error.localizedDescription))
                    }

                    if !state.imageApiKey.isEmpty {
                        state.updateStep(.imageGeneration, status: .running)
                        do {
                            let images = try await AIService.analyzeImages(content: content, title: title)
                            if images.isEmpty {
                                state.updateStep(.imageGeneration, status: .completed("无需插图"))
                            } else {
                                content = PublishService.insertImagePlaceholders(content: content, images: images)
                                state.content = content
                                state.updateStep(.imageGeneration, status: .completed("已插入 \(images.count) 张配图提示"))
                            }
                        } catch {
                            state.updateStep(.imageGeneration, status: .failed(error.localizedDescription))
                        }
                    } else {
                        state.updateStep(.imageGeneration, status: .skipped("未配置 IMAGE_API_KEY"))
                    }
                } else {
                    state.updateStep(.roleAdaptation, status: .skipped("Claude CLI 未安装"))
                    state.updateStep(.deAI, status: .skipped("Claude CLI 未安装"))
                    state.updateStep(.themeSelection, status: .skipped("Claude CLI 未安装"))
                    state.updateStep(.imageGeneration, status: .skipped("Claude CLI 未安装"))
                }

                state.aiStreamingText = ""
                state.aiCurrentStep = ""
                state.processedContent = content
                state.updateStep(.publishing, status: .pending)
                state.workflowState = .reviewing
            } catch {
                state.workflowState = .failed(error.localizedDescription)
                publishError = error.localizedDescription
            }
        }
    }

    private func confirmPublish() {
        state.workflowState = .publishing
        state.updateStep(.publishing, status: .running)
        Task {
            do {
                let content = state.content
                let title = state.title
                let summary = state.summary
                let format = state.inputFormat

                let filePath: String
                if format == .html {
                    let dir = "/tmp/postwx/\(formattedDate())"
                    try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
                    filePath = "\(dir)/\(PublishService.generateSlug(from: title)).html"
                    try? content.write(toFile: filePath, atomically: true, encoding: .utf8)
                } else {
                    filePath = PublishService.saveTempMarkdown(content: content, title: title)
                }

                let credentials = PublishService.Credentials(
                    wechatAppId: state.wechatAppId, wechatAppSecret: state.wechatAppSecret,
                    imageApiBase: state.imageApiBase, imageApiKey: state.imageApiKey,
                    imageModel: state.imageModel
                )

                let result = try await PublishService.publish(
                    filePath: filePath, theme: state.selectedTheme, color: state.selectedColor,
                    title: title.isEmpty ? nil : title, summary: summary.isEmpty ? nil : summary,
                    author: state.author.isEmpty ? nil : state.author, credentials: credentials,
                    onLog: { log in Task { @MainActor in state.publishLog.append(log) } }
                )

                var mediaId = ""
                if let data = result.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let mid = json["media_id"] as? String { mediaId = mid }

                state.updateStep(.publishing, status: .completed("已发布"))
                state.workflowState = .done(mediaId)
            } catch {
                state.updateStep(.publishing, status: .failed(error.localizedDescription))
                state.workflowState = .failed(error.localizedDescription)
                publishError = error.localizedDescription
            }
        }
    }

    private func cancelReview() {
        state.content = state.originalContent
        state.resetWorkflow()
    }

    private func resetAll() {
        state.content = ""
        state.title = ""
        state.summary = ""
        let fallback = state.defaultAuthor.isEmpty ? state.username : state.defaultAuthor
        state.author = fallback
        droppedFileURL = nil
        showOriginalContent = false
        state.resetWorkflow()
    }

    private func formattedDate() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
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
        if state.author.isEmpty {
            let fallbackAuthor = state.defaultAuthor.isEmpty ? state.username : state.defaultAuthor
            if !fallbackAuthor.isEmpty { state.author = fallbackAuthor }
        }
        if let role = defaults.string(forKey: "creatorRole"), let r = CreatorRole(rawValue: role) { state.creatorRole = r }
        if let style = defaults.string(forKey: "writingStyle"), let s = WritingStyle(rawValue: style) { state.writingStyle = s }
        if let audience = defaults.string(forKey: "targetAudience"), let a = TargetAudience(rawValue: audience) { state.targetAudience = a }
    }
}

// MARK: - Timeline Step Row

struct TimelineStepRow: View {
    let step: WorkflowStep
    let status: StepStatus
    var isLast: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                stepIndicator
                    .frame(width: 28, height: 28)
                if !isLast {
                    Rectangle()
                        .fill(lineColor)
                        .frame(width: 2, height: 16)
                        .clipShape(Capsule())
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Image(systemName: step.icon)
                        .font(.subheadline)  // 11pt
                        .foregroundStyle(iconTint)
                    Text(step.label)
                        .font(status == .running ? .headline : .body)  // 13pt semibold / 13pt regular
                        .foregroundStyle(textColor)
                }

                switch status {
                case .completed(let detail):
                    if !detail.isEmpty {
                        Text(detail)
                            .font(.subheadline)  // 11pt
                            .foregroundStyle(Color(hex: 0x10B981))
                            .lineLimit(1)
                    }
                case .failed(let msg):
                    Text(msg)
                        .font(.subheadline)  // 11pt
                        .foregroundStyle(Color(hex: 0xEF4444))
                        .lineLimit(2)
                case .skipped(let reason):
                    Text(reason)
                        .font(.subheadline)  // 11pt
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                case .running:
                    Text("处理中...")
                        .font(.subheadline.weight(.medium))  // 11pt
                        .foregroundStyle(DS.brandGlow.opacity(0.8))
                default:
                    EmptyView()
                }
            }
            .padding(.bottom, isLast ? 0 : 2)

            Spacer()
        }
        .animation(.spring(duration: 0.4), value: status)
    }

    @ViewBuilder
    private var stepIndicator: some View {
        switch status {
        case .pending:
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.15), lineWidth: 1.5)
                    .frame(width: 22, height: 22)
                Text("\(step.rawValue)")
                    .font(.footnote.bold())  // 10pt bold
                    .foregroundStyle(.quaternary)
            }
        case .running:
            ZStack {
                Circle()
                    .fill(DS.brandGlow.opacity(0.10))
                    .frame(width: 24, height: 24)
                Circle()
                    .stroke(DS.brandGlow.opacity(0.3), lineWidth: 1.5)
                    .frame(width: 24, height: 24)
                ProgressView()
                    .controlSize(.mini)
            }
        case .completed:
            ZStack {
                Circle()
                    .fill(Color(hex: 0x10B981).opacity(0.12))
                    .frame(width: 24, height: 24)
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color(hex: 0x10B981))
            }
        case .skipped:
            ZStack {
                Circle()
                    .fill(Color.secondary.opacity(0.06))
                    .frame(width: 24, height: 24)
                Image(systemName: "forward.fill")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.quaternary)
            }
        case .failed:
            ZStack {
                Circle()
                    .fill(Color(hex: 0xEF4444).opacity(0.12))
                    .frame(width: 24, height: 24)
                Image(systemName: "exclamationmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color(hex: 0xEF4444))
            }
        }
    }

    private var lineColor: Color {
        switch status {
        case .completed: Color(hex: 0x10B981).opacity(0.25)
        case .running: DS.brandGlow.opacity(0.20)
        case .failed: Color(hex: 0xEF4444).opacity(0.20)
        default: Color.secondary.opacity(0.10)
        }
    }

    private var iconTint: Color {
        switch status {
        case .running: DS.brandGlow
        case .completed: Color(hex: 0x10B981)
        case .failed: Color(hex: 0xEF4444)
        case .skipped: .secondary
        default: Color.secondary.opacity(0.4)
        }
    }

    private var textColor: Color {
        switch status {
        case .pending: .secondary.opacity(0.6)
        case .running, .completed, .failed: .primary
        case .skipped: .secondary
        }
    }
}

// MARK: - Reusable Components

struct LiveStatusBadge: View {
    let label: String
    let icon: String
    let color: Color
    var isAnimated: Bool = false

    @State private var isPulsing = false

    var body: some View {
        HStack(spacing: 6) {
            ZStack {
                if isAnimated {
                    Circle()
                        .fill(color.opacity(0.3))
                        .frame(width: 14, height: 14)
                        .scaleEffect(isPulsing ? 1.4 : 1.0)
                        .opacity(isPulsing ? 0 : 1)
                        .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: false), value: isPulsing)
                }
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
                    .shadow(color: color.opacity(0.5), radius: 4)
            }
            .frame(width: 14, height: 14)

            Image(systemName: icon)
                .font(.subheadline.bold())  // 11pt
            Text(label)
                .font(.headline)  // 13pt semibold
        }
        .foregroundStyle(color)
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(color.opacity(0.08), in: Capsule())
        .overlay(Capsule().stroke(color.opacity(0.15), lineWidth: 0.5))
        .onAppear { isPulsing = true }
    }
}

struct IconButton: View {
    let icon: String
    var size: ButtonSize = .regular
    let action: () -> Void
    @State private var isHovered = false

    enum ButtonSize {
        case small, regular
        var dimension: CGFloat { self == .small ? 24 : 32 }
        var font: CGFloat { self == .small ? 10 : 12 }
        var radius: CGFloat { self == .small ? 5 : 7 }
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size.font, weight: .medium))
                .foregroundStyle(isHovered ? .primary : .secondary)
                .frame(width: size.dimension, height: size.dimension)
                .background(
                    RoundedRectangle(cornerRadius: size.radius)
                        .fill(isHovered ? Color.primary.opacity(0.08) : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

struct PillButton: View {
    let icon: String
    let label: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(isHovered ? .primary : .secondary)
            .padding(.horizontal, 13)
            .padding(.vertical, 7)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().stroke(Color.primary.opacity(isHovered ? 0.12 : 0.06), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

struct InputField: View {
    let label: String
    let icon: String
    @Binding var text: String
    var prompt: String = ""
    var axis: Axis = .horizontal

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.subheadline)  // 11pt
                    .foregroundStyle(.tertiary)
                Text(label)
                    .font(.headline)  // 13pt semibold
                    .foregroundStyle(.secondary)
            }
            TextField(prompt, text: $text, axis: axis)
                .textFieldStyle(.plain)
                .font(.body)  // 13pt — macOS standard
                .focused($isFocused)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: DS.r8)
                        .fill(DS.surfaceInput)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DS.r8)
                        .stroke(isFocused ? DS.borderActive : DS.borderDefault, lineWidth: isFocused ? 1.5 : 0.5)
                )
                .animation(.easeOut(duration: 0.15), value: isFocused)
        }
    }
}

struct ScoreBadge: View {
    let score: Int
    private var color: Color {
        score >= 45 ? Color(hex: 0x10B981) : score >= 35 ? .orange : Color(hex: 0xEF4444)
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "shield.checkered")
                .font(.subheadline)  // 11pt
            Text("\(score)/50")
                .font(.subheadline.bold().monospacedDigit())  // 11pt bold
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(color.opacity(0.10), in: Capsule())
    }
}

struct ActionButton: View {
    let label: String
    var icon: String?
    var style: Style = .brand
    var isLoading: Bool = false
    var action: () -> Void
    @State private var isHovered = false

    enum Style {
        case brand, warning, ghost
    }

    private var gradient: LinearGradient {
        switch style {
        case .brand: DS.brandGradient
        case .warning: DS.warningGradient
        case .ghost: LinearGradient(colors: [.clear], startPoint: .leading, endPoint: .trailing)
        }
    }

    private var glowColor: Color {
        switch style {
        case .brand: DS.brandGlow
        case .warning: Color(hex: 0xF59E0B)
        case .ghost: .clear
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .tint(style == .ghost ? .primary : .white)
                } else if let icon {
                    Image(systemName: icon)
                        .font(.body.weight(.semibold))  // 13pt
                }
                Text(label)
                    .font(.headline)  // 13pt semibold
            }
            .foregroundStyle(style == .ghost ? Color.primary.opacity(0.7) : Color.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: DS.r10)
                    .fill(style == .ghost ? AnyShapeStyle(Color.primary.opacity(isHovered ? 0.08 : 0.04)) : AnyShapeStyle(gradient))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.r10)
                    .stroke(style == .ghost ? Color.primary.opacity(0.08) : Color.clear, lineWidth: 0.5)
            )
            .shadow(color: glowColor.opacity(isHovered ? 0.3 : 0.15), radius: isHovered ? 12 : 6, y: isHovered ? 4 : 2)
            .scaleEffect(isHovered ? 1.01 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.15), value: isHovered)
    }
}
