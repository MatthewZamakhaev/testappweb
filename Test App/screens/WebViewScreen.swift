import SwiftUI
import WebKit
import UserNotifications

struct WebScreen: View {

    let startUrl: String

    var body: some View {
        WebViewContainer(url: startUrl)
            .ignoresSafeArea()
            .onAppear {
                requestPushIfNeeded()
            }
    }

    private func requestPushIfNeeded() {

        if StorageManager.shared.permissionRequested {
            return
        }

        StorageManager.shared.permissionRequested = true

        UNUserNotificationCenter.current().getNotificationSettings { settings in

            guard settings.authorizationStatus == .notDetermined else {
                return
            }

            UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .sound, .badge]
            ) { _, _ in
            }
        }
    }
}
