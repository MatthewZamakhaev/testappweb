import Foundation

class StorageManager {

    static let shared = StorageManager()

    private let permissionRequestedKey = "permission_requested"

    var permissionRequested: Bool {
        get { UserDefaults.standard.bool(forKey: permissionRequestedKey) }
        set { UserDefaults.standard.set(newValue, forKey: permissionRequestedKey) }
    }
}
