import AuthenticationServices
import SwiftUI

struct AuthView: View {
    @EnvironmentObject private var sessionViewModel: SessionViewModel
    @Environment(\.appEnvironment) private var environment

    var body: some View {
        NavigationStack {
            ZStack {
                RecipeTheme.pageGradient.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("WeCookin'")
                            .font(.system(size: 38, weight: .bold, design: .rounded))

                        Text("Sign in with Apple to create or join a shared cookbook. Everyone in the cookbook can add, edit, and save recipes together in real time.")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        featureRow(icon: "person.2.fill", text: "Share the same recipe collection with your cookbook.")
                        featureRow(icon: "square.and.pencil", text: "Everyone can add, edit, and organize recipes.")
                        featureRow(icon: "person.badge.key.fill", text: "Sign in securely with your Apple ID.")
                    }

                    if environment.mode == .firebase {
                        SignInWithAppleButton(.signIn) { request in
                            sessionViewModel.prepareAppleSignInRequest(request)
                        } onCompletion: { result in
                            Task {
                                await sessionViewModel.handleAppleSignInCompletion(result)
                            }
                        }
                        .signInWithAppleButtonStyle(.black)
                        .frame(height: 52)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay {
                            if sessionViewModel.isSigningInWithApple {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Color.black.opacity(0.18))
                                    .overlay {
                                        ProgressView()
                                            .tint(.white)
                                    }
                                    .allowsHitTesting(false)
                            }
                        }
                    } else {
                        Button {
                            Task {
                                await sessionViewModel.signIn(email: "demo@wecookin.local", password: "demo")
                            }
                        } label: {
                            Text("Continue in Demo")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(RecipeTheme.textOnAccent)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(RecipeTheme.accentStrong)
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }

                    Text(environment.mode == .firebase
                         ? "After signing in, you can create a cookbook or join one with an invite code."
                         : "Demo mode signs you into the shared sample cookbook automatically.")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)

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

    private func featureRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(RecipeTheme.accentStrong)
                .frame(width: 24, height: 24)

            Text(text)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(RecipeTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
