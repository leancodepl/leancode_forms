/*
 * AI-Provenance:
 *   model: Claude Opus 5
 *   harness: Cursor
 */

/**
 * Pulls the Dart out of `<AdvancedFormsExample>` elements in an MDX tree.
 *
 * Two callers share this file, and they must agree exactly: the remark plugin
 * that stamps an id onto the element the page renders, and
 * `scripts/flutter-examples.mjs`, which compiles that same snippet into the
 * Flutter bundle. The id is the content hash of the Dart, so agreement is
 * automatic — an edited snippet gets a new id on both sides at once, and a
 * stale bundle shows up as an id the manifest does not know.
 *
 * Written as JavaScript rather than TypeScript because the codegen script is
 * plain Node with no build step, while the remark plugin is TypeScript; only
 * plain ESM can be imported by both without extra tooling.
 */
import { createHash } from "node:crypto"

/** The element authors write in the docs. */
export const exampleTag = "AdvancedFormsExample"

/**
 * @typedef {object} ExtractedExample
 * @property {string} id Content hash of {@link dart}, and the key the bundle registers.
 * @property {string} dart All fences joined into one compilation unit.
 * @property {string[]} sources The individual fences, in document order.
 * @property {string | null} preview Widget to mount; inferred when not given.
 * @property {number | null} height Fixed island height, or null for auto.
 * @property {boolean} isolate Render in an iframe instead of a shared view.
 * @property {string | null} caption
 * @property {string[]} helpers Docs-only widgets the snippet leans on.
 */

/**
 * Line endings and trailing spaces are invisible in MDX but would otherwise
 * change the hash, so they are normalized away before hashing.
 *
 * @param {string} source
 */
export function normalizeDart(source) {
  return source
    .replaceAll(/\r\n?/g, "\n")
    .replaceAll(/[ \t]+$/gm, "")
    .trim()
}

/**
 * Joins the fences of one example into the file that gets compiled.
 *
 * @param {readonly string[]} sources
 */
export function joinSources(sources) {
  const body = sources.map(normalizeDart).filter(Boolean).join("\n\n")
  return body === "" ? "" : body + "\n"
}

/** @param {string} dart */
export function exampleId(dart) {
  return createHash("sha256").update(dart).digest("hex").slice(0, 12)
}

/**
 * The widget to mount when `preview` is not given: the first widget class in
 * the snippet, which in practice is the one the surrounding prose is about.
 *
 * @param {string} dart
 */
export function inferPreview(dart) {
  const match = /^class\s+([A-Za-z_$][\w$]*)\s+extends\s+(?:StatelessWidget|StatefulWidget)\b/m.exec(dart)
  return match?.[1] ?? null
}

/**
 * The `Docs*` widgets from `flutter/lib/support/` that a snippet references.
 *
 * These are conveniences of the docs, not API a reader can call, so a snippet
 * using one is not copy-pasteable as it stands. Collected here so the component
 * can say so on the page without an author having to remember to.
 *
 * @param {string} dart
 */
export function usedHelpers(dart) {
  return [...new Set([...dart.matchAll(/\bDocs[A-Z][\w$]*/g)].map(match => match[0]))].toSorted()
}

/**
 * @param {unknown} node
 * @returns {node is { type: string; name?: string | null; children?: unknown[]; attributes?: unknown[] }}
 */
function isNode(node) {
  return typeof node === "object" && node !== null && "type" in node
}

/** @param {any} node */
function isExampleElement(node) {
  return (node.type === "mdxJsxFlowElement" || node.type === "mdxJsxTextElement") && node.name === exampleTag
}

/**
 * Depth-first walk that lets the visitor stop the descent, which is how nested
 * examples are kept out of their parent's fence list.
 *
 * @param {any} node
 * @param {(node: any) => boolean | void} visit
 */
function walk(node, visit) {
  if (!isNode(node)) return
  if (visit(node) === true) return
  const children = /** @type {any[]} */ (node.children)
  if (!Array.isArray(children)) return
  for (const child of children) walk(child, visit)
}

/**
 * @param {any} node
 * @param {string} name
 * @returns {string | boolean | undefined}
 */
function attribute(node, name) {
  const attributes = /** @type {any[]} */ (node.attributes ?? [])
  const found = attributes.find(a => a?.type === "mdxJsxAttribute" && a.name === name)
  if (!found) return
  // `<X isolate>` parses with a null value.
  if (found.value == null) return true
  if (typeof found.value === "string") return found.value
  // `<X height={320}>` — the expression source, good enough for a literal.
  return typeof found.value.value === "string" ? found.value.value : undefined
}

/** @param {any} element */
function dartFences(element) {
  /** @type {string[]} */
  const sources = []
  for (const child of /** @type {any[]} */ (element.children ?? [])) {
    walk(child, node => {
      if (isExampleElement(node)) return true
      if (node.type === "code" && node.lang === "dart") sources.push(String(node.value ?? ""))
      return
    })
  }
  return sources
}

/**
 * Every `<AdvancedFormsExample>` in the tree, paired with the node it came from
 * so a caller can annotate it.
 *
 * @param {any} tree
 * @returns {{ node: any; example: ExtractedExample }[]}
 */
export function collectExamples(tree) {
  /** @type {{ node: any; example: ExtractedExample }[]} */
  const found = []

  walk(tree, node => {
    if (!isExampleElement(node)) return

    const sources = dartFences(node)
    const dart = joinSources(sources)
    const preview = attribute(node, "preview")
    const height = attribute(node, "height")
    const caption = attribute(node, "caption")
    const parsedHeight = typeof height === "string" ? Number(height) : NaN

    found.push({
      node,
      example: {
        id: exampleId(dart),
        dart,
        sources,
        preview: typeof preview === "string" ? preview : inferPreview(dart),
        height: Number.isFinite(parsedHeight) && parsedHeight > 0 ? parsedHeight : null,
        isolate: attribute(node, "isolate") !== undefined,
        caption: typeof caption === "string" ? caption : null,
        helpers: usedHelpers(dart),
      },
    })

    // Nested examples are not a thing; stop so their fences are not counted twice.
    return true
  })

  return found
}
