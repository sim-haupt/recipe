import OpenAI from "openai";

import { recipeExtractionSchema } from "./schema.js";

const DEFAULT_MODEL = process.env.OPENAI_MODEL || "gpt-4.1-mini";
const MAX_TEXT_LENGTH = 24000;

const SYSTEM_PROMPT = [
  "You extract structured recipe data from scraped webpage text or social post text.",
  "Use only the provided input.",
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
  if (!request.rawText && !request.description && !request.title) {
    const error = new Error("At least one of title, description, or rawText is required.");
    error.statusCode = 400;
    throw error;
  }

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
            text: buildUserPrompt(request)
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
    "Raw text:",
    payload.rawText || ""
  ].join("\n");
}
