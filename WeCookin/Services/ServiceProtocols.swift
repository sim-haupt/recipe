import Foundation

struct AuthSession: Equatable {
    let userID: String
    let email: String?
}

protocol AuthStateListening: AnyObject {
    func cancel()
}

protocol RealtimeListening: AnyObject {
    func remove()
}

protocol AuthServicing {
    var currentSession: AuthSession? { get }
    func observeAuthState(_ handler: @escaping (AuthSession?) -> Void) -> AuthStateListening
    func signIn(email: String, password: String) async throws
    func signUp(name: String, email: String, password: String) async throws -> String
    func signOut() throws
}

protocol HouseholdServicing {
    func loadUserProfile(userID: String) async throws -> UserProfile?
    func createUserProfile(userID: String, name: String, email: String) async throws
    func createHousehold(name: String, owner: UserProfile) async throws -> Household
    func joinHousehold(inviteCode: String, user: UserProfile) async throws -> Household
}

protocol RecipeEnrichmentServicing {
    func enrichRecipeContent(using request: RecipeEnrichmentRequest) async throws -> RecipeAIExtraction?
}

protocol RecipeServicing {
    func observeRecipes(householdID: String, onChange: @escaping (Result<[Recipe], Error>) -> Void) -> RealtimeListening
    func observeTags(householdID: String, onChange: @escaping (Result<[Tag], Error>) -> Void) -> RealtimeListening
    func observeComments(householdID: String, recipeID: String, onChange: @escaping (Result<[Comment], Error>) -> Void) -> RealtimeListening
    func observeReviews(householdID: String, recipeID: String, onChange: @escaping (Result<[Review], Error>) -> Void) -> RealtimeListening
    func createRecipe(input: RecipeCreationInput, householdID: String, author: UserProfile) async throws
    func updateRecipe(recipe: Recipe, householdID: String, title: String, description: String, sourceURL: String, categories: [String], tagNames: [String], imageData: Data?) async throws
    func deleteRecipe(recipe: Recipe, householdID: String) async throws
    func updateTags(recipe: Recipe, householdID: String, tagNames: [String]) async throws
    func updateFavorite(recipe: Recipe, householdID: String, isFavorite: Bool) async throws
    func addComment(recipe: Recipe, householdID: String, text: String, imageData: Data?, author: UserProfile) async throws
    func upsertReview(recipe: Recipe, householdID: String, rating: Int, note: String, author: UserProfile) async throws
}
