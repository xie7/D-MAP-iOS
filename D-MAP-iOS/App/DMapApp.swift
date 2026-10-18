import SwiftUI

@main
struct DMapApp: App {
    @StateObject private var viewModel = DeviceViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .preferredColorScheme(.dark)
        }
    }
}
