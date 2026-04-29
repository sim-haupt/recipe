import SwiftUI

struct AuthView: View {
    @EnvironmentObject private var sessionViewModel: SessionViewModel
    @State private var isCreatingAccount = false
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        NavigationStack {
            ZStack {
                RecipeTheme.pageGradient.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("RecipeNest")
                            .font(.system(size: 38, weight: .bold, design: .rounded))
                        Text("Save recipes from the web, share a household cookbook, and keep notes together.")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }

                    VStack(spacing: 14) {
                        if isCreatingAccount {
                            TextField("Name", text: $name)
                                .textContentType(.name)
                        }

                        TextField("Email", text: $email)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .textContentType(.emailAddress)

                        SecureField("Password", text: $password)
                            .textContentType(isCreatingAccount ? .newPassword : .password)
                    }
                    .textFieldStyle(.roundedBorder)

                    Button(isCreatingAccount ? "Create Account" : "Sign In") {
                        Task {
                            if isCreatingAccount {
                                await sessionViewModel.signUp(name: name, email: email, password: password)
                            } else {
                                await sessionViewModel.signIn(email: email, password: password)
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(RecipeTheme.accentStrong)
                    .controlSize(.large)

                    Button(isCreatingAccount ? "Already have an account? Sign in" : "Need an account? Sign up") {
                        isCreatingAccount.toggle()
                    }
                    .foregroundStyle(RecipeTheme.accentStrong)

                    Spacer()
                }
                .padding(24)
                .frame(maxWidth: 520)
                .background(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .fill(RecipeTheme.card)
                        .shadow(color: RecipeTheme.mintShadow, radius: 22, y: 14)
                )
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}
