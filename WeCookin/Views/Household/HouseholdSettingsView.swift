import PhotosUI
import SwiftUI
import UIKit

struct HouseholdSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var sessionViewModel: SessionViewModel
    @StateObject private var viewModel: HouseholdSettingsViewModel
    @State private var selectedProfilePhoto: PhotosPickerItem?
    @State private var selectedProfilePhotoData: Data?
    @State private var didCopyLink = false

    init(userProfile: UserProfile, environment: AppEnvironment = .demo) {
        _viewModel = StateObject(wrappedValue: HouseholdSettingsViewModel(environment: environment, userProfile: userProfile))
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    profileCard
                    createHouseholdCard
                    householdListCard
                    accountCard
                }
                .padding(20)
            }
            .background(RecipeTheme.pageGradient.ignoresSafeArea())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
            .task {
                await viewModel.load()
                await sessionViewModel.refreshUserProfile()
            }
            .onChange(of: selectedProfilePhoto) { _, newValue in
                guard let newValue else { return }
                Task {
                    selectedProfilePhotoData = try? await newValue.loadTransferable(type: Data.self)
                }
            }
            .alert("Settings issue", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    private var profileCard: some View {
        settingsCard(title: "Profile") {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 16) {
                    PhotosPicker(selection: $selectedProfilePhoto, matching: .images) {
                        profileAvatar(size: 76)
                            .overlay(alignment: .bottomTrailing) {
                                Image(systemName: "camera.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundStyle(RecipeTheme.accentStrong)
                                    .background(Color.white.clipShape(Circle()))
                            }
                    }
                    .buttonStyle(.plain)

                    VStack(alignment: .leading, spacing: 6) {
                        TextField("Your name", text: $viewModel.editableDisplayName)
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(RecipeTheme.textPrimary)
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 2)

                        if let email = viewModel.currentUserProfile?.email, !email.isEmpty {
                            Text(email)
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(RecipeTheme.textSecondary)
                                .padding(.horizontal, 2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 10)
                }

                Button {
                    Task {
                        await viewModel.saveProfile(imageData: selectedProfilePhotoData)
                        await sessionViewModel.refreshUserProfile()
                        selectedProfilePhotoData = nil
                        selectedProfilePhoto = nil
                    }
                } label: {
                    Text(viewModel.isSavingProfile ? "Saving..." : "Save Profile")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(RecipeTheme.textOnAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(RecipeTheme.accentStrong)
                        )
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isSavingProfile)
            }
        }
    }

    private var createHouseholdCard: some View {
        settingsCard(title: "Create Cookbook") {
            VStack(alignment: .leading, spacing: 14) {
                TextField("Cookbook name", text: $viewModel.newHouseholdName)
                    .recipeSettingsInputStyle(borderColor: Color.black.opacity(0.10), lineWidth: 1.4)

                Button {
                    Task {
                        await viewModel.createHousehold()
                        await sessionViewModel.refreshUserProfile()
                    }
                } label: {
                    Text(viewModel.isCreatingHousehold ? "Creating..." : "Create Cookbook")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(RecipeTheme.textOnAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(RecipeTheme.accentStrong)
                        )
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isCreatingHousehold || viewModel.newHouseholdName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private var householdListCard: some View {
        settingsCard(title: "My Cookbooks") {
            VStack(alignment: .leading, spacing: 12) {
                if viewModel.isLoading {
                    ProgressView("Loading cookbooks…")
                } else if viewModel.households.isEmpty {
                    Text("Create your first cookbook to start sharing recipes.")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(RecipeTheme.textSecondary)
                } else {
                    ForEach(viewModel.households, id: \.id) { household in
                        let isActive = viewModel.currentUserProfile?.activeHouseholdID == household.id
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 12) {
                                Button {
                                    Task {
                                        await viewModel.setActiveHousehold(household)
                                        await sessionViewModel.refreshUserProfile()
                                    }
                                } label: {
                                    HStack(spacing: 12) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(household.name)
                                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                                .foregroundStyle(RecipeTheme.textPrimary)

                                            Text(isActive ? "Active cookbook" : "Tap to make active")
                                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                                .foregroundStyle(isActive ? RecipeTheme.accentStrong : RecipeTheme.textSecondary)
                                        }

                                        Spacer()

                                        Image(systemName: isActive ? "checkmark.circle.fill" : "circle")
                                            .font(.system(size: 18, weight: .semibold))
                                            .foregroundStyle(isActive ? RecipeTheme.accentStrong : RecipeTheme.textSecondary)
                                    }
                                }
                                .buttonStyle(.plain)
                                .disabled(viewModel.isSwitchingHousehold)

                                Spacer(minLength: 0)

                                Button {
                                    UIPasteboard.general.string = viewModel.shareLink(for: household)
                                    didCopyLink = true
                                } label: {
                                    Image(systemName: "doc.on.doc")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(RecipeTheme.accentStrong)
                                        .frame(width: 34, height: 34)
                                        .background(Color.white.opacity(0.92))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)

                                if let inviteURL = URL(string: viewModel.shareLink(for: household)) {
                                    ShareLink(
                                        item: inviteURL,
                                        subject: Text("Join my WeCookin' cookbook"),
                                        message: Text("Join my WeCookin' cookbook \"\(household.name)\" using this link.")
                                    ) {
                                        Image(systemName: "square.and.arrow.up")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundStyle(RecipeTheme.accentStrong)
                                            .frame(width: 34, height: 34)
                                            .background(Color.white.opacity(0.92))
                                            .clipShape(Circle())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }

                            let householdMembers = viewModel.members(for: household)
                            if !householdMembers.isEmpty {
                                Text(householdMembers.map { $0.displayName.isEmpty ? "WeCookin User" : $0.displayName }.joined(separator: ", "))
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundStyle(RecipeTheme.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
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
            Button {
                sessionViewModel.signOut()
                dismiss()
            } label: {
                Text("Sign Out")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(RecipeTheme.accentStrong)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.white.opacity(0.96))
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(RecipeTheme.accentStrong, lineWidth: 1.4)
                            .allowsHitTesting(false)
                    }
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

    @ViewBuilder
    private func profileAvatar(size: CGFloat) -> some View {
        if let selectedProfilePhotoData,
           let image = UIImage(data: selectedProfilePhotoData) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else if let profileURL = viewModel.currentUserProfile?.profileImageURL {
            RemoteRecipeImage(imageURL: profileURL, width: size, height: size)
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else {
            initialsAvatar(name: viewModel.currentUserProfile?.displayName ?? viewModel.editableDisplayName, size: size)
        }
    }

    @ViewBuilder
    private func memberAvatar(_ member: UserProfile, size: CGFloat) -> some View {
        if let profileURL = member.profileImageURL {
            RemoteRecipeImage(imageURL: profileURL, width: size, height: size)
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else {
            initialsAvatar(name: member.displayName, size: size)
        }
    }

    private func initialsAvatar(name: String, size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(RecipeTheme.accent.opacity(0.18))
            Text(initials(for: name))
                .font(.system(size: size * 0.34, weight: .bold, design: .rounded))
                .foregroundStyle(RecipeTheme.accentStrong)
        }
        .frame(width: size, height: size)
    }

    private func initials(for name: String) -> String {
        let pieces = name.split(separator: " ").prefix(2)
        let joined = pieces.compactMap { $0.first }.map(String.init).joined()
        return joined.isEmpty ? "WK" : joined.uppercased()
    }
}

private extension View {
    func recipeSettingsInputStyle(
        minHeight: CGFloat = 56,
        borderColor: Color = RecipeTheme.strokeSoft,
        lineWidth: CGFloat = 1
    ) -> some View {
        self
            .font(.system(size: 16, weight: .medium, design: .rounded))
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.96))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(borderColor, lineWidth: lineWidth)
                    .allowsHitTesting(false)
            }
    }
}
