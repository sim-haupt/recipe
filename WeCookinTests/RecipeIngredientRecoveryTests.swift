import XCTest
@testable import WeCookin

final class RecipeIngredientRecoveryTests: XCTestCase {
    func testSelectBestExtractionPrefersStructuredIngredientSectionWhenAmountsAreLost() {
        let extraction = RecipeAIExtraction(
            title: "Vodka Sauce Pasta",
            summary: "Pasta in a creamy vodka tomato sauce.",
            ingredients: [
                "Sauce:",
                "1/4 cup vodka",
                "Yellow onion",
                "Garlic",
                "Extra-virgin olive oil",
                "Whole peeled tomatoes",
                "Tomato paste",
                "Crushed red pepper flakes",
                "Heavy cream",
                "Salt",
                "Black pepper",
                "Pasta:",
                "Penne pasta",
                "1 cup reserved starchy pasta cooking water",
                "To serve:",
                "Fresh basil and/or parsley",
                "Parmesan cheese"
            ],
            confidence: 0.95
        )

        let rawText = """
        Ingredients:
        2 tablespoons extra-virgin olive oil
        1/2 medium yellow onion, chopped
        3 garlic cloves, thinly sliced
        1/2 teaspoon sea salt
        Freshly ground black pepper
        1/2 teaspoon red pepper flakes
        1 (6-ounce) can tomato paste
        1/4 cup vodka, see note*
        1 (14-ounce) can whole peeled tomatoes, crushed
        1 pound tube-shaped pasta, such as penne or rigatoni
        1/2 cup heavy cream
        Chopped fresh parsley or fresh basil leaves, for garnish
        Freshly grated Parmesan cheese, for serving
        """

        let recovered = RecipeIngredientRecovery.selectBestExtraction(extraction, rawText: rawText)

        XCTAssertEqual(recovered.ingredients, [
            "2 tablespoons extra-virgin olive oil",
            "1/2 medium yellow onion, chopped",
            "3 garlic cloves, thinly sliced",
            "1/2 teaspoon sea salt",
            "Freshly ground black pepper",
            "1/2 teaspoon red pepper flakes",
            "1 (6-ounce) can tomato paste",
            "1/4 cup vodka, see note*",
            "1 (14-ounce) can whole peeled tomatoes, crushed",
            "1 pound tube-shaped pasta, such as penne or rigatoni",
            "1/2 cup heavy cream",
            "Chopped fresh parsley or fresh basil leaves, for garnish",
            "Freshly grated Parmesan cheese, for serving"
        ])
    }

    func testSelectBestExtractionKeepsOriginalWhenNoStructuredIngredientSectionExists() {
        let extraction = RecipeAIExtraction(
            title: "Quick Tofu",
            summary: "A quick tofu recipe.",
            ingredients: ["400g tofu", "2 tbsp cornstarch"],
            confidence: 0.8
        )

        let recovered = RecipeIngredientRecovery.selectBestExtraction(
            extraction,
            rawText: "Mix 400g tofu with 2 tbsp cornstarch and bake until crisp."
        )

        XCTAssertEqual(recovered.ingredients, extraction.ingredients)
    }
}
