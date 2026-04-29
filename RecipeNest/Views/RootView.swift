import SwiftUI

struct RootView: View {
    @EnvironmentObject private var sessionViewModel: SessionViewModel
    @Environment(\.appEnvironment) private var environment

    var body: some View {
        Group {
            if sessionViewModel.isLoading {
                ProgressView("Loading your recipe box...")
            } else if sessionViewModel.session == nil {
                AuthView()
            } else if let userProfile = sessionViewModel.userProfile {
                if userProfile.activeHouseholdID == nil {
                    HouseholdOnboardingView(userProfile: userProfile, environment: environment)
                } else {
                    HomeView(userProfile: userProfile, environment: environment)
                }
            } else {
                ProgressView("Preparing your account...")
                    .task {
                        await sessionViewModel.refreshUserProfile()
                    }
            }
        }
        .background(RecipeTheme.background.ignoresSafeArea())
        .tint(RecipeTheme.accent)
        .alert("Something went wrong", isPresented: Binding(
            get: { sessionViewModel.errorMessage != nil },
            set: { if !$0 { sessionViewModel.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(sessionViewModel.errorMessage ?? "")
        }
    }
}
