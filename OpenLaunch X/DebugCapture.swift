//
//  DebugCapture.swift
//  OpenLaunch X
//
//  临时调试代码：把窗口（含标题栏）渲染成 PNG，并导出标题栏状态日志
//

#if DEBUG
import AppKit

enum DebugCapture {

    static func run(window: NSWindow) {
        // 采样 alpha，验证渐显动画
        var samples: [String] = []
        for delay in [0.05, 0.5, 1.0, 1.5, 2.2, 2.6] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                samples.append(String(format: "t=%.2f alpha=%.3f", delay, window.alphaValue))
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            var lines: [String] = []
            lines.append("styleMask raw = \(window.styleMask.rawValue)")
            lines.append("contains(.titled) = \(window.styleMask.contains(.titled))")
            lines.append("titleVisibility = \(window.titleVisibility.rawValue)")
            lines.append("titlebarAppearsTransparent = \(window.titlebarAppearsTransparent)")
            lines.append("frame = \(window.frame)")
            lines.append("isOpaque = \(window.isOpaque)")
            lines.append("backgroundColor = \(String(describing: window.backgroundColor))")
            lines.append("hasShadow = \(window.hasShadow)")
            if let screen = window.screen {
                lines.append("screen visibleFrame = \(screen.visibleFrame)")
                lines.append("screen frame = \(screen.frame)")
            }

            let buttons: [(String, NSButton?)] = [
                ("close", window.standardWindowButton(.closeButton)),
                ("mini", window.standardWindowButton(.miniaturizeButton)),
                ("zoom", window.standardWindowButton(.zoomButton))
            ]
            for (name, button) in buttons {
                guard let button else {
                    lines.append("\(name): nil")
                    continue
                }
                lines.append("\(name): isHidden=\(button.isHidden) alpha=\(button.alphaValue) frame=\(button.frame) superview=\(String(describing: button.superview?.className))")
            }

            // 记录 titlebar 容器视图的子视图结构
            if let themeFrame = window.contentView?.superview {
                lines.append("--- frameView hierarchy: \(themeFrame.className) ---")
                dumpHierarchy(themeFrame, depth: 0, into: &lines)
            }

            let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]

            // 1) 整窗渲染（包含标题栏区域）
            if let themeFrame = window.contentView?.superview,
               let rep = themeFrame.bitmapImageRepForCachingDisplay(in: themeFrame.bounds) {
                themeFrame.cacheDisplay(in: themeFrame.bounds, to: rep)
                if let data = rep.representation(using: .png, properties: [:]) {
                    try? data.write(to: dir.appendingPathComponent("window_full.png"))
                }
                // 2) 左上角 260x60 放大区域：专门看红绿灯
                let cropRect = NSRect(x: 0, y: themeFrame.bounds.height - 60, width: 260, height: 60)
                if let crop = rep.cgImage?.cropping(to: CGRect(x: 0, y: 0, width: 260, height: 60)) {
                    let bitmap = NSBitmapImageRep(cgImage: crop)
                    if let data = bitmap.representation(using: .png, properties: [:]) {
                        try? data.write(to: dir.appendingPathComponent("window_topleft.png"))
                    }
                }
                _ = cropRect
            }

            try? lines.joined(separator: "\n")
                .write(to: dir.appendingPathComponent("titlelog.txt"), atomically: true, encoding: .utf8)
            try? samples.joined(separator: "\n")
                .write(to: dir.appendingPathComponent("alpha.txt"), atomically: true, encoding: .utf8)
        }
    }

    private static func dumpHierarchy(_ view: NSView, depth: Int, into lines: inout [String]) {
        let indent = String(repeating: "  ", count: depth)
        lines.append("\(indent)\(view.className) frame=\(view.frame) hidden=\(view.isHidden) alpha=\(view.alphaValue)")
        if depth > 3 { return }
        for sub in view.subviews {
            dumpHierarchy(sub, depth: depth + 1, into: &lines)
        }
    }
}
#endif
