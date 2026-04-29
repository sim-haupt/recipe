import Foundation

@MainActor
final class SessionViewModel: ObservableObject {
    @Published private(set) var session: AuthSession?
    @Published private(set) var userProfile: UserProfile?
    @Published var errorMessage: String?
    @Published var isLoading = true

    private let environment: AppEnvironment
    private var authListener: AuthStateListening?

    init(environment: AppEnvironment) {
        self.environment = environment
        authListener = environment.authService.observeAuthState { [weak self] session in
            Task { @MainActor in
                await self?.handleAuthState(session)
            }
        }
    }

    func signIn(email: String, password: String) async {
        do {
            try await environment.authService.signIn(email: email, password: password)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signUp(name: String, email: String, password: String) async {
        do {
            let userID = try await environment.authService.signUp(name: name, email: email, password: password)
            try await environment.householdService.createUserProfile(userID: userID, name: name, email: email)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signOut() {
        do {
            try environment.authService.signOut()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshUserProfile() async {
        guard let session else { return }
        do {
            userProfile = try await environment.householdService.loadUserProfile(userID: session.userID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func handleAuthState(_ session: AuthSession?) async {
        self.session = session
        self.userProfile = nil
        self.isLoading = false

        guard let session else { return }

        do {
            userProfile = try await environment.householdService.loadUserProfile(userID: session.userID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
