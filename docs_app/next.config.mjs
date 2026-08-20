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
  /**
   * Authoring loop for the live examples: point this at `npm run examples:serve`
   * and the islands come from the Flutter dev server instead of the last
   * `examples:build`. It has to be a proxy rather than a direct URL because the
   * debug asset server sends no `Access-Control-Allow-Origin` header, unlike
   * the release one.
   */
  async rewrites() {
    const devServer = process.env.FLUTTER_EXAMPLES_DEV_SERVER
    if (!devServer) return []

    return {
      beforeFiles: [{ source: "/flutter-examples/:path*", destination: `${devServer}/:path*` }],
    }
  },
}

export default withMDX(config)
