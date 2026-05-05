import XCTest
@testable import WeCookin

final class PreviewMediaHitTestingTests: XCTestCase {
    func testPortraitInstagramImageHasLargeVerticalAspectFillOverflow() {
        let overflow = PreviewMediaHitTesting.aspectFillOverflow(
            imageSize: CGSize(width: 360, height: 640),
            containerSize: CGSize(width: 330, height: 210)
        )

        XCTAssertEqual(overflow.width, 0, accuracy: 0.01)
        XCTAssertGreaterThan(overflow.height, 180)
    }

    func testTypicalLandscapeWebImageDoesNotHaveVerticalAspectFillOverflow() {
        let overflow = PreviewMediaHitTesting.aspectFillOverflow(
            imageSize: CGSize(width: 1200, height: 630),
            containerSize: CGSize(width: 330, height: 210)
        )

        XCTAssertEqual(overflow.height, 0, accuracy: 0.01)
        XCTAssertGreaterThan(overflow.width, 0)
    }
}
