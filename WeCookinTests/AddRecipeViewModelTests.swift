import XCTest
@testable import WeCookin
import AuthenticationServices

@MainActor
final class AddRecipeViewModelTests: XCTestCase {
    func testInstagramPreviewGenerationCompletesAndLeavesInteractiveState() async {
        let importResult = RecipeURLImportResult(
            canonicalURL: "https://www.instagram.com/reel/Ckyu1Q3K10g/",
            title: "Chickpea sandwich",
            description: "A quick chickpea sandwich.",
            rawText: "RECIPE: -1 onion -2 cans chickpeas -100g vegan mayo",
            imageData: Data(repeating: 1, count: 32)
        )

        let environment = AppEnvironment(
            authService: MockAuthService(),
            householdService: MockHouseholdService(),
            recipeService: MockRecipeService(),
            urlImportService: MockURLImportService(result: importResult),
            recipeEnrichmentService: MockEnrichmentService(
                extraction: RecipeAIExtraction(title: "Quick Chickpea Sandwich", summary: "A quick chickpea sandwich.", ingredients: ["1 onion", "2 cans chickpeas", "100g vegan mayo"], confidence: 0.8)
            ),
            sharedDraftStore: SharedDraftStore(),
            mode: .demo
        )

        let user = UserProfile(
            id: "user-1",
            displayName: "Test User",
            email: "test@example.com",
            activeHouseholdID: "house-1",
            householdIDs: ["house-1"],
            createdAt: Date(),
            updatedAt: Date()
        )

        let viewModel = AddRecipeViewModel(environment: environment, userProfile: user)
        viewModel.draft.sourceURL = "https://www.instagram.com/reel/Ckyu1Q3K10g/"

        await viewModel.generatePreviewFromSourceURL()

        XCTAssertTrue(viewModel.hasResolvedSourcePreview)
        XCTAssertFalse(viewModel.isImportingURL)
        XCTAssertFalse(viewModel.isGeneratingPreview)
        XCTAssertFalse(viewModel.isLoadingDebugInfo)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertNotNil(viewModel.selectedImageData)
        XCTAssertFalse(viewModel.draft.ingredientsText.isEmpty)
    }
}

private final class MockAuthService: AuthServicing {
    var currentSession: AuthSession? = nil

    func observeAuthState(_ handler: @escaping (AuthSession?) -> Void) -> AuthStateListening {
        MockAuthListener()
    }

    func signIn(email: String, password: String) async throws {}
    func signUp(name: String, email: String, password: String) async throws -> String { "user-1" }
    func signInWithApple(idToken: String, rawNonce: String, fullName: PersonNameComponents?) async throws {}
    func signOut() throws {}
}

private final class MockAuthListener: AuthStateListening {
    func cancel() {}
}

private final class MockHouseholdService: HouseholdServicing {
    func loadUserProfile(userID: String) async throws -> UserProfile? { nil }
    func loadUserProfiles(userIDs: [String]) async throws -> [UserProfile] { [] }
    func loadHousehold(householdID: String) async throws -> Household? { nil }
    func createUserProfile(userID: String, name: String, email: String) async throws {}
    func createHousehold(name: String, owner: UserProfile) async throws -> Household {
        Household(id: "house-1", name: name, inviteCode: "invite", memberIDs: [owner.id], createdByUserID: owner.id, createdAt: Date(), updatedAt: Date())
    }
    func joinHousehold(inviteCode: String, user: UserProfile) async throws -> Household {
        Household(id: "house-1", name: "Home", inviteCode: inviteCode, memberIDs: [user.id], createdByUserID: user.id, createdAt: Date(), updatedAt: Date())
    }
}

private final class MockRecipeService: RecipeServicing {
    func observeRecipes(householdID: String, onChange: @escaping (Result<[Recipe], Error>) -> Void) -> RealtimeListening { MockRealtimeListener() }
    func observeTags(householdID: String, onChange: @escaping (Result<[Tag], Error>) -> Void) -> RealtimeListening { MockRealtimeListener() }
    func observeComments(householdID: String, recipeID: String, onChange: @escaping (Result<[Comment], Error>) -> Void) -> RealtimeListening { MockRealtimeListener() }
    func observeReviews(householdID: String, recipeID: String, onChange: @escaping (Result<[Review], Error>) -> Void) -> RealtimeListening { MockRealtimeListener() }
    func createRecipe(input: RecipeCreationInput, householdID: String, author: UserProfile) async throws {}
    func updateRecipe(recipe: Recipe, householdID: String, title: String, description: String, sourceURL: String, categories: [String], tagNames: [String], ingredients: [String], imageData: Data?) async throws {}
    func deleteRecipe(recipe: Recipe, householdID: String) async throws {}
    func updateTags(recipe: Recipe, householdID: String, tagNames: [String]) async throws {}
    func updateFavorite(recipe: Recipe, householdID: String, isFavorite: Bool) async throws {}
    func addComment(recipe: Recipe, householdID: String, text: String, imageData: Data?, author: UserProfile) async throws {}
    func upsertReview(recipe: Recipe, householdID: String, rating: Int, note: String, author: UserProfile) async throws {}
}

private final class MockRealtimeListener: RealtimeListening {
    func remove() {}
}

private struct MockURLImportService: RecipeURLImportServicing {
    let result: RecipeURLImportResult
    func fetchRecipeData(from urlString: String) async throws -> RecipeURLImportResult { result }
}

private struct MockEnrichmentService: RecipeEnrichmentServicing {
    let extraction: RecipeAIExtraction
    func enrichRecipeContent(using request: RecipeEnrichmentRequest) async throws -> RecipeAIExtraction? { extraction }
    func debugRecipeContent(using request: RecipeEnrichmentRequest) async throws -> RecipeEnrichmentDebugInfo? { nil }
}
