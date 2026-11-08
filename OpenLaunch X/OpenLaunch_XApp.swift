//
//  OpenLaunch_XApp.swift
//  OpenLaunch X
//
//  Created by lijf on 2026/11/8.
//

import SwiftUI

@main
struct OpenLaunch_XApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        // 隐藏标题栏：SwiftUI 层面让内容延伸至窗口顶部，
        // 红黄绿按钮则由 ContentView 里的 WindowChrome 处理
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 900, height: 560)
    }
}
