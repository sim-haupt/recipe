import SwiftUI

struct HomeView: View {
    @Environment(\.appEnvironment) private var environment
    @Environment(\.scenePhase) private var scenePhase
    @FocusState private var isSearchFocused: Bool
    @StateObject private var viewModel: HomeViewModel

    @State private var selectedTab: RecipeHomeTab = .all
    @State private var feedStyle: RecipeFeedStyle = .cards
    @State private var allSearchText = ""
    @State private var favoriteSearchText = ""
    @State private var allSelectedCategories = Set<String>()
    @State private var allSelectedTags = Set<String>()
    @State private var favoriteSelectedCategories = Set<String>()
    @State private var favoriteSelectedTags = Set<String>()
    @State private var allMinimumRating = 0
    @State private var favoriteMinimumRating = 0
    @State private var isShowingFilterSheet = false

    let userProfile: UserProfile

    init(userProfile: UserProfile, environment: AppEnvironment = .demo) {
        self.userProfile = userProfile
        _viewModel = StateObject(wrappedValue: HomeViewModel(environment: environment, userProfile: userProfile))
    }

    private var baseRecipes: [Recipe] {
        selectedTab == .all ? viewModel.allRecipesSorted : viewModel.favoriteRecipes
    }

    private var displayedRecipes: [Recipe] {
        let searched = viewModel.searchResults(in: baseRecipes, query: currentSearchText)
        return searched.filter { recipe in
            let matchesCategory = currentSelectedCategories.isEmpty || !Set(recipe.categories).isDisjoint(with: currentSelectedCategories)
            let matchesTag = currentSelectedTags.isEmpty || !Set(recipe.tagNames).isDisjoint(with: currentSelectedTags)
            let rating = recipe.averageRating ?? 0
            let matchesRating = currentMinimumRating == 0 || rating >= Double(currentMinimumRating)
            return matchesCategory && matchesTag && matchesRating
        }
    }

    private var currentSearchText: String {
        selectedTab == .all ? allSearchText : favoriteSearchText
    }

    private var currentSelectedCategories: Set<String> {
        selectedTab == .all ? allSelectedCategories : favoriteSelectedCategories
    }

    private var currentMinimumRating: Int {
        selectedTab == .all ? allMinimumRating : favoriteMinimumRating
    }

    private var currentSelectedTags: Set<String> {
        selectedTab == .all ? allSelectedTags : favoriteSelectedTags
    }

    private var currentFilterCount: Int {
        currentSelectedCategories.count + currentSelectedTags.count + (currentMinimumRating > 0 ? 1 : 0)
    }

    private var currentSearchBinding: Binding<String> {
        Binding(
            get: { selectedTab == .all ? allSearchText : favoriteSearchText },
            set: { newValue in
                if selectedTab == .all {
                    allSearchText = newValue
                } else {
                    favoriteSearchText = newValue
                }
            }
        )
    }

    private var currentSelectedCategoriesBinding: Binding<Set<String>> {
        Binding(
            get: { selectedTab == .all ? allSelectedCategories : favoriteSelectedCategories },
            set: { newValue in
                if selectedTab == .all {
                    allSelectedCategories = newValue
                } else {
                    favoriteSelectedCategories = newValue
                }
            }
        )
    }

    private var currentMinimumRatingBinding: Binding<Int> {
        Binding(
            get: { selectedTab == .all ? allMinimumRating : favoriteMinimumRating },
            set: { newValue in
                if selectedTab == .all {
                    allMinimumRating = newValue
                } else {
                    favoriteMinimumRating = newValue
                }
            }
        )
    }

    private var currentSelectedTagsBinding: Binding<Set<String>> {
        Binding(
            get: { selectedTab == .all ? allSelectedTags : favoriteSelectedTags },
            set: { newValue in
                if selectedTab == .all {
                    allSelectedTags = newValue
                } else {
                    favoriteSelectedTags = newValue
                }
            }
        )
    }

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                let metrics = HomeLayoutMetrics(availableWidth: proxy.size.width)
                let bottomInset = proxy.safeAreaInsets.bottom

                ZStack {
                    RecipeTheme.homeBackdrop
                        .ignoresSafeArea()

                    backgroundDecor(metrics: metrics)

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {
                            HomeHeroSection(
                                metrics: metrics,
                                initials: userInitials,
                                greeting: "Hello, \(firstName)",
                                subtitle: "What we cookin’?",
                                searchText: currentSearchBinding,
                                isSearchFocused: $isSearchFocused,
                                activeFilterCount: currentFilterCount,
                                addAction: {
                                    viewModel.isShowingAddRecipe = true
                                },
                                filterAction: {
                                    isShowingFilterSheet = true
                                }
                            )

                            VStack(alignment: .leading, spacing: metrics.sectionSpacing) {
                                categoriesSection(metrics: metrics)

                                RecipeTabSelector(
                                    selectedTab: $selectedTab
                                )

                                RecipeFeedHeader(
                                    subtitle: "\(displayedRecipes.count) recipes",
                                    feedStyle: $feedStyle
                                )

                                recipeFeed(metrics: metrics)
                            }
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            .padding(.horizontal, metrics.horizontalPadding)
                            .padding(.top, metrics.panelTopPadding)
                            .padding(.bottom, metrics.panelBottomPadding + bottomInset)
                            .background {
                                UnevenRoundedRectangle(
                                    topLeadingRadius: 0,
                                    bottomLeadingRadius: 0,
                                    bottomTrailingRadius: 0,
                                    topTrailingRadius: 0,
                                    style: .continuous
                                )
                                .fill(RecipeTheme.contentBackground.opacity(0.97))
                                .overlay {
                                    UnevenRoundedRectangle(
                                        topLeadingRadius: 0,
                                        bottomLeadingRadius: 0,
                                        bottomTrailingRadius: 0,
                                        topTrailingRadius: 0,
                                        style: .continuous
                                    )
                                    .stroke(Color.white.opacity(0.72), lineWidth: 1)
                                    .allowsHitTesting(false)
                                }
                                .shadow(color: RecipeTheme.shadow.opacity(0.08), radius: 22, y: -2)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .top)
                        .frame(minHeight: proxy.size.height, alignment: .top)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .simultaneousGesture(TapGesture().onEnded {
                        isSearchFocused = false
                    })
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(RecipeTheme.homeBackdrop.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $viewModel.isShowingAddRecipe) {
                AddRecipeView(userProfile: userProfile, environment: environment)
            }
            .sheet(isPresented: $isShowingFilterSheet) {
                RecipeFilterSheet(
                    selectedCategories: currentSelectedCategoriesBinding,
                    selectedTags: currentSelectedTagsBinding,
                    minimumRating: currentMinimumRatingBinding,
                    availableCategories: RecipeCategory.allTitles,
                    availableTags: availableTags
                )
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

    @ViewBuilder
    private func categoriesSection(metrics: HomeLayoutMetrics) -> some View {
        if !topCategories.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Categories")
                    .font(.system(size: metrics.sectionCaptionSize + 6, weight: .bold, design: .rounded))
                    .foregroundStyle(RecipeTheme.textPrimary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(topCategories, id: \.self) { category in
                            CategoryBadge(
                                title: category,
                                isSelected: currentSelectedCategories.contains(category),
                                action: {
                                    toggleCurrentCategory(category)
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 1)
                }
            }
        }
    }

    @ViewBuilder
    private func recipeFeed(metrics: HomeLayoutMetrics) -> some View {
        if displayedRecipes.isEmpty {
            HomeEmptyCard(message: emptyStateMessage)
        } else {
            LazyVStack(spacing: feedStyle == .cards ? 18 : 14) {
                ForEach(displayedRecipes) { recipe in
                    NavigationLink {
                        RecipeDetailView(recipe: recipe, userProfile: userProfile, environment: environment)
                    } label: {
                        RecipeCardView(
                            recipe: recipe,
                            layoutStyle: feedStyle == .cards ? .featured : .list,
                            cardWidth: feedStyle == .cards ? metrics.feedCardWidth : metrics.listCardWidth,
                            imageWidth: feedStyle == .cards ? metrics.feedCardWidth : metrics.listImageWidth,
                            imageHeight: feedStyle == .cards ? metrics.feedImageHeight : metrics.listImageHeight,
                            titleFontSize: feedStyle == .cards ? metrics.featuredCardTitleSize : metrics.listCardTitleSize,
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

    private var emptyStateMessage: String {
        if selectedTab == .favorites {
            return "Favorite a recipe and it will appear here."
        }
        return "No recipes matched the current search and filters."
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
        return initials.isEmpty ? "CB" : initials
    }

    private var topCategories: [String] {
        let counts = Dictionary(grouping: viewModel.allRecipesSorted.flatMap(\.categories), by: { $0 })
            .mapValues(\.count)

        return counts
            .sorted { lhs, rhs in
                if lhs.value == rhs.value {
                    return lhs.key < rhs.key
                }
                return lhs.value > rhs.value
            }
            .prefix(4)
            .map(\.key)
    }

    private func toggleCurrentCategory(_ category: String) {
        if selectedTab == .all {
            if allSelectedCategories.contains(category) {
                allSelectedCategories.remove(category)
            } else {
                allSelectedCategories.insert(category)
            }
        } else {
            if favoriteSelectedCategories.contains(category) {
                favoriteSelectedCategories.remove(category)
            } else {
                favoriteSelectedCategories.insert(category)
            }
        }
    }

    private var availableTags: [String] {
        Array(Set(baseRecipes.flatMap(\.tagNames)))
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }
}

private enum RecipeHomeTab {
    case all
    case favorites

    var title: String {
        switch self {
        case .all: return "All Recipes"
        case .favorites: return "Favourites"
        }
    }
}

private enum RecipeFeedStyle {
    case cards
    case list
}

private struct HomeHeroSection: View {
    let metrics: HomeLayoutMetrics
    let initials: String
    let greeting: String
    let subtitle: String
    @Binding var searchText: String
    @FocusState.Binding var isSearchFocused: Bool
    let activeFilterCount: Int
    let addAction: () -> Void
    let filterAction: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(Color.clear)
                .background {
                    ZStack {
                        Image("RecipeDetailPattern")
                            .resizable()
                            .scaledToFill()

                        LinearGradient(
                            colors: [
                                RecipeTheme.accent.opacity(0.10),
                                RecipeTheme.accentStrong.opacity(0.22)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
                    .clipped()
                }
                .overlay(alignment: .topTrailing) {
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                            .frame(width: metrics.heroRingOne, height: metrics.heroRingOne)
                            .offset(x: metrics.availableWidth * 0.14, y: metrics.heroRingOffsetOneY)

                        Circle()
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            .frame(width: metrics.heroRingTwo, height: metrics.heroRingTwo)
                            .offset(x: metrics.availableWidth * 0.04, y: metrics.heroRingOffsetTwoY)
                    }
                }

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 14) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.22))
                            Text(initials)
                                .font(.system(size: metrics.avatarFontSize, weight: .bold, design: .rounded))
                                .foregroundStyle(RecipeTheme.textOnAccent)
                        }
                        .frame(width: metrics.avatarSize, height: metrics.avatarSize)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(greeting)
                                .font(.system(size: metrics.heroTitleSize, weight: .bold, design: .rounded))
                                .foregroundStyle(RecipeTheme.textOnAccent)
                                .lineLimit(1)

                            Text(subtitle)
                                .font(.system(size: metrics.heroSubtitleSize, weight: .medium, design: .rounded))
                                .foregroundStyle(RecipeTheme.textOnAccent.opacity(0.74))
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

                HeroSearchBar(
                    text: $searchText,
                    isFocused: $isSearchFocused,
                    height: metrics.searchBarHeight,
                    activeFilterCount: activeFilterCount,
                    filterAction: filterAction
                )
            }
            .padding(.top, metrics.heroTopPadding)
            .padding(.horizontal, metrics.horizontalPadding)
            .padding(.bottom, metrics.heroBottomPadding)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct HeroSearchBar: View {
    @Binding var text: String
    @FocusState.Binding var isFocused: Bool
    let height: CGFloat
    let activeFilterCount: Int
    let filterAction: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isFocused ? RecipeTheme.accentStrong : Color.black.opacity(0.34))

                TextField("", text: $text, prompt: Text("Search recipes").foregroundStyle(Color.black.opacity(0.28)))
                    .focused($isFocused)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.system(size: 16, weight: .medium, design: .rounded))

                if !text.isEmpty {
                    Button {
                        text = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.black.opacity(0.28))
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity.combined(with: .scale))
                }
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.97))
            )

            Button(action: filterAction) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.97))
                    .frame(width: height, height: height)
                    .overlay {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(activeFilterCount > 0 ? RecipeTheme.accentStrong : Color.black.opacity(0.36))
                            .allowsHitTesting(false)
                    }
                    .overlay(alignment: .topTrailing) {
                        if activeFilterCount > 0 {
                            Text("\(min(activeFilterCount, 9))")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(RecipeTheme.textOnAccent)
                                .frame(minWidth: 18, minHeight: 18)
                                .background(RecipeTheme.accentStrong)
                                .clipShape(Capsule())
                                .offset(x: 8, y: -8)
                                .allowsHitTesting(false)
                        }
                    }
                .shadow(color: Color.black.opacity(0.08), radius: 10, y: 5)
            }
            .buttonStyle(PressableScaleButtonStyle())
        }
    }
}

private struct RecipeTabSelector: View {
    @Binding var selectedTab: RecipeHomeTab

    var body: some View {
        HStack(spacing: 12) {
            RecipeTabButton(
                title: "All Recipes",
                isSelected: selectedTab == .all,
                action: { selectedTab = .all }
            )

            RecipeTabButton(
                title: "Favourites",
                isSelected: selectedTab == .favorites,
                action: { selectedTab = .favorites }
            )
        }
    }
}

private struct RecipeTabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(isSelected ? RecipeTheme.textOnAccent : RecipeTheme.textPrimary)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(isSelected ? AnyShapeStyle(RecipeTheme.heroGradient) : AnyShapeStyle(RecipeTheme.surface))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(isSelected ? Color.clear : RecipeTheme.strokeSoft, lineWidth: 1)
                    .allowsHitTesting(false)
            }
            .shadow(color: isSelected ? RecipeTheme.mintShadow : RecipeTheme.shadow.opacity(0.05), radius: 12, y: 6)
        }
        .buttonStyle(PressableScaleButtonStyle())
        .contentShape(Rectangle())
    }
}

private struct RecipeFeedHeader: View {
    let subtitle: String
    @Binding var feedStyle: RecipeFeedStyle

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Text(subtitle)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(RecipeTheme.textSecondary)

            Spacer(minLength: 12)

            RecipeViewSwitcher(feedStyle: $feedStyle)
        }
    }
}

private struct RecipeViewSwitcher: View {
    @Binding var feedStyle: RecipeFeedStyle

    var body: some View {
        HStack(spacing: 8) {
            switcherButton(systemName: "rectangle.grid.1x2.fill", style: .cards)
            switcherButton(systemName: "list.bullet.rectangle.portrait.fill", style: .list)
        }
        .padding(6)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.86))
        )
        .overlay {
            Capsule()
                .stroke(RecipeTheme.strokeSoft, lineWidth: 1)
                .allowsHitTesting(false)
        }
        .contentShape(Rectangle())
    }

    private func switcherButton(systemName: String, style: RecipeFeedStyle) -> some View {
        Button {
            feedStyle = style
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(feedStyle == style ? RecipeTheme.textOnAccent : RecipeTheme.accentStrong)
                .frame(width: 38, height: 38)
                .background(
                    Circle()
                        .fill(feedStyle == style ? RecipeTheme.accentStrong : Color.clear)
                )
        }
        .buttonStyle(PressableScaleButtonStyle())
    }
}

private struct CategoryBadge: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        CategoryPill(title: title, isSelected: isSelected, style: .outlined, action: action)
            .buttonStyle(PressableScaleButtonStyle())
            .contentShape(Rectangle())
    }
}

struct RecipeTagPill: View {
    let title: String

    var body: some View {
        CategoryPill(title: title, compact: true)
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
                    .allowsHitTesting(false)
            }
    }
}

private struct RecipeFilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedCategories: Set<String>
    @Binding var selectedTags: Set<String>
    @Binding var minimumRating: Int

    let availableCategories: [String]
    let availableTags: [String]

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Categories")
                            .font(.system(size: 17, weight: .bold, design: .rounded))

                        if availableCategories.isEmpty {
                            HomeEmptyCard(message: "Categories will appear here once recipes are assigned.")
                        } else {
                            AdaptiveCategoryGrid(tags: availableCategories, selectedTags: $selectedCategories)
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Minimum Rating")
                            .font(.system(size: 17, weight: .bold, design: .rounded))

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 88), spacing: 10)], alignment: .leading, spacing: 10) {
                            ratingChip(value: 0, label: "Any")
                            ratingChip(value: 3, label: "3+")
                            ratingChip(value: 4, label: "4+")
                            ratingChip(value: 5, label: "5")
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Tags")
                            .font(.system(size: 17, weight: .bold, design: .rounded))

                        if availableTags.isEmpty {
                            HomeEmptyCard(message: "Tags will appear here once recipes are tagged.")
                        } else {
                            AdaptiveTagGrid(tags: availableTags, selectedTags: $selectedTags)
                        }
                    }
                }
                .padding(20)
            }
            .background(RecipeTheme.homeBackdrop.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Reset") {
                        selectedCategories.removeAll()
                        selectedTags.removeAll()
                        minimumRating = 0
                    }
                    .foregroundStyle(RecipeTheme.accentStrong)
                }

                ToolbarItem(placement: .principal) {
                    Text("Filters")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(RecipeTheme.accentStrong)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func ratingChip(value: Int, label: String) -> some View {
        Button {
            minimumRating = value
        } label: {
            HStack(spacing: 6) {
                if value > 0 {
                    Image(systemName: "star.fill")
                        .font(.system(size: 11, weight: .bold))
                }
                Text(label)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(minimumRating == value ? RecipeTheme.textOnAccent : RecipeTheme.accentStrong)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(minimumRating == value ? RecipeTheme.accentStrong : RecipeTheme.surface)
            )
            .overlay {
                Capsule()
                    .stroke(minimumRating == value ? Color.clear : RecipeTheme.strokeSoft, lineWidth: 1)
                    .allowsHitTesting(false)
            }
        }
        .buttonStyle(PressableScaleButtonStyle())
    }
}

private struct AdaptiveCategoryGrid: View {
    let tags: [String]
    @Binding var selectedTags: Set<String>

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 132), spacing: 10)], alignment: .leading, spacing: 10) {
            ForEach(tags, id: \.self) { tag in
                CategoryBadge(
                    title: tag,
                    isSelected: selectedTags.contains(tag),
                    action: {
                        if selectedTags.contains(tag) {
                            selectedTags.remove(tag)
                        } else {
                            selectedTags.insert(tag)
                        }
                    }
                )
            }
        }
    }
}

private struct AdaptiveTagGrid: View {
    let tags: [String]
    @Binding var selectedTags: Set<String>

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 112), spacing: 10)], alignment: .leading, spacing: 10) {
            ForEach(tags, id: \.self) { tag in
                TagChip(title: "#\(tag)", isSelected: selectedTags.contains(tag)) {
                    if selectedTags.contains(tag) {
                        selectedTags.remove(tag)
                    } else {
                        selectedTags.insert(tag)
                    }
                }
            }
        }
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

    private var safeAvailableWidth: CGFloat {
        availableWidth.isFinite ? max(availableWidth, 1) : 1
    }

    var horizontalPadding: CGFloat { safeAvailableWidth < 380 ? 16 : 20 }
    var sectionSpacing: CGFloat { safeAvailableWidth < 380 ? 22 : 26 }
    var heroTopPadding: CGFloat { safeAvailableWidth < 380 ? 8 : 10 }
    var heroBottomPadding: CGFloat { safeAvailableWidth < 380 ? 18 : 20 }
    var avatarSize: CGFloat { safeAvailableWidth < 380 ? 44 : 48 }
    var avatarFontSize: CGFloat { safeAvailableWidth < 380 ? 14 : 15 }
    var heroTitleSize: CGFloat { safeAvailableWidth < 380 ? 17 : 18 }
    var heroSubtitleSize: CGFloat { safeAvailableWidth < 380 ? 12 : 13 }
    var heroActionSize: CGFloat { safeAvailableWidth < 380 ? 48 : 52 }
    var heroActionIconSize: CGFloat { safeAvailableWidth < 380 ? 18 : 19 }
    var searchBarHeight: CGFloat { safeAvailableWidth < 380 ? 44 : 46 }
    var heroRingOne: CGFloat { max(safeAvailableWidth * 0.64, 1) }
    var heroRingTwo: CGFloat { max(safeAvailableWidth * 0.96, 1) }
    var heroRingOffsetOneY: CGFloat { safeAvailableWidth < 380 ? 10 : 14 }
    var heroRingOffsetTwoY: CGFloat { safeAvailableWidth < 380 ? 18 : 24 }

    var panelRadius: CGFloat { safeAvailableWidth < 380 ? 30 : 34 }
    var panelTopPadding: CGFloat { safeAvailableWidth < 380 ? 20 : 24 }
    var panelBottomPadding: CGFloat { safeAvailableWidth < 380 ? 28 : 32 }

    var feedCardWidth: CGFloat { max(safeAvailableWidth - (horizontalPadding * 2), 1) }
    var feedImageHeight: CGFloat { safeAvailableWidth < 380 ? 208 : 232 }
    var featuredCardTitleSize: CGFloat { safeAvailableWidth < 380 ? 17 : 18 }
    var listCardWidth: CGFloat { max(safeAvailableWidth - (horizontalPadding * 2), 1) }
    var listImageWidth: CGFloat { safeAvailableWidth < 380 ? 124 : 132 }
    var listImageHeight: CGFloat { safeAvailableWidth < 380 ? 108 : 116 }
    var listCardTitleSize: CGFloat { safeAvailableWidth < 380 ? 15 : 16 }

    var sectionCaptionSize: CGFloat { safeAvailableWidth < 380 ? 11 : 12 }

    var backdropOrbOne: CGFloat { max(safeAvailableWidth * 0.84, 1) }
    var backdropOrbTwo: CGFloat { max(safeAvailableWidth * 0.68, 1) }
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
    var body: some View {
        HomeView(userProfile: HomePreviewData.user, environment: .demo)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(RecipeTheme.homeBackdrop.ignoresSafeArea())
    }
}

#Preview {
    HomePreviewHost()
}
