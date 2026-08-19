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
    ignores: ["node_modules/**", ".next/**", "out/**", "build/**", ".source/**", "next-env.d.ts"],
  },
]

export default config
