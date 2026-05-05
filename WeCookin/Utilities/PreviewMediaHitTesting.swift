import CoreGraphics

enum PreviewMediaHitTesting {
    static func aspectFillOverflow(imageSize: CGSize, containerSize: CGSize) -> CGSize {
        guard imageSize.width > 0, imageSize.height > 0, containerSize.width > 0, containerSize.height > 0 else {
            return .zero
        }

        let widthScale = containerSize.width / imageSize.width
        let heightScale = containerSize.height / imageSize.height
        let scale = max(widthScale, heightScale)
        let renderedWidth = imageSize.width * scale
        let renderedHeight = imageSize.height * scale

        return CGSize(
            width: max(0, (renderedWidth - containerSize.width) / 2),
            height: max(0, (renderedHeight - containerSize.height) / 2)
        )
    }
}
