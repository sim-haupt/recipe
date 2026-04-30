import Foundation
import SwiftUI

@main
struct WeCookinApp: App {
    private let environment: AppEnvironment
    @StateObject private var sessionViewModel: SessionViewModel

    init() {
        let environment = Self.makeEnvironment()
        self.environment = environment
        _sessionViewModel = StateObject(wrappedValue: SessionViewModel(environment: environment))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(sessionViewModel)
                .environment(\.appEnvironment, environment)
        }
    }

    private static func makeEnvironment() -> AppEnvironment {
        guard Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil else {
            return .demo
        }

        configureFirebaseIfAvailable()

        return .live
    }

    private static func configureFirebaseIfAvailable() {
        let appClass: AnyObject? = NSClassFromString("FIRApp")
        let defaultAppSelector = NSSelectorFromString("defaultApp")
        let configureSelector = NSSelectorFromString("configure")

        guard let appClass else { return }
        let existingApp = appClass.perform(defaultAppSelector)
        if existingApp?.takeUnretainedValue() == nil {
            _ = appClass.perform(configureSelector)
        }
    }
}
