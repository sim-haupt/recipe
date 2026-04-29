import Foundation

@MainActor
final class HouseholdViewModel: ObservableObject {
    @Published var householdName = ""
    @Published var inviteCode = ""
    @Published var isSubmitting = false
    @Published var errorMessage: String?

    private let environment: AppEnvironment

    init(environment: AppEnvironment) {
        self.environment = environment
    }

    func createHousehold(for userProfile: UserProfile) async {
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            _ = try await environment.householdService.createHousehold(
                name: householdName.trimmingCharacters(in: .whitespacesAndNewlines),
                owner: userProfile
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func joinHousehold(for userProfile: UserProfile) async {
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            _ = try await environment.householdService.joinHousehold(
                inviteCode: inviteCode.trimmingCharacters(in: .whitespacesAndNewlines),
                user: userProfile
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
