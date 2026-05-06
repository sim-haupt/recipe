import test from "node:test";
import assert from "node:assert/strict";

import { previewPayloadDiagnostics, reconcileIngredientAmountsForTesting } from "../src/recipeExtractor.js";

test("webpage and instagram preview payloads normalize to the same safe contract", () => {
  const webpage = previewPayloadDiagnostics({
    sourceURL: "https://www.example.com/recipes/pasta",
    title: "Burst Tomato Pasta",
    description: "A bright pasta with tomatoes and basil.",
    rawText: "Ingredients:\n- 200g pasta\n- 2 cups cherry tomatoes\n- basil"
  });

  const instagram = previewPayloadDiagnostics({
    sourceURL: "https://www.instagram.com/reel/DWjnf6LAuqm/",
    title: "fitgreenmind on Instagram",
    description: "(Werbung/Ad) STULLEN AROUND THE WORLD 🗺️ 🥪 pt. 3: chickpea sandwich",
    rawText: "REZEPT (4 Portionen): -1 Zwiebel -3 Zehen Knoblauch -2 Dosen Kichererbsen\nRECIPE (4 servings): -1 onion -3 cloves garlic -2 cans chickpeas"
  });

  assert.deepEqual(
    Object.keys(webpage.normalizedRequest).sort(),
    Object.keys(instagram.normalizedRequest).sort()
  );
  assert.equal(webpage.containsHTML, false);
  assert.equal(instagram.containsHTML, false);
  assert.equal(webpage.containsIframe, false);
  assert.equal(instagram.containsIframe, false);
  assert.equal(webpage.containsScript, false);
  assert.equal(instagram.containsScript, false);
});

test("instagram payload diagnostics strip embed-like markup from candidate text", () => {
  const diagnostics = previewPayloadDiagnostics({
    sourceURL: "https://www.instagram.com/reel/DWjnf6LAuqm/",
    title: "Instagram Reel",
    description: "<iframe src=\"https://instagram.com/embed\"></iframe>",
    rawText: "<script>alert('x')</script> RECIPE: -1 onion -2 cans chickpeas"
  });

  assert.equal(diagnostics.containsHTML, false);
  assert.equal(diagnostics.containsIframe, false);
  assert.equal(diagnostics.containsScript, false);
  assert.match(diagnostics.candidateText, /RECIPE/i);
  assert.match(diagnostics.candidateText, /chickpeas/i);
});

test("instagram diagnostics prefer the english recipe block and drop noisy social lead text", () => {
  const diagnostics = previewPayloadDiagnostics({
    sourceURL: "https://www.instagram.com/reel/Ckyu1Q3K10g/",
    title: "168K likes, 763 comments - fitgreenmind on November 10, 2022: 10min TOFU",
    description: "",
    rawText: [
      "168K likes, 763 comments - fitgreenmind on November 10, 2022: \"10min TOFU😍 This is my go to recipe for tofu\"",
      "REZEPT (2 Portionen,10min Zubereitungszeit):",
      "-400g Tofu, trockenge tupft",
      "-2 El Maisstärke",
      "RECIPE (2 servings,10min prep time):",
      "-400g firm tofu, pat dried",
      "-2 Tbsp cornstarch",
      "-salt to taste"
    ].join("\n")
  });

  assert.doesNotMatch(diagnostics.candidateText, /168K likes/i);
  assert.match(diagnostics.candidateText, /RECIPE/i);
  assert.match(diagnostics.candidateText, /firm tofu/i);
  assert.match(diagnostics.candidateText, /cornstarch/i);
  assert.doesNotMatch(diagnostics.candidateText, /trockenge/i);
});

test("candidate text preserves grouped ingredient subsection markers", () => {
  const diagnostics = previewPayloadDiagnostics({
    sourceURL: "https://www.instagram.com/reel/example/",
    title: "",
    description: "",
    rawText: [
      "RECIPE:",
      "-400g firm tofu, pat dried",
      "-2 Tbsp cornstarch",
      "Sauce:",
      "-4 Tbsp soy sauce",
      "-2 Tbsp white wine vinegar",
      "To serve:",
      "-rice",
      "-spring onions"
    ].join("\n")
  });

  assert.match(diagnostics.candidateText, /Sauce:/);
  assert.match(diagnostics.candidateText, /To serve:/);
});

test("narrative recipe text keeps distinct component cues for gpt inference", () => {
  const diagnostics = previewPayloadDiagnostics({
    sourceURL: "https://www.instagram.com/reel/narrative-example/",
    title: "",
    description: "",
    rawText: [
      "The chicken is ridiculously good in this recipe, but honestly? The veggies might be the best part.",
      "Add 4 chicken leg quarters (or 2lbs thighs) to a large bowl. Drizzle with 1 tbsp olive oil, add the zest + juice of a large lemon, 1 tbsp garlic powder, 1 tbsp oregano, 1/2 tsp cayenne pepper, 1.5 tbsp paprika, and a generous pinch of salt and pepper. I also add 2 tbsp tomato paste & 4 minced garlic cloves.",
      "I used 2 medium sweet potato, a large handful broccoli florets, and a large shallot (or red onion).",
      "Drizzle with olive oil, season with salt, 1/2 tbsp oregano, & 1/2 tbsp garlic powder.",
      "For your creamy lemony zesty sauce, mix 3 tbsp mayo with 1 tbsp tomato paste, 1 minced garlic clove, the zest and juice of 1 lemon, and a pinch of salt.",
      "Plate up your chicken with veggies, top with finely chopped fresh parsley, a little sauce, and serve with regular rice, quinoa, or protein rice if you like."
    ].join("\n")
  });

  assert.match(diagnostics.candidateText, /chicken leg quarters/i);
  assert.match(diagnostics.candidateText, /sweet potato/i);
  assert.match(diagnostics.candidateText, /creamy lemony zesty sauce/i);
  assert.match(diagnostics.candidateText, /mayo/i);
  assert.match(diagnostics.candidateText, /regular rice/i);
});

test("reconciles missing amounts from structured ingredient source lines", () => {
  const reconciled = reconcileIngredientAmountsForTesting(
    [
      "firm tofu, pat dried",
      "cornstarch",
      "soy sauce",
      "white wine or balsamic vinegar"
    ],
    [
      "Ingredients:",
      "-400g firm tofu, pat dried",
      "-2 Tbsp cornstarch",
      "Sauce:",
      "-4 Tbsp soy sauce",
      "-2 Tbsp white wine or balsamic vinegar"
    ].join("\n")
  );

  assert.deepEqual(reconciled, [
    "400g firm tofu, pat dried",
    "2 Tbsp cornstarch",
    "Sauce:",
    "4 Tbsp soy sauce",
    "2 Tbsp white wine or balsamic vinegar"
  ].filter((line) => !line.endsWith(":")));
});

test("does not replace instruction text while reconciling ingredient amounts", () => {
  const reconciled = reconcileIngredientAmountsForTesting(
    ["salt", "black pepper"],
    [
      "Instructions:",
      "Add salt and black pepper to taste.",
      "Mix well."
    ].join("\n")
  );

  assert.deepEqual(reconciled, ["salt", "black pepper"]);
});
