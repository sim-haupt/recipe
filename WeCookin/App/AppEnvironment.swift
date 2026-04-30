import Foundation

struct AppEnvironment {
    let authService: AuthServicing
    let householdService: HouseholdServicing
    let recipeService: RecipeServicing
    let urlImportService: RecipeURLImportServicing
    let recipeEnrichmentService: RecipeEnrichmentServicing
    let sharedDraftStore: SharedDraftStore
    let mode: AppMode

    enum AppMode {
        case firebase
        case demo
    }

    static let live = AppEnvironment(
        authService: FirebaseAuthService(),
        householdService: FirestoreHouseholdService(),
        recipeService: FirestoreRecipeService(),
        urlImportService: RecipeURLImportService(),
        recipeEnrichmentService: RecipeEnrichmentService(),
        sharedDraftStore: SharedDraftStore(),
        mode: .firebase
    )

    static let demo = AppEnvironment(
        authService: DemoAuthService(),
        householdService: DemoHouseholdService(),
        recipeService: DemoRecipeService(),
        urlImportService: RecipeURLImportService(),
        recipeEnrichmentService: RecipeEnrichmentService(),
        sharedDraftStore: SharedDraftStore(),
        mode: .demo
    )
}
