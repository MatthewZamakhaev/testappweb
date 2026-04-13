import SwiftUI

class WebStorage {
    private static let lastUrlKey = "last_web_url"

    static func save(url: String) {
        UserDefaults.standard.set(url, forKey: lastUrlKey)
    }

    static func get() -> String? {
        UserDefaults.standard.string(forKey: lastUrlKey)
    }
}
