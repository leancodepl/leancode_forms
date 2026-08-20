/*
 * AI-Provenance:
 *   model: Claude Opus 5
 *   harness: Cursor
 */
import Link from "fumadocs-core/link"
import type { ReactNode } from "react"
import { FlutterIsland } from "./flutter-island"
import { flutterExamples } from "@/lib/flutter-examples/manifest.generated"

interface AdvancedFormsExampleProps {
  /**
   * Content hash of the Dart fences, stamped on by the `remarkExampleId`
   * plugin. Authors never write it.
   */
  id?: string
  /** Widget to mount. Defaults to the first widget class in the snippet. */
  preview?: string
  /** Fixed island height. Needed for `Scaffold` and for scrolling demos. */
  height?: number | string
  /** Render in an iframe instead of a shared view. Escape hatch; needs `height`. */
  isolate?: boolean
  caption?: string
  /** The highlighted code fences, rendered under the island. */
  children: ReactNode
}

/**
 * A docs example that is both listing and demo: the Dart fences inside it are
 * compiled into the Flutter bundle at build time and rendered above the code
 * that produced them.
 *
 *     <AdvancedFormsExample preview="SignupForm">
 *
 *     ```dart
 *     class SignupForm extends StatefulWidget { ... }
 *     ```
 *
 *     </AdvancedFormsExample>
 *
 * An auto-height island must not use `Scaffold`, which takes all the height it
 * is offered; pass `height` for those.
 */
export function AdvancedFormsExample({ id, height, isolate, caption, children }: AdvancedFormsExampleProps) {
  if (!id) {
    throw new Error(
      "<AdvancedFormsExample> was rendered without an id. The remarkExampleId plugin in " +
        "source.config.ts is what adds it — check that the docs are built through it.",
    )
  }

  const example = flutterExamples[id]

  // A missing id means the manifest was generated from different MDX than this
  // build is rendering. Failing the build beats shipping a page with a hole in
  // it; in development it is usually just a forgotten `examples:generate`.
  if (!example) {
    const message =
      `No compiled example for id "${id}". Run \`npm run examples:generate\` — ` +
      "the docs and lib/flutter-examples/manifest.generated.ts are out of step."
    if (process.env.NODE_ENV === "production") throw new Error(message)
    console.warn(`[flutter-examples] ${message}`)
  }

  const pixels = typeof height === "string" ? Number(height) : height
  const fixedHeight = Number.isFinite(pixels) && (pixels as number) > 0 ? (pixels as number) : undefined
  const helpers = example?.helpers ?? []

  return (
    <figure className="not-prose my-6 flex flex-col gap-3">
      {example &&
        (isolate ? (
          <iframe
            src={`/flutter-examples/index.html?example=${id}`}
            title={`Live example: ${example.preview}`}
            loading="lazy"
            className="w-full rounded-lg border border-fd-border bg-fd-card"
            style={{ height: fixedHeight ?? 420 }}
          />
        ) : (
          <FlutterIsland exampleId={id} preview={example.preview} height={fixedHeight} />
        ))}

      {!example && (
        <div className="rounded-lg border border-fd-border bg-fd-muted p-4 text-xs text-fd-muted-foreground">
          This example has not been compiled yet. Run <code>npm run examples:build</code> to see it running.
        </div>
      )}

      <div className="flex flex-col gap-2">{children}</div>

      {(caption || helpers.length > 0) && (
        <figcaption className="flex flex-col gap-1 text-sm text-fd-muted-foreground">
          {caption && <span>{caption}</span>}
          {helpers.length > 0 && (
            <span>
              {helpers.map((name, index) => (
                <span key={name}>
                  {index > 0 && (index === helpers.length - 1 ? " and " : ", ")}
                  <code className="rounded bg-fd-muted px-1 py-0.5 font-mono text-xs">{name}</code>
                </span>
              ))}
              {helpers.length === 1 ? " is a shorthand" : " are shorthands"} these docs define, not part of the package
              — see{" "}
              <Link href="/rendering" className="text-fd-foreground underline decoration-fd-border underline-offset-2">
                Rendering fields
              </Link>{" "}
              for the widget code an app writes.
            </span>
          )}
        </figcaption>
      )}
    </figure>
  )
}
