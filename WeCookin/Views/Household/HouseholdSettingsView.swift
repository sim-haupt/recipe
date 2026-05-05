import SwiftUI
import UIKit

struct HouseholdSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var sessionViewModel: SessionViewModel
    @StateObject private var viewModel: HouseholdSettingsViewModel
    @State private var didCopyCode = false

    init(userProfile: UserProfile, environment: AppEnvironment = .demo) {
        _viewModel = StateObject(wrappedValue: HouseholdSettingsViewModel(environment: environment, userProfile: userProfile))
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    householdCard
                    inviteCard
                    membersCard
                    accountCard
                }
                .padding(20)
            }
            .background(RecipeTheme.pageGradient.ignoresSafeArea())
            .navigationTitle("Household Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
            .task {
                await viewModel.load()
            }
            .alert("Household issue", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    private var householdCard: some View {
        settingsCard(title: "Shared Kitchen") {
            VStack(alignment: .leading, spacing: 10) {
                Text(viewModel.householdName)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(RecipeTheme.textPrimary)

                Text("Everyone who joins this household will see and edit the same shared recipes.")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(RecipeTheme.textSecondary)
            }
        }
    }

    private var inviteCard: some View {
        settingsCard(title: "Invite People") {
            VStack(alignment: .leading, spacing: 14) {
                Text("Invite Code")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(RecipeTheme.textSecondary)

                Text(viewModel.inviteCode.isEmpty ? "No code available yet" : viewModel.inviteCode)
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .foregroundStyle(RecipeTheme.accentStrong)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.white.opacity(0.96))
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(RecipeTheme.strokeSoft, lineWidth: 1)
                            .allowsHitTesting(false)
                    }

                Text("Share this code with specific people. They can open WeCookin' and join the household with this invite code.")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(RecipeTheme.textSecondary)

                HStack(spacing: 12) {
                    Button {
                        UIPasteboard.general.string = viewModel.inviteCode
                        didCopyCode = true
                    } label: {
                        Label(didCopyCode ? "Copied" : "Copy Code", systemImage: didCopyCode ? "checkmark.circle.fill" : "doc.on.doc")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(RecipeTheme.accentStrong)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Color.white.opacity(0.96))
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(RecipeTheme.strokeSoft, lineWidth: 1)
                                    .allowsHitTesting(false)
                            }
                    }
                    .buttonStyle(.plain)

                    ShareLink(item: viewModel.inviteMessage) {
                        Label("Share Invite", systemImage: "square.and.arrow.up")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(RecipeTheme.textOnAccent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(RecipeTheme.accentStrong)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var membersCard: some View {
        settingsCard(title: "Members") {
            VStack(alignment: .leading, spacing: 12) {
                if viewModel.isLoading {
                    ProgressView("Loading members…")
                } else if viewModel.members.isEmpty {
                    Text("No household members found yet.")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(RecipeTheme.textSecondary)
                } else {
                    ForEach(viewModel.members, id: \.id) { member in
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(RecipeTheme.accent.opacity(0.18))
                                Text(initials(for: member.displayName))
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundStyle(RecipeTheme.accentStrong)
                            }
                            .frame(width: 42, height: 42)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(member.displayName.isEmpty ? "WeCookin User" : member.displayName)
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundStyle(RecipeTheme.textPrimary)

                                if !member.email.isEmpty {
                                    Text(member.email)
                                        .font(.system(size: 13, weight: .medium, design: .rounded))
                                        .foregroundStyle(RecipeTheme.textSecondary)
                                }
                            }

                            Spacer()
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color.white.opacity(0.96))
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(RecipeTheme.strokeSoft, lineWidth: 1)
                                .allowsHitTesting(false)
                        }
                    }
                }
            }
        }
    }

    private var accountCard: some View {
        settingsCard(title: "Account") {
            Button(role: .destructive) {
                sessionViewModel.signOut()
                dismiss()
            } label: {
                Text("Sign Out")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.red)
                    )
            }
            .buttonStyle(.plain)
        }
    }

    private func settingsCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(RecipeTheme.textPrimary)

            content()
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RecipeTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .shadow(color: RecipeTheme.shadow, radius: 12, y: 8)
    }

    private func initials(for name: String) -> String {
        let pieces = name.split(separator: " ").prefix(2)
        let joined = pieces.compactMap { $0.first }.map(String.init).joined()
        return joined.isEmpty ? "WK" : joined.uppercased()
    }
}
