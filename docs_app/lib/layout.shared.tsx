/*
 * AI-Provenance:
 *   model: Cursor Grok 4.6
 *   harness: Cursor
 *   skills:
 *     - mark-ai-provenance
 */
import type { DocsLayoutProps } from "fumadocs-ui/layouts/notebook"
import { appName, gitConfig } from "./shared"

export function baseOptions(): Partial<DocsLayoutProps> {
  return {
    nav: {
      title: appName,
      mode: "top",
    },
    githubUrl: `https://github.com/${gitConfig.user}/${gitConfig.repo}`,
  }
}
