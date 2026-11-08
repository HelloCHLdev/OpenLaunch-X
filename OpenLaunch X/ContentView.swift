//
//  ContentView.swift
//  OpenLaunch X
//
//  Created by lijf on 2026/11/8.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        // 内容暂时留空，只保留一层半透明毛玻璃底板
        Rectangle()
            .fill(.regularMaterial)
            .ignoresSafeArea()
            // 关掉 SwiftUI 默认的窗口底色，露出我们自己的材质层
            .containerBackground(.clear, for: .window)
            .background {
                // 隐藏标题栏与红黄绿按钮 + 窗口半透明 + 自动铺满可用区域
                WindowChrome()
            }
    }
}

#if DEBUG
// 用 PreviewProvider 而不是 #Preview 宏：宏需要 swift-plugin-server，
// 命令行构建时该插件在部分环境里起不来
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
#endif
