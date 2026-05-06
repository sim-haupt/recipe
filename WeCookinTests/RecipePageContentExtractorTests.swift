import XCTest
@testable import WeCookin

final class RecipePageContentExtractorTests: XCTestCase {
    func testPrefersMeasuredIngredientsSectionWhenPageContainsTwoIngredientSections() {
        let html = """
        <html>
        <head><title>Vodka Pasta</title></head>
        <body>
          <h2>Ingredients</h2>
          <p>Vodka, of course! You’ll only use 1/4 cup here, so choose one that you’d like to have on hand.</p>
          <p>Yellow onion and garlic – They give the sauce savory depth of flavor.</p>
          <p>Extra-virgin olive oil – For sautéing the onion and garlic.</p>
          <p>Whole peeled tomatoes and tomato paste – They create the sauce’s flavorful tomato base.</p>
          <p>Heavy cream – It makes the sauce rich and creamy.</p>
          <p>Crushed red pepper flakes – They add a subtle kick of heat.</p>
          <p>Penne pasta – The classic choice for pairing with vodka sauce.</p>
          <p>Fresh basil and/or parsley – For garnish.</p>
          <p>Parmesan cheese – For serving.</p>
          <p>And salt and pepper – To make all the flavors pop!</p>

          <h2>Ingredients</h2>
          <ul>
            <li>2 tablespoons extra-virgin olive oil</li>
            <li>1/2 medium yellow onion, chopped</li>
            <li>3 garlic cloves, thinly sliced</li>
            <li>1/2 teaspoon sea salt</li>
            <li>Freshly ground black pepper</li>
            <li>1/2 teaspoon red pepper flakes</li>
            <li>1 (6-ounce) can tomato paste</li>
            <li>1/4 cup vodka, see note*</li>
            <li>1 (14-ounce) can whole peeled tomatoes, crushed</li>
            <li>1 pound tube-shaped pasta, such as penne or rigatoni</li>
            <li>1/2 cup heavy cream</li>
            <li>Chopped fresh parsley or fresh basil leaves, for garnish</li>
            <li>Freshly grated Parmesan cheese, for serving</li>
          </ul>

          <h2>Instructions</h2>
          <p>Bring a large pot of salted water to a boil.</p>
        </body>
        </html>
        """

        let content = RecipePageContentExtractor.extract(from: html, baseURL: URL(string: "https://example.com")!)
        let bodyText = content.bodyText ?? ""

        XCTAssertTrue(bodyText.contains("2 tablespoons extra-virgin olive oil"))
        XCTAssertTrue(bodyText.contains("1/2 medium yellow onion, chopped"))
        XCTAssertTrue(bodyText.contains("1 pound tube-shaped pasta, such as penne or rigatoni"))
        XCTAssertTrue(bodyText.contains("Ingredients:"))
    }
}
