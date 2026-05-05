import Foundation

@MainActor
final class HouseholdSettingsViewModel: ObservableObject {
    @Published private(set) var currentUserProfile: UserProfile?
    @Published private(set) var households: [Household] = []
    @Published private(set) var membersByHouseholdID: [String: [UserProfile]] = [:]
    @Published var editableDisplayName: String = ""
    @Published var newHouseholdName: String = ""
    @Published var errorMessage: String?
    @Published var isLoading = false
    @Published var isSavingProfile = false
    @Published var isCreatingHousehold = false
    @Published var isSwitchingHousehold = false

    private let environment: AppEnvironment
    private let userID: String

    init(environment: AppEnvironment, userProfile: UserProfile) {
        self.environment = environment
        self.userID = userProfile.id
        self.currentUserProfile = userProfile
        self.editableDisplayName = userProfile.displayName
    }

    var activeHousehold: Household? {
        guard let activeID = currentUserProfile?.activeHouseholdID else { return nil }
        return households.first(where: { $0.id == activeID })
    }

    var activeHouseholdName: String {
        activeHousehold?.name.isEmpty == false ? activeHousehold!.name : "Shared Kitchen"
    }

    func shareLink(for household: Household) -> String {
        guard !household.inviteCode.isEmpty else { return "wecookin://join" }
        return "wecookin://join?code=\(household.inviteCode)"
    }

    func inviteMessage(for household: Household) -> String {
        """
        Join my WeCookin' household "\(household.name)".

        Open this link on your iPhone:
        \(shareLink(for: household))
        """
    }

    func members(for household: Household) -> [UserProfile] {
        membersByHouseholdID[household.id] ?? []
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        await reloadAllState()
    }

    func saveProfile(imageData: Data?) async {
        guard let currentUserProfile else { return }

        isSavingProfile = true
        defer { isSavingProfile = false }

        do {
            let trimmedName = editableDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
            let updated = try await environment.householdService.updateUserProfile(
                userID: currentUserProfile.id,
                name: trimmedName.isEmpty ? (currentUserProfile.displayName.isEmpty ? "WeCookin User" : currentUserProfile.displayName) : trimmedName,
                imageData: imageData
            )
            self.currentUserProfile = updated
            editableDisplayName = updated.displayName
            await reloadAllState()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createHousehold() async {
        guard let currentUserProfile else { return }

        isCreatingHousehold = true
        defer { isCreatingHousehold = false }

        do {
            _ = try await environment.householdService.createHousehold(
                name: newHouseholdName.trimmingCharacters(in: .whitespacesAndNewlines),
                owner: currentUserProfile
            )
            newHouseholdName = ""
            await reloadAllState()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func setActiveHousehold(_ household: Household) async {
        guard let currentUserProfile else { return }
        guard currentUserProfile.activeHouseholdID != household.id else { return }

        isSwitchingHousehold = true
        defer { isSwitchingHousehold = false }

        do {
            let updated = try await environment.householdService.setActiveHousehold(
                userID: currentUserProfile.id,
                householdID: household.id
            )
            self.currentUserProfile = updated
            await reloadAllState()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func reloadAllState() async {
        do {
            if let refreshedProfile = try await environment.householdService.loadUserProfile(userID: userID) {
                currentUserProfile = refreshedProfile
                editableDisplayName = refreshedProfile.displayName

                households = try await environment.householdService.loadHouseholds(householdIDs: refreshedProfile.householdIDs)

                var resolvedMembers: [String: [UserProfile]] = [:]
                for household in households {
                    resolvedMembers[household.id] = try await environment.householdService.loadUserProfiles(userIDs: household.memberIDs)
                }
                membersByHouseholdID = resolvedMembers
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
