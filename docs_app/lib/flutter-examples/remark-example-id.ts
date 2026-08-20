/*
 * AI-Provenance:
 *   model: Claude Opus 5
 *   harness: Cursor
 */
import type { Root } from "mdast"
import { collectExamples } from "./extract.mjs"

/**
 * Stamps every `<AdvancedFormsExample>` with the content hash of its Dart
 * fences.
 *
 * Authors never write an id: the same hash is computed by
 * `scripts/flutter-examples.mjs` when it generates the Flutter bundle, so the
 * island a page asks for and the example the bundle registered are the same
 * thing by construction.
 */
export function remarkExampleId() {
  return (tree: Root) => {
    for (const { node, example } of collectExamples(tree)) {
      const attributes = node.attributes as { type: string; name: string; value: string }[]
      const existing = attributes.findIndex(a => a.type === "mdxJsxAttribute" && a.name === "id")
      const attribute = { type: "mdxJsxAttribute" as const, name: "id", value: example.id }

      if (existing === -1) {
        attributes.push(attribute)
      } else {
        attributes[existing] = attribute
      }
    }
  }
}
