# WeCookin AI Enrichment Backend

This backend keeps your OpenAI API key off the iPhone app. The app sends extracted page or post text here, and this service returns structured recipe data for ingredients and preparation.

## Endpoints

- `GET /health`
- `POST /api/recipe-extract`

## Request shape

```json
{
  "sourceURL": "https://example.com/recipe",
  "title": "Crispy Tacos",
  "description": "Optional short summary",
  "rawText": "Full cleaned article or caption text"
}
```

## Response shape

```json
{
  "summary": "Short recipe summary",
  "ingredients": ["1 lb chicken", "2 tortillas"],
  "preparation_steps": ["Preheat the oven.", "Bake the chicken."],
  "notes": ["If the source text is incomplete, fields may be empty."],
  "confidence": 0.86
}
```

## Setup

1. Install dependencies:

```bash
npm install
```

2. Copy `.env.example` to `.env` and fill in `OPENAI_API_KEY`.
3. Start the server:

```bash
npm run dev
```

4. Point the iOS app to the server by setting `RecipeEnrichmentAPIURL` in [WeCookin-Info.plist](/Users/szy/Documents/GitHub/recipe/Config/WeCookin-Info.plist) to:

```text
http://127.0.0.1:8787/api/recipe-extract
```

For real-device testing, use your Mac's local network IP instead of `127.0.0.1`.

## Deploy to Railway

This repo is a monorepo, so the Railway service should deploy only the backend subfolder.

1. Create a new Railway project.
2. Add a new service from your GitHub repo.
3. In the Railway service settings, set the root directory to:

```text
/Backend
```

4. In service variables, add:
   - `OPENAI_API_KEY`
   - `OPENAI_MODEL` = `gpt-4.1`
5. In the service Networking settings, generate a public domain.
6. In the service Deploy settings, set the config-as-code path to:

```text
/Backend/railway.json
```

This tells Railway to use:
- `npm start`
- `/health` as the healthcheck path
- a restart-on-failure policy

After Railway gives you a public URL, set `RecipeEnrichmentAPIURL` in [WeCookin-Info.plist](/Users/szy/Documents/GitHub/recipe/Config/WeCookin-Info.plist) to:

```text
https://your-service.up.railway.app/api/recipe-extract
```

## Notes

- The backend uses the OpenAI Responses API with strict JSON schema output.
- If the model cannot find enough recipe detail in the source text, it should return empty arrays instead of inventing content.
- Instagram, WhatsApp, and some other apps may only share partial captions or links, so extraction quality depends on what iOS makes available.
