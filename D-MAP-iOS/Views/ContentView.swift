import SwiftUI

/// 主视图 - 标签栏导航
struct ContentView: View {
    @EnvironmentObject var viewModel: DeviceViewModel

    var body: some View {
        TabView {
            DeviceView()
                .tabItem {
                    Label("设备", systemImage: "watchface.applewatch.case")
                }

            AlarmView()
                .tabItem {
                    Label("闹钟", systemImage: "alarm.fill")
                }

            CameraView()
                .tabItem {
                    Label("拍照", systemImage: "camera.fill")
                }

            SettingsView()
                .tabItem {
                    Label("设置", systemImage: "gearshape.fill")
                }
        }
        .tint(.blue)
    }
}

#Preview {
    ContentView()
        .environmentObject(DeviceViewModel())
}
