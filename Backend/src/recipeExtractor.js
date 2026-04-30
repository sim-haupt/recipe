import OpenAI from "openai";

import { recipeExtractionSchema } from "./schema.js";

const DEFAULT_MODEL = process.env.OPENAI_MODEL || "gpt-4.1";
const MAX_TEXT_LENGTH = 24000;
const FETCHED_TEXT_LENGTH = 16000;

const SYSTEM_PROMPT = [
  "You extract structured recipe data from scraped webpage text or social post text.",
  "Use only the provided input.",
  "The scraped text may include navigation, related content, social captions, cookie text, or other page chrome.",
  "Prioritize recipe-specific content such as structured ingredients, instructions, and notes.",
  "Ignore unrelated page text, author bios, comment prompts, navigation labels, and legal/footer text.",
  "Do not invent ingredients, quantities, or steps that are not supported by the source.",
  "If the source is incomplete, return empty arrays or an empty summary rather than guessing.",
  "The summary must be exactly one concise sentence.",
  "Keep ingredient lines concise.",
  "Keep preparation steps ordered and actionable.",
  "Put any uncertainty or missing-data caveats into notes."
].join(" ");

export async function extractRecipeContent(payload) {
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

  const client = new OpenAI({ apiKey });
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
            text: buildUserPrompt(enrichedRequest)
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

  return normalizeExtraction(parsed);
}

function normalizePayload(payload = {}) {
  return {
    sourceURL: clampString(payload.sourceURL, 1000),
    title: clampString(payload.title, 300),
    description: clampString(payload.description, 4000),
    rawText: clampString(payload.rawText, MAX_TEXT_LENGTH)
  };
}

function normalizeExtraction(value = {}) {
  return {
    summary: clampString(value.summary, 3000).replace(/\s+/g, " ").trim(),
    ingredients: normalizeStringArray(value.ingredients, 40, 240),
    preparation_steps: normalizeStringArray(value.preparation_steps, 30, 500),
    notes: normalizeStringArray(value.notes, 12, 300),
    confidence: normalizeConfidence(value.confidence)
  };
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
  return [
    `Source URL: ${payload.sourceURL || ""}`,
    `Title: ${payload.title || ""}`,
    `Description: ${payload.description || ""}`,
    `Fetched page title: ${payload.fetchedTitle || ""}`,
    `Fetched page description: ${payload.fetchedDescription || ""}`,
    "Raw text:",
    payload.rawText || "",
    "Fetched page text:",
    payload.fetchedText || ""
  ].join("\n");
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
    text: clampString(text, FETCHED_TEXT_LENGTH)
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

  const normalizedLines = decodeEntities(withLineBreaks)
    .split(/\n+/)
    .map((line) => line.replace(/\s+/g, " ").trim())
    .filter(Boolean)
    .filter(isUsefulContentLine);

  const focused = focusRecipeLines(normalizedLines);
  const selected = focused.length > 0 ? focused : normalizedLines.slice(0, 80);
  return selected.join("\n");
}

function focusRecipeLines(lines) {
  const ingredientSection = sectionLines(
    lines,
    ["ingredients", "ingredient list", "what you need"],
    ["instructions", "directions", "method", "preparation", "steps", "how to make", "notes", "tips"]
  );
  const preparationSection = sectionLines(
    lines,
    ["instructions", "directions", "method", "preparation", "steps", "how to make"],
    ["notes", "tips", "nutrition", "related recipes"]
  );
  const notesSection = sectionLines(
    lines,
    ["notes", "tips"],
    ["nutrition", "related recipes"]
  );

  const intro = lines
    .filter((line) => !line.toLowerCase().includes("ingredients") && !line.toLowerCase().includes("instructions"))
    .slice(0, 4);

  const result = [];
  if (intro.length) result.push(...intro);
  if (ingredientSection.length) result.push("Ingredients:", ...ingredientSection);
  if (preparationSection.length) result.push("Preparation:", ...preparationSection);
  if (notesSection.length) result.push("Notes:", ...notesSection);

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
    .replace(/\s+/g, " ")
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
