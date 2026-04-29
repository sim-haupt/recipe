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

    private let columns = [
        GridItem(.adaptive(minimum: 280), spacing: 16)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if !viewModel.tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(viewModel.tags) { tag in
                                    TagChip(title: tag.name, isSelected: viewModel.selectedTags.contains(tag.name)) {
                                        viewModel.toggle(tag: tag)
                                    }
                                }
                            }
                            .padding(.horizontal, 1)
                        }
                    }

                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(viewModel.filteredRecipes) { recipe in
                            NavigationLink {
                                RecipeDetailView(recipe: recipe, userProfile: userProfile, environment: environment)
                            } label: {
                                RecipeCardView(recipe: recipe)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(20)
            }
            .background(RecipeTheme.background.ignoresSafeArea())
            .navigationTitle("Recipes")
            .searchable(text: $viewModel.searchText, prompt: "Search titles, notes, or sources")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Sign Out") {
                        sessionViewModel.signOut()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.isShowingAddRecipe = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
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
        .environment(\.appEnvironment, environment)
    }
}
