/*
 * AI-Provenance:
 *   model: Cursor Grok 4.6
 *   harness: Cursor
 *   skills:
 *     - mark-ai-provenance
 */
import defaultMdxComponents from "fumadocs-ui/mdx"
import type { MDXComponents } from "mdx/types"
import type { ImgHTMLAttributes } from "react"
import { cn } from "@/lib/cn"

function toPixel(value: ImgHTMLAttributes<HTMLImageElement>["width"]): number | undefined {
  if (value == null || value === "") return undefined
  const n = typeof value === "number" ? value : Number(value)
  if (!Number.isFinite(n)) return undefined
  return Math.max(1, Math.round(n))
}

function DocsImage({ className, width, height, ...props }: ImgHTMLAttributes<HTMLImageElement>) {
  return <img {...props} width={toPixel(width)} height={toPixel(height)} className={cn("rounded-lg", className)} />
}

export function getMDXComponents(components?: MDXComponents) {
  return {
    ...defaultMdxComponents,
    img: DocsImage,
    ...components,
  } satisfies MDXComponents
}

export const useMDXComponents = getMDXComponents

declare global {
  type MDXProvidedComponents = ReturnType<typeof getMDXComponents>
}
