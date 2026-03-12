import SwiftUI
import AppKit

/// SPM 构建的 macOS 应用默认以 accessory（后台）模式启动，
/// 必须通过 NSApplicationDelegate 将激活策略设为 .regular，
/// 否则窗口无法获得键盘焦点，TextField 无法输入。
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}

@main
struct PostwxApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var showSettings = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 600, minHeight: 500)
                .sheet(isPresented: $showSettings) {
                    SettingsView()
                }
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 700, height: 560)
        .commands {
            // 标准 Edit 菜单 — 没有这个，TextField 无法接收键盘输入
            CommandGroup(replacing: .textEditing) {
                Button("剪切") { NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: nil) }
                    .keyboardShortcut("x")
                Button("拷贝") { NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: nil) }
                    .keyboardShortcut("c")
                Button("粘贴") { NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: nil) }
                    .keyboardShortcut("v")
                Button("全选") { NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil) }
                    .keyboardShortcut("a")
            }
            CommandGroup(replacing: .undoRedo) {
                Button("撤销") { NSApp.sendAction(Selector(("undo:")), to: nil, from: nil) }
                    .keyboardShortcut("z")
                Button("重做") { NSApp.sendAction(Selector(("redo:")), to: nil, from: nil) }
                    .keyboardShortcut("z", modifiers: [.command, .shift])
            }
            CommandGroup(after: .appSettings) {
                Button("偏好设置...") { showSettings = true }
                    .keyboardShortcut(",", modifiers: .command)
            }
        }

        Settings {
            SettingsView()
        }
    }
}
