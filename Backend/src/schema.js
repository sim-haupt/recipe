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
      description: "A list of ingredient lines from the source."
    },
    preparation_steps: {
      type: "array",
      items: {
        type: "string"
      },
      description: "Ordered preparation steps from the source."
    },
    notes: {
      type: "array",
      items: {
        type: "string"
      },
      description: "Optional extra notes or caveats."
    },
    confidence: {
      type: "number",
      description: "A 0-1 confidence estimate for the extraction."
    }
  },
  required: ["summary", "ingredients", "preparation_steps", "notes", "confidence"]
};
