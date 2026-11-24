import SwiftUI

@main
struct DMapApp: App {
    @StateObject private var viewModel = DeviceViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                // 安卓原版 D-MAP 为亮色蓝系界面，固定亮色以保持一致
                .preferredColorScheme(.light)
        }
    }
}
