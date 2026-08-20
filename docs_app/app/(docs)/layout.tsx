/*
 * AI-Provenance:
 *   model: Cursor Grok 4.6
 *   harness: Cursor
 *   skills:
 *     - mark-ai-provenance
 */
import { source } from "@/lib/source"
import { DocsLayout } from "fumadocs-ui/layouts/notebook"
import { baseOptions } from "@/lib/layout.shared"
import type { LayoutTab } from "fumadocs-ui/layouts/shared"

export default function Layout({ children }: LayoutProps<"/">) {
  const documentationUrls = new Set(
    source
      .getPages()
      .map(page => page.url)
      .filter(url => url !== "/" && url !== "/agent-skill"),
  )
  const tabs: LayoutTab[] = [
    {
      title: "Overview",
      url: "/",
      urls: new Set(["/"]),
    },
    {
      title: "Documentation",
      url: "/installation",
      urls: documentationUrls,
    },
    {
      title: "Agent Skill",
      url: "/agent-skill",
      urls: new Set(["/agent-skill"]),
    },
    {
      title: "Contact Us",
      url: "https://leancode.co/get-estimate",
      urls: new Set(),
      props: {
        target: "_blank",
        rel: "noreferrer",
      },
    },
  ]

  return (
    <DocsLayout tree={source.getPageTree()} tabMode="navbar" tabs={tabs} {...baseOptions()}>
      {children}
    </DocsLayout>
  )
}
