import Foundation
import AuthenticationServices
import CryptoKit
import Security

@MainActor
final class SessionViewModel: ObservableObject {
    @Published private(set) var session: AuthSession?
    @Published private(set) var userProfile: UserProfile?
    @Published var errorMessage: String?
    @Published var isLoading = true
    @Published var isSigningInWithApple = false
    @Published var pendingInviteCode: String?

    private let environment: AppEnvironment
    private var authListener: AuthStateListening?
    private var currentNonce: String?

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

    func prepareAppleSignInRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = Self.randomNonceString()
        currentNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)
    }

    func handleAppleSignInCompletion(_ result: Result<ASAuthorization, Error>) async {
        isSigningInWithApple = true
        defer {
            isSigningInWithApple = false
            currentNonce = nil
        }

        do {
            guard let appleIDCredential = try Self.extractAppleCredential(from: result) else {
                throw NSError(domain: "WeCookinAuth", code: 400, userInfo: [NSLocalizedDescriptionKey: "Apple sign-in did not return a valid credential."])
            }

            guard let nonce = currentNonce else {
                throw NSError(domain: "WeCookinAuth", code: 401, userInfo: [NSLocalizedDescriptionKey: "Apple sign-in state is invalid. Please try again."])
            }

            guard let identityToken = appleIDCredential.identityToken,
                  let idTokenString = String(data: identityToken, encoding: .utf8) else {
                throw NSError(domain: "WeCookinAuth", code: 402, userInfo: [NSLocalizedDescriptionKey: "Could not read the Apple identity token."])
            }

            try await environment.authService.signInWithApple(
                idToken: idTokenString,
                rawNonce: nonce,
                fullName: appleIDCredential.fullName
            )

            let fallbackDisplayName = Self.formattedName(from: appleIDCredential.fullName)
            let fallbackEmail = appleIDCredential.email ?? environment.authService.currentSession?.email ?? ""
            await ensureUserProfileExists(
                displayName: fallbackDisplayName.isEmpty ? "WeCookin User" : fallbackDisplayName,
                email: fallbackEmail
            )
        } catch {
            if let appleError = error as? ASAuthorizationError, appleError.code == .canceled {
                return
            }
            errorMessage = error.localizedDescription
        }
    }

    func signOut() {
        do {
            try environment.authService.signOut()
            pendingInviteCode = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshUserProfile() async {
        guard let session else { return }
        do {
            userProfile = try await environment.householdService.loadUserProfile(userID: session.userID)
            await joinPendingInviteIfPossible()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func handleIncomingURL(_ url: URL) {
        guard url.scheme?.lowercased() == "wecookin" else { return }

        if url.host?.lowercased() == "join",
           let inviteCode = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == "code" })?
            .value?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !inviteCode.isEmpty {
            pendingInviteCode = inviteCode.uppercased()

            Task {
                await joinPendingInviteIfPossible()
            }
        }
    }

    func clearPendingInviteCode() {
        pendingInviteCode = nil
    }

    private func handleAuthState(_ session: AuthSession?) async {
        self.session = session
        self.userProfile = nil
        self.isLoading = false

        guard let session else { return }

        do {
            if let existingProfile = try await environment.householdService.loadUserProfile(userID: session.userID) {
                userProfile = existingProfile
            } else {
                let trimmedName = session.displayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let fallbackName = trimmedName.isEmpty ? "WeCookin User" : trimmedName
                let fallbackEmail = session.email ?? ""
                try await environment.householdService.createUserProfile(
                    userID: session.userID,
                    name: fallbackName,
                    email: fallbackEmail
                )
                userProfile = try await environment.householdService.loadUserProfile(userID: session.userID)
            }
            await joinPendingInviteIfPossible()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func ensureUserProfileExists(displayName: String, email: String) async {
        guard let session = environment.authService.currentSession else { return }

        do {
            let existingProfile = try await environment.householdService.loadUserProfile(userID: session.userID)
            if existingProfile == nil {
                try await environment.householdService.createUserProfile(
                    userID: session.userID,
                    name: displayName,
                    email: email
                )
            }
            userProfile = try await environment.householdService.loadUserProfile(userID: session.userID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private static func extractAppleCredential(from result: Result<ASAuthorization, Error>) throws -> ASAuthorizationAppleIDCredential? {
        switch result {
        case .success(let authorization):
            return authorization.credential as? ASAuthorizationAppleIDCredential
        case .failure(let error):
            throw error
        }
    }

    private static func formattedName(from components: PersonNameComponents?) -> String {
        guard let components else { return "" }
        return PersonNameComponentsFormatter().string(from: components).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func joinPendingInviteIfPossible() async {
        guard let code = pendingInviteCode,
              let userProfile else { return }

        do {
            _ = try await environment.householdService.joinHousehold(inviteCode: code, user: userProfile)
            self.userProfile = try await environment.householdService.loadUserProfile(userID: userProfile.id)
            pendingInviteCode = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private static func sha256(_ input: String) -> String {
        let hashedData = SHA256.hash(data: Data(input.utf8))
        return hashedData.map { String(format: "%02x", $0) }.joined()
    }

    private static func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            let randoms: [UInt8] = (0..<16).map { _ in
                var random: UInt8 = 0
                let status = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if status != errSecSuccess {
                    fatalError("Unable to generate nonce. OSStatus \(status)")
                }
                return random
            }

            randoms.forEach { random in
                if remainingLength == 0 {
                    return
                }

                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }

        return result
    }
}
