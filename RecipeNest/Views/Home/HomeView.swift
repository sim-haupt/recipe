import SwiftUI

struct HomeView: View {
    @Environment(\.appEnvironment) private var environment
    @EnvironmentObject private var sessionViewModel: SessionViewModel
    @StateObject private var viewModel: HomeViewModel
    let userProfile: UserProfile

    init(userProfile: UserProfile, environment: AppEnvironment = .demo) {
        self.userProfile = userProfile
        _viewModel = StateObject(wrappedValue: HomeViewModel(environment: environment, userProfile: userProfile))
    }

    private var popularRecipes: [Recipe] {
        viewModel.filteredRecipes
            .sorted { lhs, rhs in
                let lhsScore = (lhs.averageRating ?? 0) * Double(max(lhs.reviewCount, 1))
                let rhsScore = (rhs.averageRating ?? 0) * Double(max(rhs.reviewCount, 1))
                if lhsScore == rhsScore {
                    return lhs.savedDate > rhs.savedDate
                }
                return lhsScore > rhsScore
            }
    }

    private var recentRecipes: [Recipe] {
        viewModel.filteredRecipes.sorted { $0.savedDate > $1.savedDate }
    }

    private var contributors: [ContributorSummary] {
        var seen = Set<String>()
        return recentRecipes.compactMap { recipe in
            guard seen.insert(recipe.createdByUserID).inserted else { return nil }
            return ContributorSummary(id: recipe.createdByUserID, name: recipe.createdByName)
        }
    }

    var body: some View {
        GeometryReader { proxy in
            let metrics = HomeLayoutMetrics(availableWidth: proxy.size.width)

            NavigationStack {
                ZStack {
                    RecipeTheme.pageGradient.ignoresSafeArea()

                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: metrics.sectionSpacing) {
                            heroHeader(metrics: metrics)
                            categoriesSection(metrics: metrics)
                            popularSection(metrics: metrics)

                            if !contributors.isEmpty {
                                contributorsSection(metrics: metrics)
                            }

                            allRecipesSection(metrics: metrics)
                        }
                        .frame(maxWidth: metrics.contentWidth, alignment: .leading)
                        .padding(.horizontal, metrics.horizontalPadding)
                        .padding(.top, 12)
                        .padding(.bottom, metrics.bottomInsetPadding)
                    }
                }
                .toolbar(.hidden, for: .navigationBar)
                .safeAreaInset(edge: .bottom) {
                    homeBottomBar(metrics: metrics)
                        .frame(maxWidth: metrics.contentWidth)
                        .padding(.horizontal, metrics.horizontalPadding)
                        .padding(.top, 8)
                        .padding(.bottom, 8)
                        .background(Color.clear)
                }
                .sheet(isPresented: $viewModel.isShowingAddRecipe) {
                    AddRecipeView(userProfile: userProfile, environment: environment)
                }
                .task {
                    viewModel.start()
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

    private func heroHeader(metrics: HomeLayoutMetrics) -> some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: metrics.heroCornerRadius, style: .continuous)
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
            .padding(metrics.heroPadding)
        }
        .frame(height: metrics.heroHeight)
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
                                imageURL: imageURL(for: tag),
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
                                    titleFontSize: metrics.featuredCardTitleSize
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

    private func contributorsSection(metrics: HomeLayoutMetrics) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "Contributors", actionTitle: "\(contributors.count) people", metrics: metrics)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 18) {
                    ForEach(contributors) { contributor in
                        VStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(RecipeTheme.accentSoft)
                                    .frame(width: metrics.contributorAvatarSize, height: metrics.contributorAvatarSize)
                                Text(contributor.initials)
                                    .font(.system(size: metrics.contributorInitialsSize, weight: .bold, design: .rounded))
                                    .foregroundStyle(RecipeTheme.accentStrong)
                            }

                            Text(contributor.name)
                                .font(.system(size: metrics.contributorNameSize, weight: .medium, design: .rounded))
                                .lineLimit(1)
                        }
                    }
                }
                .padding(.horizontal, 1)
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
                                titleFontSize: metrics.listCardTitleSize
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func homeBottomBar(metrics: HomeLayoutMetrics) -> some View {
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
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.7), lineWidth: 1)
        }
        .shadow(color: RecipeTheme.shadow, radius: 14, y: 8)
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

    private func imageURL(for tag: Tag) -> String? {
        recentRecipes.first(where: { $0.tagNames.contains(tag.name) })?.imageURL
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
    let imageURL: String?
    let isSelected: Bool
    let metrics: HomeLayoutMetrics
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottomLeading) {
                RemoteRecipeImage(imageURL: imageURL, height: metrics.categoryPillHeight)
                    .overlay {
                        LinearGradient(
                            colors: [Color.clear, Color.black.opacity(isSelected ? 0.42 : 0.28)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }

                Text(title)
                    .font(.system(size: metrics.categoryTitleSize, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(12)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(width: metrics.categoryPillWidth, height: metrics.categoryPillHeight)
            .background(RecipeTheme.secondaryCard)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(isSelected ? RecipeTheme.accentStrong : Color.white.opacity(0.7), lineWidth: isSelected ? 2 : 1)
            }
            .shadow(color: isSelected ? RecipeTheme.mintShadow : RecipeTheme.shadow, radius: 12, y: 6)
        }
        .buttonStyle(.plain)
    }
}

private struct HomeLayoutMetrics {
    let availableWidth: CGFloat

    var contentWidth: CGFloat { min(availableWidth - 32, 680) }
    var horizontalPadding: CGFloat { availableWidth >= 768 ? 32 : 16 }
    var sectionSpacing: CGFloat { availableWidth < 360 ? 20 : 24 }
    var bottomInsetPadding: CGFloat { availableWidth < 360 ? 104 : 110 }

    var heroHeight: CGFloat { min(max(contentWidth * 0.58, 196), 252) }
    var heroCornerRadius: CGFloat { availableWidth < 360 ? 28 : 32 }
    var heroPadding: CGFloat { availableWidth < 360 ? 16 : 18 }
    var heroSpacing: CGFloat { availableWidth < 360 ? 18 : 22 }
    var heroHeaderSpacing: CGFloat { availableWidth < 360 ? 10 : 12 }
    var avatarSize: CGFloat { availableWidth < 360 ? 40 : 46 }
    var avatarFontSize: CGFloat { availableWidth < 360 ? 13 : 15 }
    var heroTitleFont: CGFloat { availableWidth < 360 ? 15 : 17 }
    var heroSubtitleFont: CGFloat { availableWidth < 360 ? 12 : 13 }
    var heroButtonSize: CGFloat { availableWidth < 360 ? 36 : 40 }
    var heroButtonSymbolSize: CGFloat { availableWidth < 360 ? 14 : 16 }
    var searchBarHeight: CGFloat { availableWidth < 360 ? 46 : 50 }
    var searchSpacing: CGFloat { availableWidth < 360 ? 8 : 10 }
    var filterSymbolSize: CGFloat { availableWidth < 360 ? 16 : 18 }

    var heroCircleOneSize: CGFloat { contentWidth * 0.64 }
    var heroCircleTwoSize: CGFloat { contentWidth * 0.82 }
    var heroCircleOneOffsetX: CGFloat { contentWidth * 0.26 }
    var heroCircleOneOffsetY: CGFloat { heroHeight * 0.22 }
    var heroCircleTwoOffsetX: CGFloat { contentWidth * 0.40 }
    var heroCircleTwoOffsetY: CGFloat { heroHeight * 0.12 }

    var categoryPillWidth: CGFloat { min(max(contentWidth * 0.34, 108), 152) }
    var categoryPillHeight: CGFloat { availableWidth < 360 ? 72 : 78 }
    var categoryTitleSize: CGFloat { availableWidth < 360 ? 13 : 14 }

    var featuredCardWidth: CGFloat { min(max(contentWidth * 0.84, 270), 380) }
    var featuredCardImageHeight: CGFloat { availableWidth < 360 ? 212 : 244 }
    var featuredCardTitleSize: CGFloat { availableWidth < 360 ? 17 : 19 }
    var listCardImageHeight: CGFloat { availableWidth < 360 ? 220 : 244 }
    var listCardTitleSize: CGFloat { availableWidth < 360 ? 18 : 19 }

    var contributorAvatarSize: CGFloat { availableWidth < 360 ? 54 : 62 }
    var contributorInitialsSize: CGFloat { availableWidth < 360 ? 16 : 18 }
    var contributorNameSize: CGFloat { availableWidth < 360 ? 12 : 13 }

    var bottomBarCenterButtonSize: CGFloat { availableWidth < 360 ? 48 : 52 }
    var bottomBarCenterIconSize: CGFloat { availableWidth < 360 ? 18 : 20 }
    var bottomBarIconSize: CGFloat { availableWidth < 360 ? 16 : 18 }
    var bottomBarLabelSize: CGFloat { availableWidth < 360 ? 10 : 11 }
    var sectionTitleSize: CGFloat { availableWidth < 360 ? 21 : 24 }
    var sectionCaptionSize: CGFloat { availableWidth < 360 ? 12 : 13 }
}

private struct ContributorSummary: Identifiable {
    let id: String
    let name: String

    var initials: String {
        let parts = name.split(separator: " ")
        let letters = parts.prefix(2).compactMap { $0.first }
        let value = String(letters)
        return value.isEmpty ? "R" : value
    }
}
