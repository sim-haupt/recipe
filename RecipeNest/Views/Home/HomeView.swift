import SwiftUI

struct HomeView: View {
    @Environment(\.appEnvironment) private var environment
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var sessionViewModel: SessionViewModel
    @FocusState private var isSearchFocused: Bool
    @StateObject private var viewModel: HomeViewModel

    let userProfile: UserProfile

    init(userProfile: UserProfile, environment: AppEnvironment = .demo) {
        self.userProfile = userProfile
        _viewModel = StateObject(wrappedValue: HomeViewModel(environment: environment, userProfile: userProfile))
    }

    private var popularRecipes: [Recipe] {
        viewModel.favoriteRecipes
    }

    private var recentRecipes: [Recipe] {
        viewModel.filteredRecipes.sorted { $0.savedDate > $1.savedDate }
    }

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                let metrics = HomeLayoutMetrics(availableWidth: proxy.size.width)
                let topInset = proxy.safeAreaInsets.top
                let bottomInset = proxy.safeAreaInsets.bottom

                ZStack {
                    RecipeTheme.homeBackdrop
                        .ignoresSafeArea()

                    backgroundDecor(metrics: metrics)

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {
                            HomeHeroSection(
                                metrics: metrics,
                                topInset: topInset,
                                initials: userInitials,
                                greeting: "Hello, \(firstName)",
                                subtitle: "Save beautiful recipes from anywhere.",
                                searchText: $viewModel.searchText,
                                isSearchFocused: $isSearchFocused,
                                activeFilterCount: viewModel.selectedTags.count,
                                savedCount: recentRecipes.count,
                                favoriteCount: popularRecipes.count,
                                addAction: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.84)) {
                                        viewModel.isShowingAddRecipe = true
                                    }
                                },
                                filterAction: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.84)) {
                                        viewModel.selectedTags.removeAll()
                                    }
                                }
                            )

                            VStack(alignment: .leading, spacing: metrics.sectionSpacing) {
                                categoriesSection(metrics: metrics)
                                favoritesSection(metrics: metrics)
                                librarySection(metrics: metrics)
                            }
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            .padding(.horizontal, metrics.horizontalPadding)
                            .padding(.top, metrics.panelTopPadding)
                            .padding(.bottom, metrics.panelBottomPadding + bottomInset)
                            .background {
                                UnevenRoundedRectangle(
                                    topLeadingRadius: metrics.panelRadius,
                                    bottomLeadingRadius: 0,
                                    bottomTrailingRadius: 0,
                                    topTrailingRadius: metrics.panelRadius,
                                    style: .continuous
                                )
                                .fill(RecipeTheme.contentBackground.opacity(0.97))
                                .overlay {
                                    UnevenRoundedRectangle(
                                        topLeadingRadius: metrics.panelRadius,
                                        bottomLeadingRadius: 0,
                                        bottomTrailingRadius: 0,
                                        topTrailingRadius: metrics.panelRadius,
                                        style: .continuous
                                    )
                                    .stroke(Color.white.opacity(0.72), lineWidth: 1)
                                }
                                .shadow(color: RecipeTheme.shadow.opacity(0.08), radius: 22, y: -2)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .top)
                        .frame(minHeight: proxy.size.height, alignment: .top)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    HomeBottomDock(
                        metrics: metrics,
                        bottomInset: bottomInset,
                        addAction: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.84)) {
                                viewModel.isShowingAddRecipe = true
                            }
                        },
                        signOutAction: {
                            sessionViewModel.signOut()
                        }
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(RecipeTheme.homeBackdrop.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $viewModel.isShowingAddRecipe) {
                AddRecipeView(userProfile: userProfile, environment: environment)
            }
            .task {
                viewModel.start()
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else { return }
                Task {
                    await viewModel.importPendingDraftsIfNeeded()
                }
            }
            .alert("Recipe sync issue", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RecipeTheme.homeBackdrop.ignoresSafeArea())
        .environment(\.appEnvironment, environment)
    }

    @ViewBuilder
    private func backgroundDecor(metrics: HomeLayoutMetrics) -> some View {
        ZStack(alignment: .top) {
            Circle()
                .fill(RecipeTheme.accent.opacity(0.14))
                .frame(width: metrics.backdropOrbOne, height: metrics.backdropOrbOne)
                .blur(radius: 10)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, -metrics.availableWidth * 0.18)
                .padding(.top, -metrics.availableWidth * 0.12)

            Circle()
                .fill(Color.white.opacity(0.38))
                .frame(width: metrics.backdropOrbTwo, height: metrics.backdropOrbTwo)
                .blur(radius: 24)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .padding(.leading, -metrics.availableWidth * 0.20)
                .padding(.top, metrics.availableWidth * 0.56)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .allowsHitTesting(false)
    }

    private func categoriesSection(metrics: HomeLayoutMetrics) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HomeSectionHeader(
                title: "Categories",
                actionTitle: selectedTagSummary,
                metrics: metrics
            )

            if viewModel.tags.isEmpty {
                HomeEmptyCard(message: "Tags you add to recipes will appear here.")
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(viewModel.tags) { tag in
                            CategoryBadge(
                                title: tag.name,
                                isSelected: viewModel.selectedTags.contains(tag.name),
                                action: {
                                    withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                                        viewModel.toggle(tag: tag)
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 1)
                }
            }
        }
    }

    private func favoritesSection(metrics: HomeLayoutMetrics) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HomeSectionHeader(
                title: "Popular Recipes",
                actionTitle: popularRecipes.isEmpty ? "No favorites yet" : "\(popularRecipes.count) saved",
                metrics: metrics
            )

            if popularRecipes.isEmpty {
                HomeEmptyCard(message: "Favorite a recipe and it will appear here.")
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(popularRecipes.prefix(8)) { recipe in
                            NavigationLink {
                                RecipeDetailView(recipe: recipe, userProfile: userProfile, environment: environment)
                            } label: {
                                RecipeCardView(
                                    recipe: recipe,
                                    imageHeight: metrics.featuredImageHeight,
                                    titleFontSize: metrics.featuredCardTitleSize,
                                    favoriteAction: {
                                        Task { await viewModel.toggleFavorite(recipe) }
                                    }
                                )
                                .frame(width: metrics.featuredCardWidth)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 1)
                }
            }
        }
    }

    private func librarySection(metrics: HomeLayoutMetrics) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HomeSectionHeader(
                title: "Recipe Library",
                actionTitle: "\(recentRecipes.count) total",
                metrics: metrics
            )

            if recentRecipes.isEmpty {
                HomeEmptyCard(message: "Use the add button to start your household cookbook.")
            } else {
                LazyVStack(spacing: 16) {
                    ForEach(recentRecipes) { recipe in
                        NavigationLink {
                            RecipeDetailView(recipe: recipe, userProfile: userProfile, environment: environment)
                        } label: {
                            RecipeCardView(
                                recipe: recipe,
                                imageHeight: metrics.listImageHeight,
                                titleFontSize: metrics.listCardTitleSize,
                                favoriteAction: {
                                    Task { await viewModel.toggleFavorite(recipe) }
                                }
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var firstName: String {
        userProfile.displayName
            .split(separator: " ")
            .first
            .map(String.init) ?? userProfile.displayName
    }

    private var userInitials: String {
        let pieces = userProfile.displayName.split(separator: " ")
        let firstTwo = pieces.prefix(2).compactMap { $0.first }
        let initials = String(firstTwo)
        return initials.isEmpty ? "RN" : initials
    }

    private var selectedTagSummary: String {
        if viewModel.selectedTags.isEmpty {
            return "All"
        }

        return viewModel.selectedTags.sorted().joined(separator: ", ")
    }
}

private struct HomeHeroSection: View {
    let metrics: HomeLayoutMetrics
    let topInset: CGFloat
    let initials: String
    let greeting: String
    let subtitle: String
    @Binding var searchText: String
    @FocusState.Binding var isSearchFocused: Bool
    let activeFilterCount: Int
    let savedCount: Int
    let favoriteCount: Int
    let addAction: () -> Void
    let filterAction: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(RecipeTheme.heroGradient)
                .overlay(alignment: .topTrailing) {
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                            .frame(width: metrics.heroRingOne, height: metrics.heroRingOne)
                            .offset(x: metrics.availableWidth * 0.14, y: metrics.heroHeight * 0.10)

                        Circle()
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            .frame(width: metrics.heroRingTwo, height: metrics.heroRingTwo)
                            .offset(x: metrics.availableWidth * 0.04, y: metrics.heroHeight * 0.18)
                    }
                }

            VStack(alignment: .leading, spacing: metrics.heroContentSpacing) {
                HStack(alignment: .center, spacing: 14) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.22))
                            Text(initials)
                                .font(.system(size: metrics.avatarFontSize, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                        }
                        .frame(width: metrics.avatarSize, height: metrics.avatarSize)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(greeting)
                                .font(.system(size: metrics.heroTitleSize, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            Text(subtitle)
                                .font(.system(size: metrics.heroSubtitleSize, weight: .medium, design: .rounded))
                                .foregroundStyle(Color.white.opacity(0.84))
                                .lineLimit(1)
                        }
                    }

                    Spacer(minLength: 8)

                    Button(action: addAction) {
                        Image(systemName: "plus")
                            .font(.system(size: metrics.heroActionIconSize, weight: .bold))
                            .foregroundStyle(RecipeTheme.accentStrong)
                            .frame(width: metrics.heroActionSize, height: metrics.heroActionSize)
                            .background(Color.white)
                            .clipShape(Circle())
                            .shadow(color: Color.black.opacity(0.12), radius: 14, y: 8)
                    }
                    .buttonStyle(PressableScaleButtonStyle())
                }

                HStack(spacing: 12) {
                    HomeSearchBar(
                        text: $searchText,
                        isFocused: $isSearchFocused,
                        height: metrics.searchBarHeight
                    )

                    FilterButton(
                        isActive: activeFilterCount > 0,
                        count: activeFilterCount,
                        side: metrics.searchBarHeight,
                        action: filterAction
                    )
                }

                HStack(spacing: 10) {
                    HeroMetricPill(title: "Saved", value: savedCount)
                    HeroMetricPill(title: "Favorites", value: favoriteCount)
                }
            }
            .padding(.top, topInset + metrics.heroTopPadding)
            .padding(.horizontal, metrics.horizontalPadding)
            .padding(.bottom, metrics.heroBottomPadding)
        }
        .frame(maxWidth: .infinity)
        .frame(height: metrics.heroHeight + topInset, alignment: .top)
    }
}

private struct HomeSearchBar: View {
    @Binding var text: String
    @FocusState.Binding var isFocused: Bool
    let height: CGFloat

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(isFocused ? RecipeTheme.accentStrong : Color.black.opacity(0.34))

            TextField("", text: $text, prompt: Text("Search recipes").foregroundStyle(Color.black.opacity(0.28)))
                .focused($isFocused)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .font(.system(size: 16, weight: .medium, design: .rounded))
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.97))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(isFocused ? Color.white.opacity(0.95) : Color.white.opacity(0.45), lineWidth: isFocused ? 1.5 : 1)
        }
        .shadow(color: Color.black.opacity(isFocused ? 0.10 : 0.07), radius: 12, y: 6)
    }
}

private struct FilterButton: View {
    let isActive: Bool
    let count: Int
    let side: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.97))
                    .frame(width: side, height: side)

                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(isActive ? RecipeTheme.accentStrong : Color.black.opacity(0.34))

                if isActive {
                    Text("\(min(count, 9))")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(minWidth: 18, minHeight: 18)
                        .background(RecipeTheme.accentStrong)
                        .clipShape(Capsule())
                        .padding(.trailing, -7)
                        .padding(.top, -7)
                }
            }
            .shadow(color: Color.black.opacity(0.08), radius: 10, y: 5)
        }
        .buttonStyle(PressableScaleButtonStyle())
    }
}

private struct HeroMetricPill: View {
    let title: String
    let value: Int

    var body: some View {
        HStack(spacing: 8) {
            Text("\(value)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
            Text(title)
                .font(.system(size: 12, weight: .medium, design: .rounded))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.14))
        .clipShape(Capsule())
    }
}

private struct HomeSectionHeader: View {
    let title: String
    let actionTitle: String
    let metrics: HomeLayoutMetrics

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: metrics.sectionTitleSize, weight: .bold, design: .rounded))
                .foregroundStyle(RecipeTheme.textPrimary)

            Spacer(minLength: 12)

            Text(actionTitle)
                .font(.system(size: metrics.sectionCaptionSize, weight: .semibold, design: .rounded))
                .foregroundStyle(RecipeTheme.accentStrong)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
    }
}

private struct CategoryBadge: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Circle()
                    .fill(isSelected ? Color.white : RecipeTheme.accent.opacity(0.24))
                    .frame(width: 7, height: 7)

                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(isSelected ? .white : RecipeTheme.accentStrong)
                    .lineLimit(1)
            }
            .padding(.horizontal, 15)
            .frame(height: 42)
            .background(
                Capsule()
                    .fill(isSelected ? RecipeTheme.accentStrong : RecipeTheme.surface)
            )
            .overlay {
                Capsule()
                    .stroke(isSelected ? Color.clear : RecipeTheme.strokeSoft, lineWidth: 1)
            }
            .shadow(color: isSelected ? RecipeTheme.mintShadow : RecipeTheme.shadow.opacity(0.45), radius: 10, y: 5)
        }
        .buttonStyle(PressableScaleButtonStyle())
    }
}

struct RecipeTagPill: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(RecipeTheme.accentStrong)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(RecipeTheme.accentSoft)
            )
    }
}

struct RecipeRatingPill: View {
    let rating: Double
    let reviewCount: Int

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "star.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color(red: 1.0, green: 0.74, blue: 0.24))

            Text(String(format: "%.1f", rating))
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(RecipeTheme.textPrimary)

            if reviewCount > 0 {
                Text("(\(reviewCount))")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(RecipeTheme.textSecondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.94))
        )
    }
}

private struct HomeEmptyCard: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.system(size: 14, weight: .medium, design: .rounded))
            .foregroundStyle(RecipeTheme.textSecondary)
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(RecipeTheme.surface)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(RecipeTheme.strokeSoft, lineWidth: 1)
            }
    }
}

private struct HomeBottomDock: View {
    let metrics: HomeLayoutMetrics
    let bottomInset: CGFloat
    let addAction: () -> Void
    let signOutAction: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            HomeBottomDockItem(systemName: "house.fill", title: "Home", isActive: true, action: {})

            Button(action: addAction) {
                ZStack {
                    Circle()
                        .fill(RecipeTheme.heroGradient)
                        .frame(width: metrics.dockCenterButtonSize, height: metrics.dockCenterButtonSize)
                        .shadow(color: RecipeTheme.heroGlow, radius: 18, y: 8)

                    Image(systemName: "plus")
                        .font(.system(size: metrics.dockCenterIconSize, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PressableScaleButtonStyle())

            HomeBottomDockItem(systemName: "rectangle.portrait.and.arrow.right", title: "Sign Out", isActive: false, action: signOutAction)
        }
        .padding(.horizontal, metrics.dockHorizontalPadding)
        .padding(.top, 12)
        .padding(.bottom, max(bottomInset, 12))
        .frame(maxWidth: .infinity)
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Color.white.opacity(0.55))
                        .frame(height: 1)
                }
                .ignoresSafeArea(edges: .bottom)
        }
    }
}

private struct HomeBottomDockItem: View {
    let systemName: String
    let title: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: systemName)
                    .font(.system(size: 18, weight: .semibold))
                Text(title)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
            }
            .foregroundStyle(isActive ? RecipeTheme.accentStrong : RecipeTheme.textSecondary)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PressableScaleButtonStyle())
    }
}

struct PressableScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.82), value: configuration.isPressed)
    }
}

private struct HomeLayoutMetrics {
    let availableWidth: CGFloat

    var horizontalPadding: CGFloat { availableWidth < 380 ? 16 : 20 }
    var sectionSpacing: CGFloat { availableWidth < 380 ? 24 : 28 }
    var heroHeight: CGFloat { availableWidth < 380 ? 256 : 278 }
    var heroTopPadding: CGFloat { availableWidth < 380 ? 8 : 10 }
    var heroBottomPadding: CGFloat { availableWidth < 380 ? 28 : 30 }
    var heroContentSpacing: CGFloat { availableWidth < 380 ? 16 : 18 }
    var avatarSize: CGFloat { availableWidth < 380 ? 44 : 48 }
    var avatarFontSize: CGFloat { availableWidth < 380 ? 14 : 15 }
    var heroTitleSize: CGFloat { availableWidth < 380 ? 17 : 18 }
    var heroSubtitleSize: CGFloat { availableWidth < 380 ? 12 : 13 }
    var heroActionSize: CGFloat { availableWidth < 380 ? 48 : 52 }
    var heroActionIconSize: CGFloat { availableWidth < 380 ? 18 : 19 }
    var searchBarHeight: CGFloat { availableWidth < 380 ? 54 : 58 }
    var heroRingOne: CGFloat { availableWidth * 0.64 }
    var heroRingTwo: CGFloat { availableWidth * 0.96 }

    var panelRadius: CGFloat { availableWidth < 380 ? 30 : 34 }
    var panelTopPadding: CGFloat { availableWidth < 380 ? 22 : 26 }
    var panelBottomPadding: CGFloat { availableWidth < 380 ? 108 : 116 }

    var featuredCardWidth: CGFloat { min(max((availableWidth - (horizontalPadding * 2)) * 0.84, 286), 380) }
    var featuredImageHeight: CGFloat { availableWidth < 380 ? 214 : 232 }
    var featuredCardTitleSize: CGFloat { availableWidth < 380 ? 17 : 18 }
    var listImageHeight: CGFloat { availableWidth < 380 ? 196 : 214 }
    var listCardTitleSize: CGFloat { availableWidth < 380 ? 16 : 17 }

    var sectionTitleSize: CGFloat { availableWidth < 380 ? 20 : 22 }
    var sectionCaptionSize: CGFloat { availableWidth < 380 ? 11 : 12 }

    var dockHorizontalPadding: CGFloat { availableWidth < 380 ? 20 : 24 }
    var dockCenterButtonSize: CGFloat { availableWidth < 380 ? 60 : 64 }
    var dockCenterIconSize: CGFloat { availableWidth < 380 ? 23 : 24 }

    var backdropOrbOne: CGFloat { availableWidth * 0.84 }
    var backdropOrbTwo: CGFloat { availableWidth * 0.68 }
}

private enum HomePreviewData {
    static let user = UserProfile(
        id: "preview-user",
        displayName: "Demo Cook",
        email: "demo@example.com",
        activeHouseholdID: "preview-household",
        householdIDs: ["preview-household"],
        createdAt: .now,
        updatedAt: .now
    )
}

private struct HomePreviewHost: View {
    private let sessionViewModel = SessionViewModel(environment: .demo)

    var body: some View {
        GeometryReader { _ in
            HomeView(userProfile: HomePreviewData.user, environment: .demo)
                .environmentObject(sessionViewModel)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(RecipeTheme.homeBackdrop.ignoresSafeArea())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RecipeTheme.homeBackdrop.ignoresSafeArea())
    }
}

#Preview("iPhone 16 Pro") {
    HomePreviewHost()
}

#Preview("iPhone SE") {
    HomePreviewHost()
        .previewDevice("iPhone SE (3rd generation)")
}

#Preview("iPhone 16 Pro Max") {
    HomePreviewHost()
        .previewDevice("iPhone 16 Pro Max")
}
