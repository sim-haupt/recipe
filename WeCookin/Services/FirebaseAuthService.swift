import FirebaseAuth
import Foundation

final class FirebaseAuthService: AuthServicing {
    var currentSession: AuthSession? {
        guard let user = Auth.auth().currentUser else { return nil }
        return AuthSession(userID: user.uid, email: user.email)
    }

    func observeAuthState(_ handler: @escaping (AuthSession?) -> Void) -> AuthStateListening {
        FirebaseAuthStateListener(handler: handler)
    }

    func signIn(email: String, password: String) async throws {
        _ = try await Auth.auth().signIn(withEmail: email, password: password)
    }

    func signUp(name: String, email: String, password: String) async throws -> String {
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        let request = result.user.createProfileChangeRequest()
        request.displayName = name
        try await request.commitChanges()
        return result.user.uid
    }

    func signOut() throws {
        try Auth.auth().signOut()
    }
}

private final class FirebaseAuthStateListener: AuthStateListening {
    private var handle: AuthStateDidChangeListenerHandle?

    init(handler: @escaping (AuthSession?) -> Void) {
        handle = Auth.auth().addStateDidChangeListener { _, user in
            if let user {
                handler(AuthSession(userID: user.uid, email: user.email))
            } else {
                handler(nil)
            }
        }
    }

    func cancel() {
        if let handle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
        handle = nil
    }

    deinit {
        cancel()
    }
}
