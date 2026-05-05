import test from "node:test";
import assert from "node:assert/strict";

import { previewPayloadDiagnostics } from "../src/recipeExtractor.js";

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
