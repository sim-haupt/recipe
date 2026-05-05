import Foundation
import AuthenticationServices

final class DemoAuthService: AuthServicing {
    private let store: DemoDataStore

    init(store: DemoDataStore = .shared) {
        self.store = store
        store.seedIfNeeded()
    }

    var currentSession: AuthSession? {
        guard let userID = store.currentUserID ?? "demo-user" as String? else { return nil }
        let user = store.users[userID]
        return AuthSession(userID: userID, email: user?.email, displayName: user?.displayName)
    }

    func observeAuthState(_ handler: @escaping (AuthSession?) -> Void) -> AuthStateListening {
        let token = UUID()
        store.seedIfNeeded()
        if store.currentUserID == nil {
            store.currentUserID = "demo-user"
        }
        store.authObservers[token] = handler
        handler(currentSession)
        return DemoAuthListener(token: token, store: store)
    }

    func signIn(email: String, password: String) async throws {
        let user = store.users.values.first { $0.email.caseInsensitiveCompare(email) == .orderedSame }
        if let user {
            store.currentUserID = user.id
            store.saveSnapshotIfPossible()
            store.notifyAuthObservers()
        } else {
            throw NSError(domain: "WeCookinDemo", code: 401, userInfo: [NSLocalizedDescriptionKey: "Demo mode could not find that user."])
        }
    }

    func signUp(name: String, email: String, password: String) async throws -> String {
        let userID = UUID().uuidString
        let user = UserProfile(
            id: userID,
            displayName: name,
            email: email,
            activeHouseholdID: nil,
            householdIDs: [],
            createdAt: Date(),
            updatedAt: Date()
        )
        store.users[userID] = user
        store.currentUserID = userID
        store.saveSnapshotIfPossible()
        store.notifyAuthObservers()
        return userID
    }

    func signInWithApple(idToken: String, rawNonce: String, fullName: PersonNameComponents?) async throws {
        store.seedIfNeeded()
        if store.currentUserID == nil {
            store.currentUserID = "demo-user"
        }
        store.saveSnapshotIfPossible()
        store.notifyAuthObservers()
    }

    func signOut() throws {
        store.currentUserID = nil
        store.saveSnapshotIfPossible()
        store.notifyAuthObservers()
    }
}

final class DemoHouseholdService: HouseholdServicing {
    private let store: DemoDataStore

    init(store: DemoDataStore = .shared) {
        self.store = store
        store.seedIfNeeded()
    }

    func loadUserProfile(userID: String) async throws -> UserProfile? {
        store.users[userID]
    }

    func loadUserProfiles(userIDs: [String]) async throws -> [UserProfile] {
        userIDs.compactMap { store.users[$0] }
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    func loadHousehold(householdID: String) async throws -> Household? {
        store.households[householdID]
    }

    func loadHouseholds(householdIDs: [String]) async throws -> [Household] {
        householdIDs.compactMap { store.households[$0] }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func createUserProfile(userID: String, name: String, email: String) async throws {
        let now = Date()
        store.users[userID] = UserProfile(
            id: userID,
            displayName: name,
            email: email,
            profileImageURL: nil,
            activeHouseholdID: nil,
            householdIDs: [],
            createdAt: now,
            updatedAt: now
        )
        store.saveSnapshotIfPossible()
    }

    func updateUserProfile(userID: String, name: String, imageData: Data?) async throws -> UserProfile {
        guard var user = store.users[userID] else {
            throw NSError(domain: "WeCookinDemo", code: 404, userInfo: [NSLocalizedDescriptionKey: "Could not find that demo profile."])
        }

        user.displayName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let imageData {
            user.profileImageURL = try store.persistImageData(imageData, fileName: "profile-\(userID)")
        }
        user.updatedAt = Date()
        store.users[userID] = user
        store.saveSnapshotIfPossible()
        store.notifyAuthObservers()
        return user
    }

    func createHousehold(name: String, owner: UserProfile) async throws -> Household {
        let now = Date()
        let householdID = UUID().uuidString
        let household = Household(
            id: householdID,
            name: name.isEmpty ? "My Kitchen" : name,
            inviteCode: "JOIN\(Int.random(in: 100...999))",
            memberIDs: [owner.id],
            createdByUserID: owner.id,
            createdAt: now,
            updatedAt: now
        )
        store.households[householdID] = household

        var updatedUser = owner
        if updatedUser.activeHouseholdID == nil {
            updatedUser.activeHouseholdID = householdID
        }
        updatedUser.householdIDs = Array(Set(updatedUser.householdIDs + [householdID]))
        updatedUser.updatedAt = now
        store.users[owner.id] = updatedUser

        store.recipesByHousehold[householdID] = []
        store.tagsByHousehold[householdID] = []
        store.saveSnapshotIfPossible()
        store.notifyAuthObservers()
        store.notifyRecipes(householdID: householdID)
        store.notifyTags(householdID: householdID)
        return household
    }

    func joinHousehold(inviteCode: String, user: UserProfile) async throws -> Household {
        guard let household = store.households.values.first(where: { $0.inviteCode.caseInsensitiveCompare(inviteCode) == .orderedSame }) else {
            throw NSError(domain: "WeCookinDemo", code: 404, userInfo: [NSLocalizedDescriptionKey: "No demo cooking book matches that invite code."])
        }

        var updatedHousehold = household
        updatedHousehold.memberIDs = Array(Set(updatedHousehold.memberIDs + [user.id]))
        updatedHousehold.updatedAt = Date()
        store.households[household.id] = updatedHousehold

        var updatedUser = user
        updatedUser.activeHouseholdID = household.id
        updatedUser.householdIDs = Array(Set(updatedUser.householdIDs + [household.id]))
        updatedUser.updatedAt = Date()
        store.users[user.id] = updatedUser

        store.saveSnapshotIfPossible()
        store.notifyAuthObservers()
        return updatedHousehold
    }

    func setActiveHousehold(userID: String, householdID: String) async throws -> UserProfile {
        guard var user = store.users[userID] else {
            throw NSError(domain: "WeCookinDemo", code: 404, userInfo: [NSLocalizedDescriptionKey: "Could not find that demo profile."])
        }

        user.activeHouseholdID = householdID
        if !user.householdIDs.contains(householdID) {
            user.householdIDs.append(householdID)
        }
        user.updatedAt = Date()
        store.users[userID] = user
        store.saveSnapshotIfPossible()
        store.notifyAuthObservers()
        return user
    }
}

final class DemoRecipeService: RecipeServicing {
    private let store: DemoDataStore

    init(store: DemoDataStore = .shared) {
        self.store = store
        store.seedIfNeeded()
    }

    func observeRecipes(householdID: String, onChange: @escaping (Result<[Recipe], Error>) -> Void) -> RealtimeListening {
        let token = UUID()
        store.recipeObservers[householdID, default: [:]][token] = onChange
        onChange(.success((store.recipesByHousehold[householdID] ?? []).sorted { $0.savedDate > $1.savedDate }))
        return DemoRealtimeListener {
            self.store.recipeObservers[householdID]?[token] = nil
        }
    }

    func observeTags(householdID: String, onChange: @escaping (Result<[Tag], Error>) -> Void) -> RealtimeListening {
        let token = UUID()
        store.tagObservers[householdID, default: [:]][token] = onChange
        onChange(.success((store.tagsByHousehold[householdID] ?? []).sorted { $0.name < $1.name }))
        return DemoRealtimeListener {
            self.store.tagObservers[householdID]?[token] = nil
        }
    }

    func observeComments(householdID: String, recipeID: String, onChange: @escaping (Result<[Comment], Error>) -> Void) -> RealtimeListening {
        let key = store.recipeKey(householdID: householdID, recipeID: recipeID)
        let token = UUID()
        store.commentObservers[key, default: [:]][token] = onChange
        onChange(.success(store.commentsByRecipeKey[key] ?? []))
        return DemoRealtimeListener {
            self.store.commentObservers[key]?[token] = nil
        }
    }

    func observeReviews(householdID: String, recipeID: String, onChange: @escaping (Result<[Review], Error>) -> Void) -> RealtimeListening {
        let key = store.recipeKey(householdID: householdID, recipeID: recipeID)
        let token = UUID()
        store.reviewObservers[key, default: [:]][token] = onChange
        onChange(.success((store.reviewsByRecipeKey[key] ?? []).sorted { $0.updatedAt > $1.updatedAt }))
        return DemoRealtimeListener {
            self.store.reviewObservers[key]?[token] = nil
        }
    }

    func createRecipe(input: RecipeCreationInput, householdID: String, author: UserProfile) async throws {
        let now = Date()
        let tags = ensureTags(tagNames: input.tagNames, householdID: householdID)
        let recipeID = UUID().uuidString
        let imageURL = try input.imageData.map { try store.persistImageData($0, fileName: recipeID) }
        let extraction = input.aiExtraction?.hasMeaningfulContent == true ? input.aiExtraction : nil
        let description = ImportedTextSanitizer.preferredRecipeDescription(
            baseDescription: input.description,
            rawText: (extraction?.ingredients ?? []).joined(separator: "\n"),
            aiSummary: extraction?.summary
        )
        let cleanedTitle = ImportedTextSanitizer.cleanInline(input.title)

        var recipes = store.recipesByHousehold[householdID] ?? []
        let recipe = Recipe(
            id: recipeID,
            householdID: householdID,
            title: cleanedTitle.isEmpty ? "Untitled Recipe" : cleanedTitle,
            description: description,
            sourceURL: input.sourceURL.isEmpty ? nil : input.sourceURL,
            imageURL: imageURL,
            savedDate: now,
            createdByUserID: author.id,
            createdByName: author.displayName,
            updatedAt: now,
            categories: input.categories,
            tagIDs: tags.map(\.id),
            tagNames: tags.map(\.name),
            isFavorite: false,
            averageRating: input.initialRating > 0 ? Double(input.initialRating) : nil,
            reviewCount: input.initialRating > 0 ? 1 : 0,
            ingredients: extraction?.ingredients ?? [],
            preparationSteps: [],
            aiNotes: [],
            aiSummary: normalizedOptionalString(extraction?.summary),
            aiConfidence: extraction?.confidence
        )
        recipes.insert(recipe, at: 0)
        store.recipesByHousehold[householdID] = recipes

        if !input.initialComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            try await addComment(recipe: recipe, householdID: householdID, text: input.initialComment, imageData: nil, author: author)
        }

        if input.initialRating > 0 {
            try await upsertReview(recipe: recipe, householdID: householdID, rating: input.initialRating, note: input.initialComment, author: author)
        } else {
            store.saveSnapshotIfPossible()
            store.notifyRecipes(householdID: householdID)
        }
    }

    func updateTags(recipe: Recipe, householdID: String, tagNames: [String]) async throws {
        let tags = ensureTags(tagNames: tagNames, householdID: householdID)
        guard var recipes = store.recipesByHousehold[householdID],
              let index = recipes.firstIndex(where: { $0.id == recipe.id }) else { return }

        recipes[index].tagIDs = tags.map(\.id)
        recipes[index].tagNames = tags.map(\.name)
        recipes[index].updatedAt = Date()
        store.recipesByHousehold[householdID] = recipes
        store.saveSnapshotIfPossible()
        store.notifyRecipes(householdID: householdID)
        store.notifyTags(householdID: householdID)
    }

    func updateRecipe(
        recipe: Recipe,
        householdID: String,
        title: String,
        description: String,
        sourceURL: String,
        categories: [String],
        tagNames: [String],
        ingredients: [String],
        imageData: Data?
    ) async throws {
        let tags = ensureTags(tagNames: tagNames, householdID: householdID)
        guard var recipes = store.recipesByHousehold[householdID],
              let index = recipes.firstIndex(where: { $0.id == recipe.id }) else { return }

        let cleanedTitle = ImportedTextSanitizer.cleanInline(title)
        recipes[index].title = cleanedTitle.isEmpty ? recipe.title : cleanedTitle
        recipes[index].description = ImportedTextSanitizer.cleanInline(description)
        recipes[index].sourceURL = sourceURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : sourceURL.trimmingCharacters(in: .whitespacesAndNewlines)
        recipes[index].categories = categories
        recipes[index].tagIDs = tags.map(\.id)
        recipes[index].tagNames = tags.map(\.name)
        recipes[index].ingredients = ingredients
        recipes[index].preparationSteps = []
        recipes[index].aiNotes = []
        if let imageData {
            recipes[index].imageURL = try store.persistImageData(imageData, fileName: recipe.id)
        }
        recipes[index].updatedAt = Date()
        store.recipesByHousehold[householdID] = recipes
        store.saveSnapshotIfPossible()
        store.notifyRecipes(householdID: householdID)
        store.notifyTags(householdID: householdID)
    }

    func deleteRecipe(recipe: Recipe, householdID: String) async throws {
        guard var recipes = store.recipesByHousehold[householdID] else { return }
        recipes.removeAll { $0.id == recipe.id }
        store.recipesByHousehold[householdID] = recipes
        let key = store.recipeKey(householdID: householdID, recipeID: recipe.id)
        store.commentsByRecipeKey[key] = nil
        store.reviewsByRecipeKey[key] = nil
        store.saveSnapshotIfPossible()
        store.notifyRecipes(householdID: householdID)
        store.notifyComments(householdID: householdID, recipeID: recipe.id)
        store.notifyReviews(householdID: householdID, recipeID: recipe.id)
    }

    func updateFavorite(recipe: Recipe, householdID: String, isFavorite: Bool) async throws {
        guard var recipes = store.recipesByHousehold[householdID],
              let index = recipes.firstIndex(where: { $0.id == recipe.id }) else { return }

        recipes[index].isFavorite = isFavorite
        recipes[index].updatedAt = Date()
        store.recipesByHousehold[householdID] = recipes
        store.saveSnapshotIfPossible()
        store.notifyRecipes(householdID: householdID)
    }

    func addComment(recipe: Recipe, householdID: String, text: String, imageData: Data?, author: UserProfile) async throws {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || imageData != nil else { return }
        let key = store.recipeKey(householdID: householdID, recipeID: recipe.id)
        var comments = store.commentsByRecipeKey[key] ?? []
        let commentID = UUID().uuidString
        let imageURL = try imageData.map { try store.persistImageData($0, fileName: commentID) }
        comments.append(Comment(
            id: commentID,
            recipeID: recipe.id,
            authorID: author.id,
            authorName: author.displayName,
            text: trimmed,
            imageURL: imageURL,
            createdAt: Date()
        ))
        store.commentsByRecipeKey[key] = comments
        store.saveSnapshotIfPossible()
        store.notifyComments(householdID: householdID, recipeID: recipe.id)
    }

    func upsertReview(recipe: Recipe, householdID: String, rating: Int, note: String, author: UserProfile) async throws {
        let key = store.recipeKey(householdID: householdID, recipeID: recipe.id)
        var reviews = store.reviewsByRecipeKey[key] ?? []

        if let index = reviews.firstIndex(where: { $0.authorID == author.id }) {
            reviews[index].rating = rating
            reviews[index].note = note
            reviews[index].updatedAt = Date()
        } else {
            reviews.append(Review(
                id: author.id,
                recipeID: recipe.id,
                authorID: author.id,
                authorName: author.displayName,
                rating: rating,
                note: note,
                createdAt: Date(),
                updatedAt: Date()
            ))
        }

        store.reviewsByRecipeKey[key] = reviews

        guard var recipes = store.recipesByHousehold[householdID],
              let index = recipes.firstIndex(where: { $0.id == recipe.id }) else {
            store.notifyReviews(householdID: householdID, recipeID: recipe.id)
            return
        }

        let validRatings = reviews.map(\.rating).filter { $0 > 0 }
        recipes[index].averageRating = validRatings.isEmpty ? nil : Double(validRatings.reduce(0, +)) / Double(validRatings.count)
        recipes[index].reviewCount = validRatings.count
        recipes[index].updatedAt = Date()
        store.recipesByHousehold[householdID] = recipes

        store.saveSnapshotIfPossible()
        store.notifyReviews(householdID: householdID, recipeID: recipe.id)
        store.notifyRecipes(householdID: householdID)
    }

    private func ensureTags(tagNames: [String], householdID: String) -> [Tag] {
        let now = Date()
        var tags = store.tagsByHousehold[householdID] ?? []

        for tagName in tagNames.map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) }).filter({ !$0.isEmpty }) {
            let normalized = tagName.normalizedTag
            if !tags.contains(where: { $0.id == normalized }) {
                tags.append(Tag(id: normalized, householdID: householdID, name: tagName, normalizedName: normalized, createdAt: now, updatedAt: now))
            }
        }

        tags.sort { $0.name < $1.name }
        store.tagsByHousehold[householdID] = tags
        store.saveSnapshotIfPossible()
        store.notifyTags(householdID: householdID)

        return tagNames
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .compactMap { tagName in tags.first(where: { $0.id == tagName.normalizedTag }) }
    }
}

private extension String {
    var nilIfEmpty: String? {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private func normalizedOptionalString(_ value: String?) -> String? {
    value?.nilIfEmpty
}

private final class DemoAuthListener: AuthStateListening {
    let token: UUID
    let store: DemoDataStore

    init(token: UUID, store: DemoDataStore) {
        self.token = token
        self.store = store
    }

    func cancel() {
        store.authObservers[token] = nil
    }
}

private final class DemoRealtimeListener: RealtimeListening {
    private let onRemove: () -> Void

    init(onRemove: @escaping () -> Void) {
        self.onRemove = onRemove
    }

    func remove() {
        onRemove()
    }
}
