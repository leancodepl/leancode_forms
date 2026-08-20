/*
 * AI-Provenance:
 *   model: Cursor Grok 4.6
 *   harness: Cursor
 *   skills:
 *     - mark-ai-provenance
 */
import { a11y, base, imports } from "@leancodepl/eslint-config"

const config = [
  ...base,
  ...imports,
  ...a11y,
  {
    ignores: [
      "node_modules/**",
      ".next/**",
      "out/**",
      "build/**",
      ".source/**",
      "next-env.d.ts",
      // The nested Flutter package and everything generated from the docs.
      "flutter/**",
      "public/flutter-examples/**",
      "lib/flutter-examples/manifest.generated.ts",
    ],
  },
  {
    // Build scripts report progress on stdout; that is their interface.
    files: ["scripts/**"],
    rules: { "no-console": "off" },
  },
]

export default config
