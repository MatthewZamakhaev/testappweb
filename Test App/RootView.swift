import SwiftUI

struct RootView: View {

    @EnvironmentObject var vm: AppViewModel

    var body: some View {
        if let url = vm.webURL {
            WebScreen(startUrl: url)
                .statusBarHidden(true)
        }
    }
}
