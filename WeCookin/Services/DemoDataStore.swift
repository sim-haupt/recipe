import Foundation

final class DemoDataStore {
    static let shared = DemoDataStore()
    private static let imageReferencePrefix = "demo-image:"

    private struct Snapshot: Codable {
        var currentUserID: String?
        var users: [String: UserProfile]
        var households: [String: Household]
        var recipesByHousehold: [String: [Recipe]]
        var tagsByHousehold: [String: [Tag]]
        var commentsByRecipeKey: [String: [Comment]]
        var reviewsByRecipeKey: [String: [Review]]
    }

    var currentUserID: String?
    var authObservers: [UUID: (AuthSession?) -> Void] = [:]

    var users: [String: UserProfile] = [:]
    var households: [String: Household] = [:]
    var recipesByHousehold: [String: [Recipe]] = [:]
    var tagsByHousehold: [String: [Tag]] = [:]
    var commentsByRecipeKey: [String: [Comment]] = [:]
    var reviewsByRecipeKey: [String: [Review]] = [:]

    var recipeObservers: [String: [UUID: (Result<[Recipe], Error>) -> Void]] = [:]
    var tagObservers: [String: [UUID: (Result<[Tag], Error>) -> Void]] = [:]
    var commentObservers: [String: [UUID: (Result<[Comment], Error>) -> Void]] = [:]
    var reviewObservers: [String: [UUID: (Result<[Review], Error>) -> Void]] = [:]

    private var hasLoadedInitialData = false

    private init() {}

    func persistImageData(_ data: Data, fileName: String) throws -> String {
        let storedFileName = "\(fileName).jpg"
        let fileURL = try imageDirectoryURL().appendingPathComponent(storedFileName)
        try data.write(to: fileURL, options: .atomic)
        return Self.imageReferencePrefix + storedFileName
    }

    func resolvedImageURL(for reference: String) -> URL? {
        if reference.hasPrefix(Self.imageReferencePrefix) {
            let fileName = String(reference.dropFirst(Self.imageReferencePrefix.count))
            return try? imageDirectoryURL().appendingPathComponent(fileName)
        }

        if let url = URL(string: reference), url.isFileURL {
            return url
        }

        return nil
    }

    func seedIfNeeded() {
        guard !hasLoadedInitialData else { return }
        hasLoadedInitialData = true

        if loadSnapshotIfPresent() {
            return
        }

        let now = Date()
        let userID = "demo-user"
        let householdID = "demo-household"

        let household = Household(
            id: householdID,
            name: "Demo Kitchen",
            inviteCode: "DEMO42",
            memberIDs: [userID],
            createdByUserID: userID,
            createdAt: now,
            updatedAt: now
        )

        let user = UserProfile(
            id: userID,
            displayName: "Demo Cook",
            email: "demo@wecookin.local",
            activeHouseholdID: householdID,
            householdIDs: [householdID],
            createdAt: now,
            updatedAt: now
        )

        let tags = [
            Tag(id: "weeknight", householdID: householdID, name: "Weeknight", normalizedName: "weeknight", createdAt: now, updatedAt: now),
            Tag(id: "pasta", householdID: householdID, name: "Pasta", normalizedName: "pasta", createdAt: now, updatedAt: now)
        ]

        let recipe = Recipe(
            id: "demo-recipe",
            householdID: householdID,
            title: "Creamy Lemon Pasta",
            description: "A simple demo recipe to make sure the app has real content on first launch.",
            sourceURL: "https://example.com/lemon-pasta",
            imageURL: nil,
            savedDate: now,
            createdByUserID: userID,
            createdByName: user.displayName,
            updatedAt: now,
            category: RecipeCategory.pastaAndRice.rawValue,
            tagIDs: tags.map(\.id),
            tagNames: tags.map(\.name),
            isFavorite: true,
            averageRating: 4.0,
            reviewCount: 1
        )

        let comment = Comment(
            id: UUID().uuidString,
            recipeID: recipe.id,
            authorID: userID,
            authorName: user.displayName,
            text: "Demo mode is active because Firebase is not configured yet.",
            imageURL: nil,
            createdAt: now
        )

        let review = Review(
            id: userID,
            recipeID: recipe.id,
            authorID: userID,
            authorName: user.displayName,
            rating: 4,
            note: "Solid starter recipe for testing comments, ratings, and sharing.",
            createdAt: now,
            updatedAt: now
        )

        users[userID] = user
        households[householdID] = household
        tagsByHousehold[householdID] = tags
        recipesByHousehold[householdID] = [recipe]
        commentsByRecipeKey[recipeKey(householdID: householdID, recipeID: recipe.id)] = [comment]
        reviewsByRecipeKey[recipeKey(householdID: householdID, recipeID: recipe.id)] = [review]
        currentUserID = userID
        saveSnapshotIfPossible()
    }

    func recipeKey(householdID: String, recipeID: String) -> String {
        "\(householdID)::\(recipeID)"
    }

    func notifyAuthObservers() {
        let session = currentUserID.flatMap { userID in
            let user = users[userID]
            return AuthSession(userID: userID, email: user?.email, displayName: user?.displayName)
        }
        authObservers.values.forEach { $0(session) }
    }

    func notifyRecipes(householdID: String) {
        let payload: Result<[Recipe], Error> = .success((recipesByHousehold[householdID] ?? []).sorted { $0.savedDate > $1.savedDate })
        recipeObservers[householdID]?.values.forEach { $0(payload) }
    }

    func notifyTags(householdID: String) {
        let payload: Result<[Tag], Error> = .success((tagsByHousehold[householdID] ?? []).sorted { $0.name < $1.name })
        tagObservers[householdID]?.values.forEach { $0(payload) }
    }

    func notifyComments(householdID: String, recipeID: String) {
        let key = recipeKey(householdID: householdID, recipeID: recipeID)
        let payload: Result<[Comment], Error> = .success(commentsByRecipeKey[key] ?? [])
        commentObservers[key]?.values.forEach { $0(payload) }
    }

    func notifyReviews(householdID: String, recipeID: String) {
        let key = recipeKey(householdID: householdID, recipeID: recipeID)
        let payload: Result<[Review], Error> = .success((reviewsByRecipeKey[key] ?? []).sorted { $0.updatedAt > $1.updatedAt })
        reviewObservers[key]?.values.forEach { $0(payload) }
    }

    func saveSnapshotIfPossible() {
        try? saveSnapshot()
    }

    private func imageDirectoryURL() throws -> URL {
        let fileManager = FileManager.default
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw NSError(domain: "WeCookinDemo", code: 500, userInfo: [NSLocalizedDescriptionKey: "Could not access local image storage."])
        }

        let directory = appSupport.appendingPathComponent("WeCookinDemoImages", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func snapshotFileURL() throws -> URL {
        let fileManager = FileManager.default
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw NSError(domain: "WeCookinDemo", code: 500, userInfo: [NSLocalizedDescriptionKey: "Could not access demo storage."])
        }

        let directory = appSupport.appendingPathComponent("WeCookinDemoStore", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("snapshot.json")
    }

    private func loadSnapshotIfPresent() -> Bool {
        guard let fileURL = try? snapshotFileURL(),
              let data = try? Data(contentsOf: fileURL),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) else {
            return false
        }

        currentUserID = snapshot.currentUserID
        users = snapshot.users
        households = snapshot.households
        recipesByHousehold = snapshot.recipesByHousehold
        tagsByHousehold = snapshot.tagsByHousehold
        commentsByRecipeKey = snapshot.commentsByRecipeKey
        reviewsByRecipeKey = snapshot.reviewsByRecipeKey
        return true
    }

    private func saveSnapshot() throws {
        let snapshot = Snapshot(
            currentUserID: currentUserID,
            users: users,
            households: households,
            recipesByHousehold: recipesByHousehold,
            tagsByHousehold: tagsByHousehold,
            commentsByRecipeKey: commentsByRecipeKey,
            reviewsByRecipeKey: reviewsByRecipeKey
        )

        let data = try JSONEncoder().encode(snapshot)
        try data.write(to: snapshotFileURL(), options: .atomic)
    }
}
