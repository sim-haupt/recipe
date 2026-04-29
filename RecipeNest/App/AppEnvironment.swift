import Foundation

struct AppEnvironment {
    let authService: AuthServicing
    let householdService: HouseholdServicing
    let recipeService: RecipeServicing
    let sharedDraftStore: SharedDraftStore

    static let live = AppEnvironment(
        authService: FirebaseAuthService(),
        householdService: FirestoreHouseholdService(),
        recipeService: FirestoreRecipeService(),
        sharedDraftStore: SharedDraftStore()
    )
}
