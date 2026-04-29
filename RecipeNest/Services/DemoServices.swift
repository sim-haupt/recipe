import Foundation

final class DemoAuthService: AuthServicing {
    private let store: DemoDataStore

    init(store: DemoDataStore = .shared) {
        self.store = store
        store.seedIfNeeded()
    }

    var currentSession: AuthSession? {
        guard let userID = store.currentUserID ?? "demo-user" as String? else { return nil }
        let user = store.users[userID]
        return AuthSession(userID: userID, email: user?.email)
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
            store.notifyAuthObservers()
        } else {
            throw NSError(domain: "RecipeNestDemo", code: 401, userInfo: [NSLocalizedDescriptionKey: "Demo mode could not find that user."])
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
        store.notifyAuthObservers()
        return userID
    }

    func signOut() throws {
        store.currentUserID = nil
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

    func createUserProfile(userID: String, name: String, email: String) async throws {
        let now = Date()
        store.users[userID] = UserProfile(
            id: userID,
            displayName: name,
            email: email,
            activeHouseholdID: nil,
            householdIDs: [],
            createdAt: now,
            updatedAt: now
        )
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
        updatedUser.activeHouseholdID = householdID
        updatedUser.householdIDs = Array(Set(updatedUser.householdIDs + [householdID]))
        updatedUser.updatedAt = now
        store.users[owner.id] = updatedUser

        store.recipesByHousehold[householdID] = []
        store.tagsByHousehold[householdID] = []
        store.notifyAuthObservers()
        store.notifyRecipes(householdID: householdID)
        store.notifyTags(householdID: householdID)
        return household
    }

    func joinHousehold(inviteCode: String, user: UserProfile) async throws -> Household {
        guard let household = store.households.values.first(where: { $0.inviteCode.caseInsensitiveCompare(inviteCode) == .orderedSame }) else {
            throw NSError(domain: "RecipeNestDemo", code: 404, userInfo: [NSLocalizedDescriptionKey: "No demo household matches that invite code."])
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

        store.notifyAuthObservers()
        return updatedHousehold
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
        let imageURL = try input.imageData.map { try store.persistImageData($0, recipeID: recipeID) }

        var recipes = store.recipesByHousehold[householdID] ?? []
        let recipe = Recipe(
            id: recipeID,
            householdID: householdID,
            title: input.title.isEmpty ? "Untitled Recipe" : input.title,
            description: input.description,
            sourceURL: input.sourceURL.isEmpty ? nil : input.sourceURL,
            imageURL: imageURL,
            savedDate: now,
            createdByUserID: author.id,
            createdByName: author.displayName,
            updatedAt: now,
            tagIDs: tags.map(\.id),
            tagNames: tags.map(\.name),
            isFavorite: false,
            averageRating: input.initialRating > 0 ? Double(input.initialRating) : nil,
            reviewCount: input.initialRating > 0 ? 1 : 0
        )
        recipes.insert(recipe, at: 0)
        store.recipesByHousehold[householdID] = recipes

        if !input.initialComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            try await addComment(recipe: recipe, householdID: householdID, text: input.initialComment, author: author)
        }

        if input.initialRating > 0 {
            try await upsertReview(recipe: recipe, householdID: householdID, rating: input.initialRating, note: input.initialComment, author: author)
        } else {
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
        store.notifyRecipes(householdID: householdID)
        store.notifyTags(householdID: householdID)
    }

    func updateFavorite(recipe: Recipe, householdID: String, isFavorite: Bool) async throws {
        guard var recipes = store.recipesByHousehold[householdID],
              let index = recipes.firstIndex(where: { $0.id == recipe.id }) else { return }

        recipes[index].isFavorite = isFavorite
        recipes[index].updatedAt = Date()
        store.recipesByHousehold[householdID] = recipes
        store.notifyRecipes(householdID: householdID)
    }

    func addComment(recipe: Recipe, householdID: String, text: String, author: UserProfile) async throws {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let key = store.recipeKey(householdID: householdID, recipeID: recipe.id)
        var comments = store.commentsByRecipeKey[key] ?? []
        comments.append(Comment(
            id: UUID().uuidString,
            recipeID: recipe.id,
            authorID: author.id,
            authorName: author.displayName,
            text: trimmed,
            createdAt: Date()
        ))
        store.commentsByRecipeKey[key] = comments
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
        store.notifyTags(householdID: householdID)

        return tagNames
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .compactMap { tagName in tags.first(where: { $0.id == tagName.normalizedTag }) }
    }
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
