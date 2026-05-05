import { recipeExtractionSchema } from "./schema.js";

const DEFAULT_MODEL = process.env.OPENAI_MODEL || "gpt-5.2";
const MAX_TEXT_LENGTH = 24000;
const FETCHED_TEXT_LENGTH = 16000;

const SYSTEM_PROMPT = [
  "You extract structured recipe data from scraped webpage text or social post text.",
  "Use only the provided input.",
  "The scraped text may include navigation, related content, social captions, cookie text, or other page chrome.",
  "For Instagram, TikTok, reels, or other social posts, the useful recipe content may appear only in the caption or page description.",
  "When social captions contain recipe data inline, extract ingredient lines from dashed lines, numbered lines, emoji-prefixed lines, or short inventory-style sentences.",
  "Social captions may be bilingual or duplicated in multiple languages. If the same recipe appears twice in different languages, merge it into one clean extraction instead of duplicating the recipe.",
  "Generate a short natural English recipe title based on the recipe itself, not on page chrome or social engagement text.",
  "For social posts, never copy likes, comments, account names, dates, or long caption text into the title.",
  "Prefer titles like main ingredient + style and optionally time, for example '10-Minute Crispy Tofu'.",
  "When a recipe has subsections such as sauce, marinade, topping, glaze, garnish, or to serve, include those ingredient lines too if they are clearly part of the same recipe.",
  "Always return ingredient lines in English.",
  "If the source is only in German, translate the ingredient lines into natural English while preserving amounts and measurements.",
  "If the source includes both German and English, always prefer the English version and discard the duplicate German version.",
  "Treat section markers such as REZEPT, RECIPE, ZUTATEN, INGREDIENTS, Zum Zusammenbauen, To assemble, Preparation, Instructions, Notes, Tipps, or Tips as strong recipe structure hints.",
  "Ignore engagement counts, hashtags, ad markers, creator mentions, discount codes, and conversational intro/outro text unless they contain actual recipe instructions, storage guidance, or ingredient details.",
  "Prioritize recipe-specific content such as structured ingredient lines.",
  "Ignore unrelated page text, author bios, comment prompts, navigation labels, legal/footer text, and preparation instructions.",
  "Do not invent ingredients or quantities that are not supported by the source.",
  "If the source is incomplete, return empty arrays or an empty summary rather than guessing.",
  "The summary must be exactly one concise sentence in English.",
  "Keep ingredient lines concise.",
  "Return ingredients only. Do not return preparation steps or notes."
].join(" ");

export async function extractRecipeContent(payload) {
  const prepared = await prepareRecipeRequest(payload);
  return extractRecipeContentFromPreparedRequest(prepared);
}

export function previewPayloadDiagnostics(payload) {
  const normalizedRequest = normalizePayload(payload);
  const candidateText = extractCandidateText({
    ...normalizedRequest,
    fetchedTitle: "",
    fetchedDescription: "",
    fetchedText: ""
  });

  return {
    normalizedRequest,
    candidateText,
    containsHTML: /<[^>]+>/.test(candidateText),
    containsIframe: /<iframe/i.test(candidateText),
    containsScript: /<script/i.test(candidateText)
  };
}

export async function debugRecipeContent(payload) {
  const prepared = await prepareRecipeRequest(payload);
  const extraction = await extractRecipeContentFromPreparedRequest(prepared);
  const userPrompt = buildUserPrompt(prepared.enrichedRequest);

  return {
    extraction,
    debug: {
      model: DEFAULT_MODEL,
      systemPrompt: SYSTEM_PROMPT,
      userPrompt,
      normalizedRequest: {
        sourceURL: prepared.request.sourceURL,
        title: prepared.request.title,
        description: prepared.request.description,
        rawText: prepared.request.rawText
      },
      fetchedContext: {
        fetchedTitle: prepared.enrichedRequest.fetchedTitle || "",
        fetchedDescription: prepared.enrichedRequest.fetchedDescription || "",
        fetchedText: prepared.enrichedRequest.fetchedText || ""
      },
      candidateText: extractCandidateText(prepared.enrichedRequest)
    }
  };
}

async function prepareRecipeRequest(payload) {
  const apiKey = process.env.OPENAI_API_KEY?.trim();
  if (!apiKey) {
    const error = new Error("Missing OPENAI_API_KEY.");
    error.statusCode = 500;
    throw error;
  }

  const request = normalizePayload(payload);
  if (!request.rawText && !request.description && !request.title && !request.sourceURL) {
    const error = new Error("At least one of title, description, or rawText is required.");
    error.statusCode = 400;
    throw error;
  }

  const enrichedRequest = await enrichPayloadWithRemoteContent(request);
  return { apiKey, request, enrichedRequest };
}

async function extractRecipeContentFromPreparedRequest(prepared) {
  const { default: OpenAI } = await import("openai");
  const client = new OpenAI({ apiKey: prepared.apiKey });
  const response = await client.responses.create({
    model: DEFAULT_MODEL,
    input: [
      {
        role: "system",
        content: [
          {
            type: "input_text",
            text: SYSTEM_PROMPT
          }
        ]
      },
      {
        role: "user",
        content: [
          {
            type: "input_text",
            text: buildUserPrompt(prepared.enrichedRequest)
          }
        ]
      }
    ],
    text: {
      format: {
        type: "json_schema",
        name: "recipe_extraction",
        strict: true,
        schema: recipeExtractionSchema
      }
    }
  });

  const outputText = response.output_text?.trim();
  if (!outputText) {
    const error = new Error("OpenAI returned an empty response.");
    error.statusCode = 502;
    throw error;
  }

  let parsed;
  try {
    parsed = JSON.parse(outputText);
  } catch {
    const error = new Error("OpenAI returned invalid JSON.");
    error.statusCode = 502;
    throw error;
  }

  return normalizeExtraction(parsed, prepared.enrichedRequest);
}

function normalizePayload(payload = {}) {
  return {
    sourceURL: clampString(payload.sourceURL, 1000),
    title: clampString(payload.title, 300),
    description: clampString(payload.description, 4000),
    rawText: clampString(payload.rawText, MAX_TEXT_LENGTH)
  };
}

function normalizeExtraction(value = {}, request = {}) {
  const ingredients = normalizeRecipeArray(value.ingredients, 40, 240);
  return {
    title: normalizeGeneratedTitle(value.title, request),
    summary: clampString(value.summary, 3000).replace(/\s+/g, " ").trim(),
    ingredients,
    confidence: normalizeConfidence(value.confidence)
  };
}

function normalizeGeneratedTitle(title, request = {}) {
  const cleaned = clampString(
    cleanRecipeLine(stripSocialLeadNoise(title || ""))
      .replace(/^[“"'`]+|[”"'`]+$/g, "")
      .replace(/\s+/g, " ")
      .trim(),
    90
  );

  if (cleaned && !looksLikeNoisySocialTitle(cleaned)) {
    return cleaned;
  }

  const requestTitle = clampString(stripSocialLeadNoise(request.title || ""), 90);
  if (requestTitle && !looksLikeNoisySocialTitle(requestTitle)) {
    return requestTitle;
  }

  return "";
}

function normalizeStringArray(value, maxItems, maxLength) {
  if (!Array.isArray(value)) {
    return [];
  }

  return value
    .map((item) => clampString(item, maxLength))
    .filter(Boolean)
    .slice(0, maxItems);
}

function normalizeRecipeArray(value, maxItems, maxLength) {
  return normalizeStringArray(value, maxItems, maxLength)
    .flatMap(splitCompoundEntry)
    .map(cleanRecipeLine)
    .filter(Boolean)
    .slice(0, maxItems);
}

function normalizeConfidence(value) {
  if (typeof value !== "number" || Number.isNaN(value)) {
    return 0;
  }

  return Math.min(1, Math.max(0, value));
}

function clampString(value, maxLength) {
  if (typeof value !== "string") {
    return "";
  }

  return value.trim().slice(0, maxLength);
}

function buildUserPrompt(payload) {
  const candidateText = extractCandidateText(payload);

  return [
    "Extraction guidance:",
    "- Generate a short English recipe title based on the actual recipe content.",
    "- For social URLs, do not copy the caption blob, likes/comments line, account name, or date into the title.",
    "- Prefer a title like main ingredient + style and optionally time, e.g. '10-Minute Crispy Tofu'.",
    "- Extract all recipe ingredients that belong to this recipe, including sauce, marinade, topping, glaze, garnish, or serving components when they are clearly part of the recipe.",
    "- Prefer ingredient lines over any intro, ad, commentary, or instruction text.",
    "- Return ingredients only and do not copy instruction sentences into the ingredients array.",
    "- If the same recipe is repeated in two languages, keep one normalized English set of ingredients.",
    "- If the source is only German, translate ingredients to English.",
    "- Ignore preparation instructions, storage tips, and assembly notes.",
    `Source URL: ${payload.sourceURL || ""}`,
    `Title: ${payload.title || ""}`,
    `Description: ${payload.description || ""}`,
    "Candidate recipe text:",
    candidateText || ""
  ].join("\n");
}

function extractCandidateText(payload) {
  const normalizedText = normalizeRecipeCandidateText(
    [payload.description, payload.rawText, payload.fetchedDescription, payload.fetchedText]
      .filter(Boolean)
      .join("\n")
  );

  const preferredText = preferredRecipeTextBlock(normalizedText);

  const lines = preferredText
    .split(/\n+/)
    .map((line) => stripSocialLeadNoise(line).trim())
    .filter(Boolean);

  const introLines = normalizedText
    .split(/\n+/)
    .map((line) => stripSocialLeadNoise(line).trim())
    .filter(Boolean);

  const preferredLines = preferredRecipeLines(lines, introLines);
  return dedupe(preferredLines).join("\n");
}

async function enrichPayloadWithRemoteContent(payload) {
  if (!payload.sourceURL) {
    return {
      ...payload,
      fetchedTitle: "",
      fetchedDescription: "",
      fetchedText: ""
    };
  }

  try {
    const fetched = await fetchRemotePageContext(payload.sourceURL);
    return {
      ...payload,
      fetchedTitle: fetched.title,
      fetchedDescription: fetched.description,
      fetchedText: fetched.text
    };
  } catch {
    return {
      ...payload,
      fetchedTitle: "",
      fetchedDescription: "",
      fetchedText: ""
    };
  }
}

async function fetchRemotePageContext(sourceURL) {
  const response = await fetch(sourceURL, {
    headers: {
      "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)"
    },
    signal: AbortSignal.timeout(15000),
    redirect: "follow"
  });

  if (!response.ok) {
    throw new Error(`Remote fetch failed: ${response.status}`);
  }

  const html = await response.text();
  const title = firstNonEmpty([
    capture(html, "<meta[^>]*property=[\"']og:title[\"'][^>]*content=[\"'](.*?)[\"'][^>]*>"),
    capture(html, "<meta[^>]*name=[\"']twitter:title[\"'][^>]*content=[\"'](.*?)[\"'][^>]*>"),
    capture(html, "<title[^>]*>(.*?)</title>")
  ]);
  const description = firstNonEmpty([
    capture(html, "<meta[^>]*property=[\"']og:description[\"'][^>]*content=[\"'](.*?)[\"'][^>]*>"),
    capture(html, "<meta[^>]*name=[\"']twitter:description[\"'][^>]*content=[\"'](.*?)[\"'][^>]*>"),
    capture(html, "<meta[^>]*name=[\"']description[\"'][^>]*content=[\"'](.*?)[\"'][^>]*>")
  ]);
  const text = extractPageText(html);

  return {
    title: clampString(decodeEntities(title || ""), 1200),
    description: clampString(decodeEntities(description || ""), 3000),
    text: clampString(normalizeRecipeCandidateText(text || decodeEntities(description || "")), FETCHED_TEXT_LENGTH)
  };
}

function extractPageText(html) {
  const withoutScripts = html
    .replace(/<script[\s\S]*?<\/script>/gi, " ")
    .replace(/<style[\s\S]*?<\/style>/gi, " ")
    .replace(/<noscript[\s\S]*?<\/noscript>/gi, " ")
    .replace(/<svg[\s\S]*?<\/svg>/gi, " ")
    .replace(/<(nav|footer|header|aside|form)[\s\S]*?<\/\1>/gi, " ");

  const withLineBreaks = withoutScripts
    .replace(/<\/(p|div|section|article|li|ul|ol|h1|h2|h3|h4|h5|h6|br|tr)>/gi, "\n")
    .replace(/<[^>]+>/g, " ");

  const normalizedLines = normalizeRecipeCandidateText(decodeEntities(withLineBreaks))
    .split(/\n+/)
    .map((line) => line.replace(/\s+/g, " ").trim())
    .filter(Boolean)
    .filter(isUsefulContentLine);

  const focused = focusRecipeLines(normalizedLines);
  const selected = focused.length > 0 ? focused : normalizedLines.slice(0, 80);
  return selected.join("\n");
}

function normalizeRecipeCandidateText(value) {
  return decodeEntities(value || "")
    .replace(/<script[\s\S]*?<\/script>/gi, "\n")
    .replace(/<iframe[\s\S]*?<\/iframe>/gi, "\n")
    .replace(/<style[\s\S]*?<\/style>/gi, "\n")
    .replace(/<[^>]+>/g, " ")
    .replace(/�/g, "\n")
    .replace(/\r\n/g, "\n")
    .replace(/\r/g, "\n")
    .replace(/\b(REZEPT|RECIPE)\b/gi, "\n$1")
    .replace(/\b(ZUTATEN|INGREDIENTS|INSTRUCTIONS|DIRECTIONS|METHOD|PREPARATION|NOTES|TIPPS|TIPS|TO ASSEMBLE|ZUM ZUSAMMENBAUEN)\b\s*:?/gi, "\n$&\n")
    .replace(/\s+-(?=\d|[A-Za-zÄÖÜäöü])/g, "\n-")
    .replace(/([.!?])\s+(?=(Add|Mix|Chop|Serve|Assemble|Cook|Bake|Fry|Heat|Stir|Whisk|Combine|Fold|Alles|Mit|Dann|Zum|Vermischen|Braten|Servieren|Zusammenbauen)\b)/gi, "$1\n")
    .replace(/(?<=[A-Za-zÄÖÜäöü0-9])\s+(?=(Add|Mix|Chop|Serve|Assemble|Cook|Bake|Fry|Heat|Stir|Whisk|Combine|Fold|Alles|Mit|Dann|Zum|Vermischen|Braten|Servieren|Zusammenbauen)\b)/gi, "\n")
    .replace(/\n{3,}/g, "\n\n")
    .trim();
}

function preferredRecipeLines(lines, introCandidates = []) {
  if (lines.length === 0) return [];

  const sanitized = lines
    .map((line) => line.replace(/\s+/g, " ").trim())
    .filter(Boolean);

  const intro = introCandidates
    .map(stripSocialLeadNoise)
    .map((line) => line.replace(/^[:\-\s]+/, "").trim())
    .filter(Boolean)
    .filter((line) => !looksLikeIngredientLine(line))
    .filter((line) => !looksLikeNoisySocialTitle(line))
    .slice(0, 2);

  return [...intro, ...sanitized.slice(0, 80)];
}

function preferredRecipeTextBlock(text) {
  const englishMatch = text.match(/(?:^|\n)(RECIPE(?:\s*[:(]|$)[\s\S]*)/i);
  const germanMatch = text.match(/(?:^|\n)(REZEPT(?:\s*[:(]|$)[\s\S]*)/i);
  const englishIndex = englishMatch ? text.indexOf(englishMatch[1]) : -1;
  const germanIndex = germanMatch ? text.indexOf(germanMatch[1]) : -1;

  if (englishIndex !== -1) {
    const englishBlock = text.slice(englishIndex, germanIndex !== -1 && germanIndex > englishIndex ? germanIndex : undefined);
    return englishBlock.trim();
  }

  if (germanIndex !== -1) {
    return text.slice(germanIndex).trim();
  }

  return text;
}

function looksLikeIngredientLine(line) {
  const lower = (line || "").toLowerCase();
  if (!lower || lower.length > 180) return false;
  if (lower.includes("likes") || lower.includes("comments") || lower.includes("@")) return false;
  if (looksLikeCaptionOutro(line)) return false;

  return /^[-•]/.test(line)
    || /\b(\d+\/\d+|\d+(?:[.,]\d+)?)\s*(g|kg|ml|l|tbsp|tsp|el|tl|cup|cups|clove|cloves|cans?|pinch)\b/i.test(line);
}

function focusRecipeLines(lines) {
  const ingredientSection = sectionLines(
    lines,
    ["ingredients", "ingredient list", "what you need"],
    ["instructions", "directions", "method", "preparation", "steps", "how to make", "notes", "tips"]
  );
  const intro = lines
    .filter((line) => !line.toLowerCase().includes("ingredients") && !line.toLowerCase().includes("instructions"))
    .slice(0, 4);

  const result = [];
  if (intro.length) result.push(...intro);
  if (ingredientSection.length) result.push("Ingredients:", ...ingredientSection);

  return dedupe(result).slice(0, 90);
}

function sectionLines(lines, headers, endHeaders) {
  const startIndex = lines.findIndex((line) => {
    const normalized = line.toLowerCase();
    return headers.some((header) => normalized === header || normalized.startsWith(`${header}:`));
  });
  if (startIndex === -1) return [];

  const remaining = lines.slice(startIndex + 1);
  const endIndex = remaining.findIndex((line) => {
    const normalized = line.toLowerCase();
    return endHeaders.some((header) => normalized === header || normalized.startsWith(`${header}:`));
  });

  return (endIndex === -1 ? remaining : remaining.slice(0, endIndex)).slice(0, 30);
}

function isUsefulContentLine(line) {
  if (line.length < 2 || line.length > 260) return false;
  if (line.includes("http")) return false;

  const lower = line.toLowerCase();
  const excludedPhrases = [
    "cookie",
    "privacy",
    "terms",
    "sign up",
    "sign in",
    "log in",
    "newsletter",
    "advertisement",
    "sponsored",
    "related recipes",
    "jump to comments",
    "follow us",
    "follow me",
    "leave a comment",
    "all rights reserved",
    "skip to content",
    "rate this recipe",
    "pin this",
    "share this",
    "facebook",
    "instagram",
    "tiktok"
  ];

  return !excludedPhrases.some((phrase) => lower.includes(phrase));
}

function looksLikeCaptionOutro(line) {
  const lower = line.toLowerCase();
  return lower.includes("much love")
    || lower.includes("alles liebe")
    || lower.includes("schaut bei")
    || lower.includes("code:")
    || lower.includes("taste that matters");
}

function capture(html, pattern) {
  const regex = new RegExp(pattern, "is");
  const match = html.match(regex);
  return match?.[1]?.trim() || "";
}

function decodeEntities(value) {
  return value
    .replace(/&amp;/g, "&")
    .replace(/&quot;/g, "\"")
    .replace(/&#39;/g, "'")
    .replace(/&apos;/g, "'")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&nbsp;/g, " ")
    .replace(/&#x([0-9A-Fa-f]+);/g, (_, hex) => {
      const code = Number.parseInt(hex, 16);
      return Number.isNaN(code) ? "" : String.fromCodePoint(code);
    })
    .replace(/&#([0-9]+);/g, (_, decimal) => {
      const code = Number.parseInt(decimal, 10);
      return Number.isNaN(code) ? "" : String.fromCodePoint(code);
    })
    .replace(/[ \t\f\v]+/g, " ")
    .replace(/ *\n+ */g, "\n")
    .trim();
}

function firstNonEmpty(values) {
  return values.find((value) => typeof value === "string" && value.trim().length > 0) || "";
}

function dedupe(values) {
  const seen = new Set();
  return values.filter((value) => {
    const key = value.toLowerCase();
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });
}

function splitCompoundEntry(entry) {
  const text = (entry || "").trim();
  if (!text) return [];
  if (text.length < 180 && !/\n/.test(text)) return [text];

  return normalizeRecipeCandidateText(text)
    .split(/\n+/)
    .map((line) => line.trim())
    .filter(Boolean);
}

function cleanRecipeLine(line) {
  return clampString(
    (line || "")
      .replace(/^[-•]\s*/, "")
      .replace(/^\d+[\.\)]\s*/, "")
      .replace(/^(recipe|rezept)\s*\([^)]*\)\s*:?/i, "")
      .replace(/^(ingredients|zutaten|sauce|to assemble|zum zusammenbauen)\s*:?/i, "")
      .trim(),
    360
  );
}

function stripSocialLeadNoise(line) {
  return (line || "")
    .replace(/^\s*\d+[A-Z]?\s+likes,\s*\d+\s+comments\s*-\s*.*?:\s*/i, "")
    .replace(/^\s*\d+[A-Z]?\s+likes\s*-\s*.*?:\s*/i, "")
    .replace(/^\s*[^:]{0,120}\bon\s+[A-Z][a-z]+\s+\d{1,2},\s+\d{4}:\s*/i, "")
    .replace(/\s+/g, " ")
    .trim();
}

function looksLikeNoisySocialTitle(line) {
  const lower = (line || "").toLowerCase();
  return lower.length > 120
    || lower.includes("likes")
    || lower.includes("comments")
    || lower.includes("@")
    || lower.includes("advertisement")
    || lower.includes("werbung/ad")
    || lower.includes("this is my go to")
    || lower.includes("much love");
}
