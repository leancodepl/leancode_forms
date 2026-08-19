<!--
AI-Provenance:
  model: Cursor Grok 4.6
  harness: Cursor
  skills:
    - mark-ai-provenance
-->

# advanced-forms-docs

This is a Next.js application generated with [Create Fumadocs](https://github.com/fuma-nama/fumadocs).

MDX lives in the repo-root `docs/` folder. From this directory:

```bash
npm run dev
```

Open http://localhost:3000 to view the docs (notebook layout, pages served from `/`).

## Explore

- `lib/source.ts`: content source (`defineDocs` points at `../docs`).
- `lib/layout.shared.tsx`: shared notebook layout options.

| Route                                                 | Description            |
| ----------------------------------------------------- | ---------------------- |
| `app/(docs)/[[...slug]]`                              | Documentation pages    |
| `app/api/search/route.ts`                             | Search                 |
| `app/llms.txt` / `app/llms-full.txt` / `app/llms.mdx` | LLM markdown endpoints |
| `app/og`                                              | Open Graph images      |
