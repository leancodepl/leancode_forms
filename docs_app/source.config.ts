/*
 * AI-Provenance:
 *   model: Claude Opus 5
 *   harness: Cursor
 */
import { defineConfig } from "fumadocs-mdx/config"
import { remarkExampleId } from "./lib/flutter-examples/remark-example-id"

// Global MDX options. The collections themselves live in `lib/source.ts` via
// `fumadocs-mdx/macro`; a collection-level `mdxOptions` would *replace* the
// fumadocs preset (Shiki, GFM, headings, search structure), while the global
// one is merged into it.
export default defineConfig({
  mdxOptions: {
    // Prepended rather than appended: the id has to be stamped on before any
    // other transformer can rewrite the tree the hash is taken from.
    remarkPlugins: plugins => [remarkExampleId, ...plugins],
  },
})
