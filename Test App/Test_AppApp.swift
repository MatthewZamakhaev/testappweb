import SwiftUI

@main
struct Test_AppApp: App {

    @StateObject var viewModel = AppViewModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(viewModel)
        }
    }
}
