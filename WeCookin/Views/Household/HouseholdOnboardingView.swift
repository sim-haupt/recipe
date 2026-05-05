import SwiftUI

struct HouseholdOnboardingView: View {
    @Environment(\.appEnvironment) private var environment
    @EnvironmentObject private var sessionViewModel: SessionViewModel
    @StateObject private var viewModel: HouseholdViewModel
    let userProfile: UserProfile

    init(userProfile: UserProfile, environment: AppEnvironment = .demo) {
        self.userProfile = userProfile
        _viewModel = StateObject(wrappedValue: HouseholdViewModel(environment: environment))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Set up your shared kitchen")
                        .font(.system(size: 32, weight: .bold, design: .rounded))

                    groupedCard(title: "Create a cooking book") {
                        TextField("Cooking book name", text: $viewModel.householdName)
                            .textFieldStyle(.roundedBorder)
                        Button("Create Cooking Book") {
                            Task {
                                await viewModel.createHousehold(for: userProfile)
                                await sessionViewModel.refreshUserProfile()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(RecipeTheme.accentStrong)
                    }

                    groupedCard(title: "Join with invite code") {
                        TextField("Invite code", text: $viewModel.inviteCode)
                            .textInputAutocapitalization(.characters)
                            .textFieldStyle(.roundedBorder)
                        Button("Join Cooking Book") {
                            Task {
                                await viewModel.joinHousehold(for: userProfile)
                                await sessionViewModel.refreshUserProfile()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(RecipeTheme.accentStrong)
                    }
                }
                .padding(24)
            }
            .background(RecipeTheme.pageGradient.ignoresSafeArea())
            .alert("Cooking book setup issue", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
        .environment(\.appEnvironment, environment)
    }

    private func groupedCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.system(size: 20, weight: .bold, design: .rounded))
            content()
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RecipeTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .shadow(color: RecipeTheme.shadow, radius: 12, y: 8)
    }
}
