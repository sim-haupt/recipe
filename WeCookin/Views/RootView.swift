import SwiftUI

struct RootView: View {
    @EnvironmentObject private var sessionViewModel: SessionViewModel
    @Environment(\.appEnvironment) private var environment

    var body: some View {
        ZStack {
            RecipeTheme.pageGradient
                .ignoresSafeArea()

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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .tint(RecipeTheme.accentStrong)
        .alert("Something went wrong", isPresented: Binding(
            get: { sessionViewModel.errorMessage != nil },
            set: { if !$0 { sessionViewModel.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(sessionViewModel.errorMessage ?? "")
        }
        .onOpenURL { url in
            sessionViewModel.handleIncomingURL(url)
        }
    }
}
