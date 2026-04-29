import FirebaseFirestore
import Foundation

final class FirestoreHouseholdService: HouseholdServicing {
    private let database = Firestore.firestore()

    func loadUserProfile(userID: String) async throws -> UserProfile? {
        let document = try await database.collection("users").document(userID).getDocument()
        guard let data = document.data() else { return nil }
        return mapUserProfile(id: document.documentID, data: data)
    }

    func createUserProfile(userID: String, name: String, email: String) async throws {
        let now = Date()
        let payload: [String: Any] = [
            "displayName": name,
            "email": email,
            "activeHouseholdID": NSNull(),
            "householdIDs": [],
            "createdAt": Timestamp(date: now),
            "updatedAt": Timestamp(date: now)
        ]

        try await database.collection("users").document(userID).setData(payload, merge: true)
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

        try await database.collection("users").document(owner.id).setData([
            "activeHouseholdID": householdID,
            "householdIDs": FieldValue.arrayUnion([householdID]),
            "updatedAt": Timestamp(date: now)
        ], merge: true)

        return household
    }

    func joinHousehold(inviteCode: String, user: UserProfile) async throws -> Household {
        let snapshot = try await database.collection("households")
            .whereField("inviteCode", isEqualTo: inviteCode.uppercased())
            .limit(to: 1)
            .getDocuments()

        guard let document = snapshot.documents.first, let household = mapHousehold(document) else {
            throw NSError(domain: "RecipeNest", code: 404, userInfo: [NSLocalizedDescriptionKey: "No household matches that invite code."])
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

    private static func makeInviteCode() -> String {
        String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(6)).uppercased()
    }
}

func mapUserProfile(id: String, data: [String: Any]) -> UserProfile {
    UserProfile(
        id: id,
        displayName: data["displayName"] as? String ?? "",
        email: data["email"] as? String ?? "",
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
        name: data["name"] as? String ?? "Household",
        inviteCode: data["inviteCode"] as? String ?? "",
        memberIDs: data["memberIDs"] as? [String] ?? [],
        createdByUserID: data["createdByUserID"] as? String ?? "",
        createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
        updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date()
    )
}
