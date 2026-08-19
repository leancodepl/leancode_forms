/*
 * AI-Provenance:
 *   model: Cursor Grok 4.6
 *   harness: Cursor
 *   skills:
 *     - mark-ai-provenance
 */
import { createMDX } from "fumadocs-mdx/next"
import { fileURLToPath } from "node:url"

const withMDX = createMDX()
const repoRoot = fileURLToPath(new URL("..", import.meta.url))

/** @type {import('next').NextConfig} */
const config = {
  outputFileTracingRoot: repoRoot,
  reactStrictMode: true,
  turbopack: {
    root: repoRoot,
  },
}

export default withMDX(config)
