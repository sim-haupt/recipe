import Foundation

struct AppEnvironment {
    let authService: AuthServicing
    let householdService: HouseholdServicing
    let recipeService: RecipeServicing
    let urlImportService: RecipeURLImportServicing
    let recipeEnrichmentService: RecipeEnrichmentServicing
    let sharedDraftStore: SharedDraftStore
    let mode: AppMode
    let configurationIssue: String?

    enum AppMode {
        case firebase
        case demo
        case misconfigured
    }

    init(
        authService: AuthServicing,
        householdService: HouseholdServicing,
        recipeService: RecipeServicing,
        urlImportService: RecipeURLImportServicing,
        recipeEnrichmentService: RecipeEnrichmentServicing,
        sharedDraftStore: SharedDraftStore,
        mode: AppMode,
        configurationIssue: String? = nil
    ) {
        self.authService = authService
        self.householdService = householdService
        self.recipeService = recipeService
        self.urlImportService = urlImportService
        self.recipeEnrichmentService = recipeEnrichmentService
        self.sharedDraftStore = sharedDraftStore
        self.mode = mode
        self.configurationIssue = configurationIssue
    }

    static let live = AppEnvironment(
        authService: FirebaseAuthService(),
        householdService: FirestoreHouseholdService(),
        recipeService: FirestoreRecipeService(),
        urlImportService: RecipeURLImportService(),
        recipeEnrichmentService: RecipeEnrichmentService(),
        sharedDraftStore: SharedDraftStore(),
        mode: .firebase,
        configurationIssue: nil
    )

    static let demo = AppEnvironment(
        authService: DemoAuthService(),
        householdService: DemoHouseholdService(),
        recipeService: DemoRecipeService(),
        urlImportService: RecipeURLImportService(),
        recipeEnrichmentService: RecipeEnrichmentService(),
        sharedDraftStore: SharedDraftStore(),
        mode: .demo,
        configurationIssue: nil
    )

    static func misconfigured(message: String) -> AppEnvironment {
        AppEnvironment(
            authService: DemoAuthService(),
            householdService: DemoHouseholdService(),
            recipeService: DemoRecipeService(),
            urlImportService: RecipeURLImportService(),
            recipeEnrichmentService: RecipeEnrichmentService(),
            sharedDraftStore: SharedDraftStore(),
            mode: .misconfigured,
            configurationIssue: message
        )
    }
}
