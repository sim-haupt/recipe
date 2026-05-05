import Foundation

@MainActor
final class HouseholdSettingsViewModel: ObservableObject {
    @Published private(set) var household: Household?
    @Published private(set) var members: [UserProfile] = []
    @Published var errorMessage: String?
    @Published var isLoading = false

    private let environment: AppEnvironment
    private let userProfile: UserProfile

    init(environment: AppEnvironment, userProfile: UserProfile) {
        self.environment = environment
        self.userProfile = userProfile
    }

    var householdName: String {
        household?.name.isEmpty == false ? household!.name : "Shared Kitchen"
    }

    var inviteCode: String {
        household?.inviteCode ?? ""
    }

    var inviteMessage: String {
        let code = inviteCode.isEmpty ? "—" : inviteCode
        return """
        Join my WeCookin' household "\(householdName)".

        Open WeCookin', choose “Join with invite code”, and enter:
        \(code)
        """
    }

    func load() async {
        guard let householdID = userProfile.activeHouseholdID else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let loadedHousehold = try await environment.householdService.loadHousehold(householdID: householdID)
            household = loadedHousehold

            if let memberIDs = loadedHousehold?.memberIDs {
                members = try await environment.householdService.loadUserProfiles(userIDs: memberIDs)
            } else {
                members = []
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
