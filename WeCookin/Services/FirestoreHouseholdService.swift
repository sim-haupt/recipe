import FirebaseFirestore
import FirebaseStorage
import Foundation

final class FirestoreHouseholdService: HouseholdServicing {
    private var database: Firestore {
        Firestore.firestore()
    }

    private var storage: Storage {
        Storage.storage()
    }

    func loadUserProfile(userID: String) async throws -> UserProfile? {
        let document = try await database.collection("users").document(userID).getDocument()
        guard let data = document.data() else { return nil }
        return mapUserProfile(id: document.documentID, data: data)
    }

    func loadUserProfiles(userIDs: [String]) async throws -> [UserProfile] {
        try await withThrowingTaskGroup(of: UserProfile?.self) { group in
            for userID in userIDs {
                group.addTask {
                    try await self.loadUserProfile(userID: userID)
                }
            }

            var profiles: [UserProfile] = []
            for try await profile in group {
                if let profile {
                    profiles.append(profile)
                }
            }
            return profiles.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        }
    }

    func loadHousehold(householdID: String) async throws -> Household? {
        let document = try await database.collection("households").document(householdID).getDocument()
        return mapHousehold(document)
    }

    func loadHouseholds(householdIDs: [String]) async throws -> [Household] {
        try await withThrowingTaskGroup(of: Household?.self) { group in
            for householdID in householdIDs {
                group.addTask {
                    try await self.loadHousehold(householdID: householdID)
                }
            }

            var households: [Household] = []
            for try await household in group {
                if let household {
                    households.append(household)
                }
            }

            return households.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
    }

    func createUserProfile(userID: String, name: String, email: String) async throws {
        let now = Date()
        let payload: [String: Any] = [
            "displayName": name,
            "email": email,
            "profileImageURL": NSNull(),
            "activeHouseholdID": NSNull(),
            "householdIDs": [],
            "createdAt": Timestamp(date: now),
            "updatedAt": Timestamp(date: now)
        ]

        try await database.collection("users").document(userID).setData(payload, merge: true)
    }

    func updateUserProfile(userID: String, name: String, imageData: Data?) async throws -> UserProfile {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        var payload: [String: Any] = [
            "displayName": trimmedName,
            "updatedAt": Timestamp(date: Date())
        ]

        if let imageData {
            payload["profileImageURL"] = try await uploadProfileImage(imageData, userID: userID)
        }

        try await database.collection("users").document(userID).setData(payload, merge: true)

        guard let updated = try await loadUserProfile(userID: userID) else {
            throw NSError(domain: "WeCookin", code: 500, userInfo: [NSLocalizedDescriptionKey: "Could not reload the updated profile."])
        }

        return updated
    }

    func createHousehold(name: String, owner: UserProfile) async throws -> Household {
        let householdID = UUID().uuidString
        let inviteCode = Self.makeInviteCode()
        let now = Date()
        let household = Household(
            id: householdID,
            name: name,
            inviteCode: inviteCode,
            memberIDs: [owner.id],
            createdByUserID: owner.id,
            createdAt: now,
            updatedAt: now
        )

        try await database.collection("households").document(householdID).setData([
            "name": household.name,
            "inviteCode": household.inviteCode,
            "memberIDs": household.memberIDs,
            "createdByUserID": household.createdByUserID,
            "createdAt": Timestamp(date: household.createdAt),
            "updatedAt": Timestamp(date: household.updatedAt)
        ])

        var userPayload: [String: Any] = [
            "householdIDs": FieldValue.arrayUnion([householdID]),
            "updatedAt": Timestamp(date: now)
        ]
        if owner.activeHouseholdID == nil {
            userPayload["activeHouseholdID"] = householdID
        }

        try await database.collection("users").document(owner.id).setData(userPayload, merge: true)

        return household
    }

    func joinHousehold(inviteCode: String, user: UserProfile) async throws -> Household {
        let snapshot = try await database.collection("households")
            .whereField("inviteCode", isEqualTo: inviteCode.uppercased())
            .limit(to: 1)
            .getDocuments()

        guard let document = snapshot.documents.first, let household = mapHousehold(document) else {
            throw NSError(domain: "WeCookin", code: 404, userInfo: [NSLocalizedDescriptionKey: "No cookbook matches that invite code."])
        }

        try await document.reference.setData([
            "memberIDs": FieldValue.arrayUnion([user.id]),
            "updatedAt": Timestamp(date: Date())
        ], merge: true)

        try await database.collection("users").document(user.id).setData([
            "activeHouseholdID": household.id,
            "householdIDs": FieldValue.arrayUnion([household.id]),
            "updatedAt": Timestamp(date: Date())
        ], merge: true)

        return household
    }

    func setActiveHousehold(userID: String, householdID: String) async throws -> UserProfile {
        try await database.collection("users").document(userID).setData([
            "activeHouseholdID": householdID,
            "updatedAt": Timestamp(date: Date())
        ], merge: true)

        guard let updated = try await loadUserProfile(userID: userID) else {
            throw NSError(domain: "WeCookin", code: 500, userInfo: [NSLocalizedDescriptionKey: "Could not reload the updated cookbook selection."])
        }
        return updated
    }

    private static func makeInviteCode() -> String {
        String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(6)).uppercased()
    }

    private func uploadProfileImage(_ data: Data, userID: String) async throws -> String {
        let reference = storage.reference().child("users/\(userID)/profile.jpg")
        _ = try await reference.putDataAwaitingResult(data)
        return try await reference.downloadURLAwaitingResult().absoluteString
    }
}

func mapUserProfile(id: String, data: [String: Any]) -> UserProfile {
    UserProfile(
        id: id,
        displayName: data["displayName"] as? String ?? "",
        email: data["email"] as? String ?? "",
        profileImageURL: data["profileImageURL"] as? String,
        activeHouseholdID: data["activeHouseholdID"] as? String,
        householdIDs: data["householdIDs"] as? [String] ?? [],
        createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
        updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date()
    )
}

func mapHousehold(_ document: DocumentSnapshot) -> Household? {
    guard let data = document.data() else { return nil }
    return Household(
        id: document.documentID,
        name: data["name"] as? String ?? "Cookbook",
        inviteCode: data["inviteCode"] as? String ?? "",
        memberIDs: data["memberIDs"] as? [String] ?? [],
        createdByUserID: data["createdByUserID"] as? String ?? "",
        createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
        updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date()
    )
}
