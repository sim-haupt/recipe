import PhotosUI
import SwiftUI
import UIKit

struct ShareComposerView: View {
    @ObservedObject var viewModel: ShareViewModel
    let onCancel: () -> Void
    let onComplete: () -> Void
    @State private var selectedPhoto: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    VStack(spacing: 14) {
                        ProgressView()
                            .controlSize(.large)
                        Text("Extracting recipe data…")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                        Text("We’re generating a preview with title, image, and ingredients.")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(28)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(shareBackground.ignoresSafeArea())
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 18) {
                            previewCard

                            Text("Some apps only share a link, caption text, or a low-resolution thumbnail. Instagram and other third-party apps may not expose the full recipe metadata, so you can edit everything here before saving.")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                        .padding(18)
                    }
                    .background(shareBackground.ignoresSafeArea())
                }
            }
            .navigationTitle("Save Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel", action: onCancel)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(viewModel.isSaving ? "Saving..." : "Save") {
                        Task {
                            if await viewModel.save() {
                                onComplete()
                            }
                        }
                    }
                    .disabled(viewModel.isSaving || viewModel.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onChange(of: selectedPhoto) { _, newValue in
                guard let newValue else { return }

                Task {
                    viewModel.imageData = try? await newValue.loadTransferable(type: Data.self)
                }
            }
            .alert("Unable to save", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    private var previewCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Recipe Preview")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                Spacer()

                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Label("Change Image", systemImage: "photo")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(shareAccent)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            previewImage

            inputSection(title: "Title") {
                TextField("Recipe title", text: $viewModel.title)
                    .shareInputFieldStyle()
            }

            inputSection(title: "Source URL") {
                TextField("https://example.com", text: $viewModel.sourceURL, axis: .vertical)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .shareInputFieldStyle(minHeight: 68)
            }

            inputSection(title: "Ingredients") {
                TextField("One ingredient per line", text: $viewModel.ingredientsText, axis: .vertical)
                    .shareInputFieldStyle(minHeight: 150)
            }

            inputSection(title: "Categories") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], spacing: 10) {
                    ForEach(RecipeCategory.allTitles, id: \.self) { category in
                        let isSelected = viewModel.selectedCategories.contains(category)
                        Button {
                            if isSelected {
                                viewModel.selectedCategories.remove(category)
                            } else {
                                viewModel.selectedCategories.insert(category)
                            }
                        } label: {
                            Text(category)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(RecipeCategory.color(for: category))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity)
                                .background(
                                    Capsule()
                                        .fill(RecipeCategory.fillColor(for: category, isSelected: isSelected))
                                )
                                .overlay {
                                    Capsule()
                                        .stroke(RecipeCategory.strokeColor(for: category, isSelected: isSelected), lineWidth: 1)
                                        .allowsHitTesting(false)
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            inputSection(title: "Tags") {
                ShareTagEditor(tags: $viewModel.tags)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
                .allowsHitTesting(false)
        }
        .shadow(color: Color.black.opacity(0.08), radius: 10, y: 6)
    }

    @ViewBuilder
    private var previewImage: some View {
        ZStack {
            if let imageData = viewModel.imageData,
               let image = UIImage(data: imageData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                sharePlaceholder
            }
        }
        .frame(maxWidth: .infinity, minHeight: 210, maxHeight: 210)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func inputSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)

            content()
        }
    }

    private var shareBackground: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.92, green: 0.98, blue: 0.94),
                Color(red: 0.98, green: 0.99, blue: 0.98)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var shareAccent: Color {
        Color(red: 74 / 255, green: 194 / 255, blue: 116 / 255)
    }

    private var sharePlaceholder: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.83, green: 0.95, blue: 0.87),
                    shareAccent
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Image(systemName: "fork.knife.circle.fill")
                .font(.system(size: 42))
                .foregroundStyle(.white.opacity(0.9))
        }
    }
}

private extension View {
    func shareInputFieldStyle(minHeight: CGFloat = 56) -> some View {
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
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
                    .allowsHitTesting(false)
            }
    }
}

private struct ShareTagEditor: View {
    @Binding var tags: [String]
    @State private var draftTag = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                TextField("Add tags", text: $draftTag)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.white.opacity(0.96))
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.black.opacity(0.06), lineWidth: 1)
                            .allowsHitTesting(false)
                    }
                    .submitLabel(.done)
                    .onSubmit { commitDraftTags() }

                Button("Add") {
                    commitDraftTags()
                }
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color(red: 74 / 255, green: 194 / 255, blue: 116 / 255))
                .foregroundStyle(.white)
                .clipShape(Capsule())
                .buttonStyle(.plain)
            }

            if !tags.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
                    ForEach(tags, id: \.self) { tag in
                        Button {
                            tags.removeAll { $0.caseInsensitiveCompare(tag) == .orderedSame }
                        } label: {
                            HStack(spacing: 6) {
                                Text("#\(tag)")
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
                            .background(Color(red: 0.92, green: 0.98, blue: 0.94))
                            .foregroundStyle(.primary)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func commitDraftTags() {
        let parsed = draftTag
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !parsed.isEmpty else { return }

        var seen = Set(tags.map { $0.lowercased() })
        for tag in parsed where seen.insert(tag.lowercased()).inserted {
            tags.append(tag)
        }
        draftTag = ""
    }
}
