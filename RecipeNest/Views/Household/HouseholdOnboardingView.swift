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
                        .font(.system(size: 30, weight: .bold, design: .rounded))

                    VStack(alignment: .leading, spacing: 14) {
                        Text("Create a household")
                            .font(.headline)
                        TextField("Household name", text: $viewModel.householdName)
                            .textFieldStyle(.roundedBorder)
                        Button("Create Household") {
                            Task {
                                await viewModel.createHousehold(for: userProfile)
                                await sessionViewModel.refreshUserProfile()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 14) {
                        Text("Join with invite code")
                            .font(.headline)
                        TextField("Invite code", text: $viewModel.inviteCode)
                            .textInputAutocapitalization(.characters)
                            .textFieldStyle(.roundedBorder)
                        Button("Join Household") {
                            Task {
                                await viewModel.joinHousehold(for: userProfile)
                                await sessionViewModel.refreshUserProfile()
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(24)
            }
            .background(RecipeTheme.background.ignoresSafeArea())
            .alert("Household setup issue", isPresented: Binding(
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
}
