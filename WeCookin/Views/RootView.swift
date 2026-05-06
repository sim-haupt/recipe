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
                } else if environment.mode == .misconfigured {
                    configurationIssueView
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

    private var configurationIssueView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Configuration Needed")
                .font(.system(size: 28, weight: .bold, design: .rounded))

            Text(environment.configurationIssue ?? "This build is missing required production configuration.")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)

            Text("Add the real Firebase configuration and rebuild before using this release build.")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(maxWidth: 520, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(RecipeTheme.card)
                .shadow(color: RecipeTheme.shadow, radius: 18, y: 10)
        )
        .padding(24)
    }
}
