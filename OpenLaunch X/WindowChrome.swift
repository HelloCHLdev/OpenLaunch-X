//
//  WindowChrome.swift
//  OpenLaunch X
//
//  隐藏 macOS 窗口标题栏（含红 / 黄 / 绿三个系统按钮）+ 窗口半透明背板
//

import SwiftUI
import AppKit
import QuartzCore

// MARK: - 标题栏隐藏方式

/// 隐藏标题栏的两种策略
enum TitleBarStyle {
    /// 保留系统窗口圆角与阴影，只隐藏标题文字和红黄绿三个按钮
    /// （最稳妥，系统仍按标准窗口绘制）
    case hideButtons

    /// 彻底摘掉标题栏本体：styleMask 去掉 .titled，窗口变成无边框
    /// （视觉上最彻底，但窗口失去系统标题栏带来的圆角/阴影）
    case borderless
}

// MARK: - 窗口背板
/// 窗口背景（背板）样式
enum WindowBackdrop {
    /// 保留系统默认材质（标准窗口那种淡毛玻璃）
    case system

    /// 窗口本体完全透明，材质完全交给内容层绘制
    /// 做启动台那种大面板时用它：避免系统材质 + 自定义材质两层叠加导致发灰
    case clear
}

// MARK: - 入场动画

/// 窗口入场动画
enum WindowEntrance {
    /// 不做入场动画
    case none

    /// 窗口整体渐显（alpha 0 → 1）
    case fadeIn(duration: TimeInterval)

    /// 渐显 + 轻微放大（启动台「从中心打开」的感觉）
    case fadeInAndScale(duration: TimeInterval)
}

// MARK: - WindowChrome

/// SwiftUI → NSWindow 的桥接视图，用来隐藏标题栏与红绿灯、设置半透明背板。
///
/// 用法：挂在任意视图的 `.background` 上即可
/// ```swift
/// ContentView()
///     .background { WindowChrome() }
/// ```
struct WindowChrome: NSViewRepresentable {

    /// 标题栏隐藏方式，默认 `.hideButtons`
    var style: TitleBarStyle = .hideButtons

    /// 窗口背板，默认 `.clear`（窗口透明，材质由内容层提供）
    var backdrop: WindowBackdrop = .clear

    /// 标题栏消失后没有拖拽把手，这里允许拖动窗口背景来移动窗口
    var isMovableByBackground: Bool = false

    /// 启动时自动铺满「菜单栏 ↔ Dock」之间的可用区域
    var fillsScreenArea: Bool = true

    /// 入场动画，默认 2 秒渐显
    var entrance: WindowEntrance = .fadeIn(duration: 2)

    /// 关闭后不释放窗口对象（启动台这类常驻 App 建议开启）
    var keepsAliveOnClose: Bool = true

    func makeNSView(context: Context) -> NSView {
        let host = ChromeHostView(frame: .zero)
        host.options = self
        return host
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let host = nsView as? ChromeHostView else { return }
        host.options = self
        host.applyIfPossible()
    }
}

// MARK: - 配置实现

extension WindowChrome {

    /// 真正作用于 NSWindow 的配置
    func apply(to window: NSWindow?) {
        guard let window else { return }

        // 1. 标题栏本体：透明化 + 不显示标题文字
        window.title = ""
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true

        // 2. 红 / 黄 / 绿三个系统按钮
        switch style {
        case .hideButtons:
            Self.hideStandardButtons(of: window)
        case .borderless:
            window.styleMask.remove(.titled)
            Self.hideStandardButtons(of: window)
        }

        // 3. 背板
        switch backdrop {
        case .system:
            window.isOpaque = false
            window.backgroundColor = .clear
        case .clear:
            // 透明窗口：材质完全由内容层的 Material / glassEffect 提供
            window.isOpaque = false
            window.backgroundColor = .clear
            Self.hideThemeFrameMaterial(of: window)
        }
        window.hasShadow = true

        // 4. 隐藏标题栏后只能靠背景拖拽移动窗口
        window.isMovable = isMovableByBackground
        window.isMovableByWindowBackground = isMovableByBackground

        // 5. 常驻 App：关闭后不销毁窗口
        window.isReleasedWhenClosed = !keepsAliveOnClose

        // 6. 铺满「菜单栏 ↔ Dock」之间的区域
        if fillsScreenArea {
            window.styleMask.remove(.resizable)
            Self.fillScreenArea(of: window)
            // SwiftUI 可能在首次布局后再改一次 frame，这里补一次
            DispatchQueue.main.async {
                Self.fillScreenArea(of: window)
            }
        }
    }

    /// 隐藏窗口左上角的红、黄、绿按钮
    private static func hideStandardButtons(of window: NSWindow) {
        let buttons = [
            window.standardWindowButton(.closeButton),
            window.standardWindowButton(.miniaturizeButton),
            window.standardWindowButton(.zoomButton)
        ]
        for button in buttons {
            button?.isHidden = true
            button?.alphaValue = 0
        }
    }

    /// 移除系统主题框架自带的那层 NSVisualEffectView。
    /// 它是标准窗口的默认毛玻璃底，留着会和内容层的材质叠加成两层、发灰。
    private static func hideThemeFrameMaterial(of window: NSWindow) {
        guard let themeFrame = window.contentView?.superview else { return }
        for subview in themeFrame.subviews where subview is NSVisualEffectView {
            subview.isHidden = true
        }
    }

    /// 把窗口铺满「菜单栏 ↔ Dock」之间的可用区域（visibleFrame）。
    /// 多屏时取鼠标所在的那块屏幕。
    private static func fillScreenArea(of window: NSWindow) {
        guard let screen = targetScreen() else { return }
        let frame = screen.visibleFrame
        guard abs(window.frame.origin.x - frame.origin.x) > 0.5
                || abs(window.frame.origin.y - frame.origin.y) > 0.5
                || abs(window.frame.size.width - frame.size.width) > 0.5
                || abs(window.frame.size.height - frame.size.height) > 0.5
        else { return }
        window.setFrame(frame, display: true)
    }

    /// 鼠标所在屏幕 → 键盘主屏 → 第一块屏幕
    private static func targetScreen() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        if let screen = NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) }) {
            return screen
        }
        return NSScreen.main ?? NSScreen.screens.first
    }
}

// MARK: - ChromeHostView

/// 承载配置逻辑的宿主视图：等它真正挂进 NSWindow 之后再做窗口改造，
/// 避免 SwiftUI 视图生命周期早于窗口创建时拿不到 NSWindow。
final class ChromeHostView: NSView {

    var options: WindowChrome? {
        didSet { applyIfPossible() }
    }

    /// 入场动画只播一次
    private var hasPlayedEntrance = false

    /// 待播放的入场动画
    private var pendingAnimation: ((NSWindow) -> Void)?
    private var pendingDuration: TimeInterval = 2
    private var pendingWindow: NSWindow?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        applyIfPossible()
    }

    /// 窗口成为 key 时补一次配置，防止系统重建按钮导致红绿灯复现
    override func viewWillMove(toWindow newWindow: NSWindow?) {
        super.viewWillMove(toWindow: newWindow)
        guard let newWindow else { return }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidBecomeKey),
            name: NSWindow.didBecomeKeyNotification,
            object: newWindow
        )
    }

    @objc private func windowDidBecomeKey() {
        applyIfPossible()
        // 窗口上屏后立刻开始入场动画
        if let window, pendingAnimation != nil {
            runPendingAnimation(on: window)
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func applyIfPossible() {
        options?.apply(to: window)
        playEntranceIfNeeded()
    }

    // MARK: - 入场动画

    /// 播放窗口入场动画（渐显 2 秒）
    private func playEntranceIfNeeded() {
        guard !hasPlayedEntrance, let window else { return }
        guard let entrance = options?.entrance else { return }
        hasPlayedEntrance = true

        switch entrance {
        case .none:
            window.alphaValue = 1
        case .fadeIn(let duration):
            window.alphaValue = 0
            startAnimation(on: window, duration: duration) { $0.animator().alphaValue = 1 }
        case .fadeInAndScale(let duration):
            window.alphaValue = 0
            let target = window.frame
            window.setFrame(target.insetBy(dx: target.width * 0.06, dy: target.height * 0.06), display: false)
            startAnimation(on: window, duration: duration) { window in
                window.animator().alphaValue = 1
                window.animator().setFrame(target, display: true)
            }
        }
    }

    /// 等窗口真正上屏后再开始动画，避免动画还没播完窗口就被系统重置
    private func startAnimation(on window: NSWindow,
                                duration: TimeInterval,
                                _ changes: @escaping (NSWindow) -> Void) {
        pendingAnimation = changes
        pendingDuration = duration

        if window.isVisible {
            DispatchQueue.main.async { [weak self] in
                self?.runPendingAnimation(on: window)
            }
        } else {
            // 窗口还没上屏：等它成为 key（上屏后必然成为 key）再开始动画
            pendingWindow = window
            // 兜底：0.5 秒后无论如何都把动画放出去，避免动画丢失
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self, let window = self.pendingWindow else { return }
                self.runPendingAnimation(on: window)
            }
        }
    }

    private func runPendingAnimation(on window: NSWindow) {
        guard let changes = pendingAnimation else { return }
        pendingAnimation = nil
        pendingWindow = nil

        NSAnimationContext.runAnimationGroup { context in
            context.duration = pendingDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            context.allowsImplicitAnimation = true
            changes(window)
        }
    }

    /// 只是背景层，不拦截鼠标事件
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
