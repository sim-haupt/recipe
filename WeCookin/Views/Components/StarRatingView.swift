import SwiftUI

struct StarRatingView: View {
    @Binding var rating: Int
    var maximum = 5
    var interactive = true

    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...maximum, id: \.self) { index in
                Image(systemName: index <= rating ? "star.fill" : "star")
                    .foregroundStyle(index <= rating ? .yellow : .secondary)
                    .onTapGesture {
                        guard interactive else { return }
                        rating = index
                    }
            }
        }
    }
}
