/*
 * AI-Provenance:
 *   model: Cursor Grok 4.6
 *   harness: Cursor
 *   skills:
 *     - mark-ai-provenance
 */
import { NextRequest, NextResponse } from "next/server"
import { isMarkdownPreferred, rewritePath } from "fumadocs-core/negotiation"
import { docsContentRoute } from "@/lib/shared"

const skipPrefixes = ["/api", "/og", "/llms"]

const { rewrite: rewriteDocs } = rewritePath(`/{/*path}`, `${docsContentRoute}{/*path}/content.md`)
const { rewrite: rewriteSuffix } = rewritePath(`/{/*path}.md`, `${docsContentRoute}{/*path}/content.md`)

function shouldSkip(pathname: string) {
  return skipPrefixes.some(
    prefix => pathname === prefix || pathname.startsWith(`${prefix}/`) || pathname.startsWith(`${prefix}.`),
  )
}

export default function proxy(request: NextRequest) {
  if (shouldSkip(request.nextUrl.pathname)) {
    return NextResponse.next()
  }

  const result = rewriteSuffix(request.nextUrl.pathname)
  if (result) {
    return NextResponse.rewrite(new URL(result, request.nextUrl))
  }

  if (isMarkdownPreferred(request)) {
    const rewritten = rewriteDocs(request.nextUrl.pathname)

    if (rewritten) {
      return NextResponse.rewrite(new URL(rewritten, request.nextUrl), {
        headers: { Vary: "Accept" },
      })
    }
  }

  return NextResponse.next()
}
