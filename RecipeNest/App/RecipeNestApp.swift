import FirebaseCore
import SwiftUI

@main
struct RecipeNestApp: App {
    @StateObject private var sessionViewModel = SessionViewModel(environment: .live)

    init() {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(sessionViewModel)
                .environment(\.appEnvironment, .live)
        }
    }
}
