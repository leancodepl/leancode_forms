/*
 * AI-Provenance:
 *   model: Claude Opus 5
 *   harness: Cursor
 */
"use client"

import { useEffect, useRef, useState, type ReactNode } from "react"
import { attachIsland, autoHeightConstraints, type AttachedIsland } from "@/lib/flutter-examples/runtime"
import { cn } from "@/lib/cn"

type Status = "waiting" | "attaching" | "ready" | "evicted" | "failed"

interface FlutterIslandProps {
  exampleId: string
  /** The widget the island mounts, used for the accessible name. */
  preview: string
  /** Fixed height in pixels. Omit to let the island size itself. */
  height?: number
}

/**
 * One live Flutter view, embedded in the page.
 *
 * Attaches when it comes near the viewport and stays attached afterwards, so
 * scrolling past an example and back does not wipe what the reader typed. The
 * shared runtime evicts the least useful view if a page has more islands than
 * the browser will give rendering surfaces for.
 */
export function FlutterIsland({ exampleId, preview, height }: FlutterIslandProps) {
  const hostRef = useRef<HTMLDivElement>(null)
  const visibleRef = useRef(false)
  const [near, setNear] = useState(false)
  const [attempt, setAttempt] = useState(0)
  const [status, setStatus] = useState<Status>("waiting")
  const [error, setError] = useState<string>()

  // Touch devices need an explicit gate: the engine sets `touch-action: none`
  // on its view root, so an un-gated island swallows the scroll gesture
  // (flutter/flutter#157435).
  const [needsActivation, setNeedsActivation] = useState(false)
  const [activated, setActivated] = useState(false)

  useEffect(() => {
    setNeedsActivation(window.matchMedia("(hover: none) and (pointer: coarse)").matches)
  }, [])

  useEffect(() => {
    const host = hostRef.current
    if (!host) return

    const observer = new IntersectionObserver(
      entries => {
        for (const entry of entries) {
          visibleRef.current = entry.isIntersecting
          if (entry.isIntersecting) setNear(true)
        }
      },
      // Start loading before the reader arrives, but only for examples they are
      // actually heading towards.
      { rootMargin: "400px 0px" },
    )
    observer.observe(host)
    return () => observer.disconnect()
  }, [])

  useEffect(() => {
    const host = hostRef.current
    if (!near || !host) return

    let cancelled = false
    let island: AttachedIsland | undefined
    setStatus("attaching")

    attachIsland({
      host,
      exampleId,
      viewConstraints: height === undefined ? autoHeightConstraints : undefined,
      isVisible: () => visibleRef.current,
      onEvicted: () => {
        if (!cancelled) setStatus("evicted")
      },
    }).then(
      attachedIsland => {
        // In development React mounts effects twice; this can resolve after the
        // cleanup below has run, and the view must not be left behind.
        if (cancelled) attachedIsland.detach()
        else {
          island = attachedIsland
          setStatus("ready")
        }
      },
      (reason: unknown) => {
        if (cancelled) return
        setError(reason instanceof Error ? reason.message : String(reason))
        setStatus("failed")
      },
    )

    return () => {
      cancelled = true
      island?.detach()
    }
  }, [near, attempt, exampleId, height])

  const settled = status === "ready"

  return (
    <div
      role="group"
      aria-label={`Live example: ${preview}`}
      className={cn("relative overflow-hidden rounded-lg border border-fd-border bg-fd-card", !settled && "min-h-32")}>
      <div
        ref={hostRef}
        style={{
          height,
          // While the gate is closed the island must not see pointer events at
          // all, or the browser will not treat a swipe as page scrolling.
          pointerEvents: needsActivation && !activated ? "none" : undefined,
        }}
        className="block w-full"
      />

      {status === "attaching" && <Notice>Loading the live example…</Notice>}

      {status === "failed" && (
        <Notice>
          <span className="font-medium">The live example could not be loaded.</span> The code below is what it would
          run.
          {error && <span className="mt-1 block font-mono text-[0.7rem] opacity-70">{error}</span>}
        </Notice>
      )}

      {status === "evicted" && (
        <Notice>
          Unloaded to stay within the browser&rsquo;s rendering budget.
          <button
            type="button"
            onClick={() => setAttempt(n => n + 1)}
            className="mx-auto mt-2 block rounded-md bg-fd-primary px-3 py-1 text-fd-primary-foreground">
            Load it again
          </button>
        </Notice>
      )}

      {needsActivation && !activated && settled && (
        <button
          type="button"
          onClick={() => setActivated(true)}
          className="absolute inset-0 flex items-center justify-center bg-fd-card/60 backdrop-blur-[1px]">
          <span className="rounded-full bg-fd-primary px-4 py-1.5 text-sm font-medium text-fd-primary-foreground">
            Try it
          </span>
        </button>
      )}

      {needsActivation && activated && (
        <button
          type="button"
          onClick={() => setActivated(false)}
          className="absolute top-1 right-1 rounded-md bg-fd-muted px-2 py-0.5 text-xs text-fd-muted-foreground">
          Done
        </button>
      )}
    </div>
  )
}

function Notice({ children }: { children: ReactNode }) {
  return (
    <div className="absolute inset-0 flex items-center justify-center p-4 text-center text-xs text-fd-muted-foreground">
      <p>{children}</p>
    </div>
  )
}
