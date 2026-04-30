import SwiftUI

struct TagChip: View {
    let title: String
    var isSelected = false
    var removable = false
    var onTap: (() -> Void)?

    var body: some View {
        Button(action: { onTap?() }) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                if removable {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(isSelected ? RecipeTheme.accent : RecipeTheme.accentSoft)
            .foregroundStyle(isSelected ? RecipeTheme.textOnAccent : RecipeTheme.textPrimary)
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .stroke(isSelected ? Color.clear : RecipeTheme.accent.opacity(0.12), lineWidth: 1)
                    .allowsHitTesting(false)
            }
        }
        .buttonStyle(.plain)
    }
}

struct CategoryPill: View {
    enum Style {
        case filled
        case outlined
    }

    let title: String
    var isSelected: Bool = true
    var compact: Bool = false
    var style: Style = .filled
    var action: (() -> Void)? = nil

    var body: some View {
        Group {
            if let action {
                Button(action: action) {
                    pillContent
                }
                .buttonStyle(.plain)
            } else {
                pillContent
            }
        }
    }

    private var pillContent: some View {
        Text(title)
            .font(.system(size: compact ? 11 : 13, weight: .semibold, design: .rounded))
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, compact ? 10 : 14)
            .padding(.vertical, compact ? 6 : 9)
            .background(
                Capsule()
                    .fill(backgroundStyle)
            )
            .overlay {
                Capsule()
                    .stroke(borderColor, lineWidth: isSelected ? 1.2 : 1)
                    .allowsHitTesting(false)
            }
            .shadow(
                color: RecipeCategory.color(for: title).opacity(style == .filled ? (isSelected ? 0.24 : 0.12) : (isSelected ? 0.14 : 0.08)),
                radius: isSelected ? 10 : 6,
                y: isSelected ? 5 : 3
            )
            .opacity(isSelected ? 1 : 0.94)
    }

    private var backgroundStyle: AnyShapeStyle {
        switch style {
        case .filled:
            return AnyShapeStyle(RecipeCategory.gradient(for: title))
        case .outlined:
            return isSelected
                ? AnyShapeStyle(RecipeCategory.gradient(for: title))
                : AnyShapeStyle(Color.white.opacity(0.96))
        }
    }

    private var borderColor: Color {
        switch style {
        case .filled:
            return Color.white.opacity(isSelected ? 0.66 : 0.26)
        case .outlined:
            return isSelected
                ? Color.clear
                : RecipeCategory.color(for: title).opacity(0.54)
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .filled:
            return .white
        case .outlined:
            return isSelected ? .white : RecipeCategory.color(for: title)
        }
    }
}

struct EditableTagEditor: View {
    @Binding var tags: [String]
    var placeholder: String = "Add tags"
    var helperText: String? = nil
    @State private var draftTag = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let helperText, !helperText.isEmpty {
                Text(helperText)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                TextField(placeholder, text: $draftTag)
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
                    .onSubmit {
                        commitDraftTags()
                    }

                Button("Add") {
                    commitDraftTags()
                }
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(RecipeTheme.accentStrong)
                .foregroundStyle(RecipeTheme.textOnAccent)
                .clipShape(Capsule())
                .buttonStyle(.plain)
            }

            if !tags.isEmpty {
                FlowTagList(tags: tags.map { "#\($0)" }) { displayedTag in
                    let rawTag = String(displayedTag.dropFirst())
                    tags.removeAll { $0.caseInsensitiveCompare(rawTag) == .orderedSame }
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
