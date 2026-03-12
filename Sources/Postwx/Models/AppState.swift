import SwiftUI

@Observable
final class AppState {
    var content: String = ""
    var title: String = ""
    var author: String = ""
    var summary: String = ""

    var selectedTheme: Theme = .default_
    var selectedColor: ThemeColor = .blue

    var isPublishing = false
    var publishProgress: PublishStep = .idle
    var publishLog: [String] = []

    // MARK: - Credentials

    var wechatAppId: String = ""
    var wechatAppSecret: String = ""
    var imageApiBase: String = ""
    var imageApiKey: String = ""
    var imageModel: String = ""
    var claudeApiBase: String = ""
    var claudeApiKey: String = ""
    var claudeModel: String = ""

    // MARK: - Preferences

    var creatorRole: CreatorRole = .techBlogger
    var writingStyle: WritingStyle = .professional
    var targetAudience: TargetAudience = .general
    var username: String = ""
    var defaultAuthor: String = ""
    var needOpenComment: Bool = true
    var onlyFansCanComment: Bool = false

    var hasCredentials: Bool {
        !wechatAppId.isEmpty && !wechatAppSecret.isEmpty
    }
}

// MARK: - Enums

enum Theme: String, CaseIterable, Identifiable {
    case default_ = "default"
    case grace
    case simple
    case modern

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .default_: "Default"
        case .grace: "Grace"
        case .simple: "Simple"
        case .modern: "Modern"
        }
    }
}

enum ThemeColor: String, CaseIterable, Identifiable {
    case blue, green, vermilion, yellow, purple
    case sky, rose, olive, black, gray
    case pink, red, orange

    var id: String { rawValue }
}

enum CreatorRole: String, CaseIterable, Identifiable {
    case techBlogger = "tech-blogger"
    case lifestyleWriter = "lifestyle-writer"
    case educator
    case businessAnalyst = "business-analyst"

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .techBlogger: "技术博主"
        case .lifestyleWriter: "生活作者"
        case .educator: "教育者"
        case .businessAnalyst: "商业分析"
        }
    }
}

enum WritingStyle: String, CaseIterable, Identifiable {
    case professional, casual, humorous, academic

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .professional: "专业"
        case .casual: "随性"
        case .humorous: "幽默"
        case .academic: "学术"
        }
    }
}

enum TargetAudience: String, CaseIterable, Identifiable {
    case general, industry, students
    case techCommunity = "tech-community"

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .general: "大众"
        case .industry: "行业人士"
        case .students: "学生"
        case .techCommunity: "技术社区"
        }
    }
}

enum PublishStep: String {
    case idle = "就绪"
    case loadingPrefs = "加载配置..."
    case detectingInput = "检测输入..."
    case adaptingRole = "角色适配..."
    case deAI = "去 AI 味..."
    case selectingTheme = "选择主题..."
    case generatingImages = "生成配图..."
    case publishing = "发布中..."
    case done = "完成"
    case failed = "失败"
}
