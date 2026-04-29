import SwiftUI

struct HomeView: View {
    @Environment(\.appEnvironment) private var environment
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var sessionViewModel: SessionViewModel
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
        GeometryReader { proxy in
            let metrics = HomeLayoutMetrics(availableWidth: proxy.size.width)
            let topInset = proxy.safeAreaInsets.top
            let bottomInset = proxy.safeAreaInsets.bottom

            NavigationStack {
                ZStack {
                    RecipeTheme.pageGradient.ignoresSafeArea()

                    VStack(spacing: 0) {
                        heroHeader(metrics: metrics, topInset: topInset)

                        ScrollView(showsIndicators: false) {
                            VStack(alignment: .leading, spacing: metrics.sectionSpacing) {
                                categoriesSection(metrics: metrics)
                                popularSection(metrics: metrics)
                                allRecipesSection(metrics: metrics)
                            }
                            .frame(maxWidth: metrics.contentWidth, alignment: .leading)
                            .padding(.horizontal, metrics.contentHorizontalPadding)
                            .padding(.top, metrics.contentTopPadding)
                            .padding(.bottom, metrics.bottomInsetPadding)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                    VStack {
                        Spacer()
                        homeBottomBar(metrics: metrics, bottomInset: bottomInset)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        }
        .environment(\.appEnvironment, environment)
    }

    private func heroHeader(metrics: HomeLayoutMetrics, topInset: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: metrics.heroCornerRadius,
                bottomTrailingRadius: metrics.heroCornerRadius,
                topTrailingRadius: 0,
                style: .continuous
            )
                .fill(RecipeTheme.heroGradient)
                .overlay {
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                            .frame(width: metrics.heroCircleOneSize, height: metrics.heroCircleOneSize)
                            .offset(x: metrics.heroCircleOneOffsetX, y: metrics.heroCircleOneOffsetY)

                        Circle()
                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                            .frame(width: metrics.heroCircleTwoSize, height: metrics.heroCircleTwoSize)
                            .offset(x: metrics.heroCircleTwoOffsetX, y: metrics.heroCircleTwoOffsetY)
                    }
                }
                .shadow(color: RecipeTheme.mintShadow, radius: 24, y: 18)

            VStack(alignment: .leading, spacing: metrics.heroSpacing) {
                HStack(spacing: metrics.heroHeaderSpacing) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.22))
                            .frame(width: metrics.avatarSize, height: metrics.avatarSize)
                        Text(userInitials)
                            .font(.system(size: metrics.avatarFontSize, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Hello, \(firstName)")
                            .font(.system(size: metrics.heroTitleFont, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Text("Check amazing recipes...")
                            .font(.system(size: metrics.heroSubtitleFont, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.88))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }

                    Spacer()

                    Button {
                        viewModel.isShowingAddRecipe = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: metrics.heroButtonSymbolSize, weight: .bold))
                            .foregroundStyle(RecipeTheme.accentStrong)
                            .frame(width: metrics.heroButtonSize, height: metrics.heroButtonSize)
                            .background(Color.white)
                            .clipShape(Circle())
                    }
                }

                HStack(spacing: metrics.searchSpacing) {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(RecipeTheme.textSecondary)
                        TextField("Search Any Recipe..", text: $viewModel.searchText)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    .padding(.horizontal, 14)
                    .frame(height: metrics.searchBarHeight)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    Button {
                        viewModel.selectedTags.removeAll()
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: metrics.filterSymbolSize, weight: .bold))
                            .foregroundStyle(viewModel.selectedTags.isEmpty ? RecipeTheme.textSecondary : RecipeTheme.accentStrong)
                            .frame(width: metrics.searchBarHeight, height: metrics.searchBarHeight)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .disabled(viewModel.selectedTags.isEmpty)
                }
            }
            .padding(.top, topInset + metrics.heroTopPadding)
            .padding(.horizontal, metrics.heroHorizontalPadding)
            .padding(.bottom, metrics.heroBottomPadding)
        }
        .frame(maxWidth: .infinity)
        .frame(height: metrics.heroHeight + topInset)
    }

    private func categoriesSection(metrics: HomeLayoutMetrics) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "Categories", actionTitle: selectedTagSummary, metrics: metrics)

            if viewModel.tags.isEmpty {
                emptyCard(message: "Tags you add to recipes will appear here.")
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(viewModel.tags) { tag in
                            CategoryPill(
                                title: tag.name,
                                isSelected: viewModel.selectedTags.contains(tag.name),
                                metrics: metrics
                            ) {
                                viewModel.toggle(tag: tag)
                            }
                        }
                    }
                    .padding(.horizontal, 1)
                }
            }
        }
    }

    private func popularSection(metrics: HomeLayoutMetrics) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "Popular Recipes", actionTitle: "\(popularRecipes.count) saved", metrics: metrics)

            if popularRecipes.isEmpty {
                emptyCard(message: "Save a few recipes and they’ll show up here.")
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(popularRecipes.prefix(6)) { recipe in
                            NavigationLink {
                                RecipeDetailView(recipe: recipe, userProfile: userProfile, environment: environment)
                            } label: {
                                RecipeCardView(
                                    recipe: recipe,
                                    imageHeight: metrics.featuredCardImageHeight,
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

    private func allRecipesSection(metrics: HomeLayoutMetrics) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "All Recipes", actionTitle: "\(recentRecipes.count) total", metrics: metrics)

            if recentRecipes.isEmpty {
                emptyCard(message: "Use the add button to start your household cookbook.")
            } else {
                VStack(spacing: 16) {
                    ForEach(recentRecipes) { recipe in
                        NavigationLink {
                            RecipeDetailView(recipe: recipe, userProfile: userProfile, environment: environment)
                        } label: {
                            RecipeCardView(
                                recipe: recipe,
                                imageHeight: metrics.listCardImageHeight,
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

    private func homeBottomBar(metrics: HomeLayoutMetrics, bottomInset: CGFloat) -> some View {
        HStack(spacing: 0) {
            bottomBarButton(systemName: "house.fill", title: "Home", isActive: true, metrics: metrics) {}

            Button {
                viewModel.isShowingAddRecipe = true
            } label: {
                ZStack {
                    Circle()
                        .fill(RecipeTheme.heroGradient)
                        .frame(width: metrics.bottomBarCenterButtonSize, height: metrics.bottomBarCenterButtonSize)
                    Image(systemName: "plus")
                        .font(.system(size: metrics.bottomBarCenterIconSize, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)

            bottomBarButton(systemName: "rectangle.portrait.and.arrow.right", title: "Sign Out", isActive: false, metrics: metrics) {
                sessionViewModel.signOut()
            }
        }
        .padding(.horizontal, metrics.bottomBarHorizontalPadding)
        .padding(.top, metrics.bottomBarTopPadding)
        .padding(.bottom, max(bottomInset, metrics.bottomBarBottomPadding))
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea(edges: .bottom)
                .overlay(alignment: .top) {
                    Divider()
                }
        }
        .frame(maxWidth: .infinity)
    }

    private func bottomBarButton(systemName: String, title: String, isActive: Bool, metrics: HomeLayoutMetrics, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: systemName)
                    .font(.system(size: metrics.bottomBarIconSize, weight: .semibold))
                Text(title)
                    .font(.system(size: metrics.bottomBarLabelSize, weight: .medium, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(isActive ? RecipeTheme.accentStrong : RecipeTheme.textSecondary)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private func sectionHeader(title: String, actionTitle: String, metrics: HomeLayoutMetrics) -> some View {
        HStack {
            Text(title)
                .font(.system(size: metrics.sectionTitleSize, weight: .bold, design: .rounded))
                .foregroundStyle(RecipeTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer()
            Text(actionTitle)
                .font(.system(size: metrics.sectionCaptionSize, weight: .semibold, design: .rounded))
                .foregroundStyle(RecipeTheme.accentStrong)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    private func emptyCard(message: String) -> some View {
        Text(message)
            .font(.system(size: 14, weight: .medium, design: .rounded))
            .foregroundStyle(RecipeTheme.textSecondary)
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RecipeTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
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

private struct CategoryPill: View {
    let title: String
    let isSelected: Bool
    let metrics: HomeLayoutMetrics
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Circle()
                    .fill(isSelected ? Color.white.opacity(0.95) : RecipeTheme.accent.opacity(0.18))
                    .frame(width: 8, height: 8)
                Text(title)
                    .font(.system(size: metrics.categoryTitleSize, weight: .semibold, design: .rounded))
                    .foregroundStyle(isSelected ? .white : RecipeTheme.accentStrong)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.horizontal, 14)
            .frame(height: metrics.categoryPillHeight)
            .background(isSelected ? RecipeTheme.accentStrong : RecipeTheme.card)
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .stroke(isSelected ? Color.clear : RecipeTheme.accent.opacity(0.14), lineWidth: 1)
            }
            .shadow(color: isSelected ? RecipeTheme.mintShadow : RecipeTheme.shadow.opacity(0.45), radius: 10, y: 5)
        }
        .buttonStyle(.plain)
    }
}

private struct HomeLayoutMetrics {
    let availableWidth: CGFloat

    var contentWidth: CGFloat { min(availableWidth - (contentHorizontalPadding * 2), 680) }
    var contentHorizontalPadding: CGFloat { availableWidth >= 768 ? 28 : 16 }
    var sectionSpacing: CGFloat { availableWidth < 360 ? 18 : 22 }
    var contentTopPadding: CGFloat { availableWidth < 360 ? 16 : 18 }
    var bottomInsetPadding: CGFloat { availableWidth < 360 ? 104 : 110 }

    var heroHeight: CGFloat { min(max(availableWidth * 0.44, 188), 232) }
    var heroCornerRadius: CGFloat { availableWidth < 360 ? 28 : 32 }
    var heroHorizontalPadding: CGFloat { availableWidth < 360 ? 16 : 20 }
    var heroTopPadding: CGFloat { availableWidth < 360 ? 8 : 10 }
    var heroBottomPadding: CGFloat { availableWidth < 360 ? 16 : 18 }
    var heroSpacing: CGFloat { availableWidth < 360 ? 16 : 18 }
    var heroHeaderSpacing: CGFloat { availableWidth < 360 ? 10 : 12 }
    var avatarSize: CGFloat { availableWidth < 360 ? 40 : 46 }
    var avatarFontSize: CGFloat { availableWidth < 360 ? 12 : 13 }
    var heroTitleFont: CGFloat { availableWidth < 360 ? 14 : 15 }
    var heroSubtitleFont: CGFloat { availableWidth < 360 ? 11 : 12 }
    var heroButtonSize: CGFloat { availableWidth < 360 ? 36 : 40 }
    var heroButtonSymbolSize: CGFloat { availableWidth < 360 ? 14 : 16 }
    var searchBarHeight: CGFloat { availableWidth < 360 ? 44 : 46 }
    var searchSpacing: CGFloat { availableWidth < 360 ? 8 : 10 }
    var filterSymbolSize: CGFloat { availableWidth < 360 ? 16 : 17 }

    var heroCircleOneSize: CGFloat { availableWidth * 0.66 }
    var heroCircleTwoSize: CGFloat { availableWidth * 0.82 }
    var heroCircleOneOffsetX: CGFloat { availableWidth * 0.30 }
    var heroCircleOneOffsetY: CGFloat { heroHeight * 0.22 }
    var heroCircleTwoOffsetX: CGFloat { availableWidth * 0.44 }
    var heroCircleTwoOffsetY: CGFloat { heroHeight * 0.10 }

    var categoryPillWidth: CGFloat { min(max(contentWidth * 0.34, 108), 152) }
    var categoryPillHeight: CGFloat { availableWidth < 360 ? 72 : 78 }
    var categoryTitleSize: CGFloat { availableWidth < 360 ? 12 : 13 }

    var featuredCardWidth: CGFloat { min(max(contentWidth * 0.84, 270), 380) }
    var featuredCardImageHeight: CGFloat { availableWidth < 360 ? 212 : 244 }
    var featuredCardTitleSize: CGFloat { availableWidth < 360 ? 16 : 17 }
    var listCardImageHeight: CGFloat { availableWidth < 360 ? 220 : 244 }
    var listCardTitleSize: CGFloat { availableWidth < 360 ? 16 : 17 }

    var bottomBarCenterButtonSize: CGFloat { availableWidth < 360 ? 48 : 52 }
    var bottomBarCenterIconSize: CGFloat { availableWidth < 360 ? 18 : 19 }
    var bottomBarIconSize: CGFloat { availableWidth < 360 ? 15 : 16 }
    var bottomBarLabelSize: CGFloat { availableWidth < 360 ? 10 : 11 }
    var bottomBarHorizontalPadding: CGFloat { availableWidth < 360 ? 10 : 12 }
    var bottomBarTopPadding: CGFloat { availableWidth < 360 ? 8 : 10 }
    var bottomBarBottomPadding: CGFloat { availableWidth < 360 ? 8 : 10 }
    var sectionTitleSize: CGFloat { availableWidth < 360 ? 19 : 20 }
    var sectionCaptionSize: CGFloat { availableWidth < 360 ? 11 : 12 }
}
