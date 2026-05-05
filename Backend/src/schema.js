export const recipeExtractionSchema = {
  type: "object",
  additionalProperties: false,
  properties: {
    title: {
      type: "string",
      description: "A short natural English recipe title inferred from the source content."
    },
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
  required: ["title", "summary", "ingredients", "confidence"]
};
