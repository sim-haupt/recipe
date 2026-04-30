import "dotenv/config";

import express from "express";

import { extractRecipeContent } from "./recipeExtractor.js";

const app = express();
const port = Number(process.env.PORT || 8787);
const host = "0.0.0.0";

app.use(express.json({ limit: "1mb" }));

app.get("/health", (_request, response) => {
  response.json({
    status: "ok",
    service: "wecookin-recipe-enrichment"
  });
});

app.post("/api/recipe-extract", async (request, response) => {
  try {
    const extraction = await extractRecipeContent(request.body);
    response.json(extraction);
  } catch (error) {
    const statusCode = Number.isInteger(error?.statusCode) ? error.statusCode : 500;
    response.status(statusCode).json({
      error: error instanceof Error ? error.message : "Unknown server error."
    });
  }
});

app.use((_request, response) => {
  response.status(404).json({
    error: "Not found."
  });
});

app.listen(port, host, () => {
  console.log(`WeCookin AI enrichment backend listening on http://${host}:${port}`);
});
