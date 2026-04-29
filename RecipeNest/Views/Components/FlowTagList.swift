import SwiftUI

struct FlowTagList: View {
    let tags: [String]
    let onRemove: (String) -> Void

    var body: some View {
        if tags.isEmpty {
            Text("Add a few tags so recipes are easier to filter later.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(tags, id: \.self) { tag in
                        TagChip(title: tag, removable: true) {
                            onRemove(tag)
                        }
                    }
                }
            }
        }
    }
}
