export const recipeExtractionSchema = {
  type: "object",
  additionalProperties: false,
  properties: {
    summary: {
      type: "string",
      description: "A short plain-language recipe summary."
    },
    ingredients: {
      type: "array",
      items: {
        type: "string"
      },
      description: "A list of ingredient lines from the source, always in English."
    },
    confidence: {
      type: "number",
      description: "A 0-1 confidence estimate for the extraction."
    }
  },
  required: ["summary", "ingredients", "confidence"]
};
