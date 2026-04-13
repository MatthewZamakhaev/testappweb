import SwiftUI
import Combine

enum AppState {
    case web
}

class AppViewModel: ObservableObject {

    @Published var appState: AppState = .web
    @Published var webURL: String? = "https://browserjunkie.marlerino-apps.io/"
}
