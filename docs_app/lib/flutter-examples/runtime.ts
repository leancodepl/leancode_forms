/*
 * AI-Provenance:
 *   model: Claude Opus 5
 *   harness: Cursor
 */
"use client"

/**
 * One Flutter engine per page, shared by every island on it.
 *
 * Multiple Flutter *engines* on one page are not supported and never will be —
 * they fight over globals on `window`. Multi-view embedding is the supported
 * shape: a single engine that renders into any number of host elements, added
 * and removed at runtime. This module owns that engine and hands out views.
 */

/** Where `flutter build web -o` puts the bundle, relative to the site root. */
const bundleBase = "/flutter-examples/"

/**
 * Each view gets its own rendering surface, and therefore its own WebGL
 * context; browsers stop handing those out somewhere around 16. Capping well
 * below that leaves room for everything else on the page.
 */
const maxAttachedViews = 4

interface ViewConstraints {
  minWidth?: number
  maxWidth?: number
  minHeight?: number
  maxHeight?: number
}

interface FlutterApp {
  addView(options: { hostElement: Element; initialData?: unknown; viewConstraints?: ViewConstraints }): number
  removeView(viewId: number): void
}

declare global {
  interface Window {
    __advancedFormsIslands?: Promise<FlutterApp>
    __advancedFormsIslandsConfig?: { assetBase?: string }
  }
}

let engine: Promise<FlutterApp> | undefined

function loadEngine(): Promise<FlutterApp> {
  engine ??= new Promise<FlutterApp>((resolve, reject) => {
    // The loader resolves asset URLs against `document.baseURI`, and a Next.js
    // page has no <base> tag, so the bundle location has to be spelled out.
    window.__advancedFormsIslandsConfig = { assetBase: bundleBase }

    const script = document.createElement("script")
    script.src = `${bundleBase}flutter_bootstrap.js`
    script.async = true

    script.addEventListener("load", () => {
      const app = window.__advancedFormsIslands
      if (app) app.then(resolve, reject)
      else reject(new Error("flutter_bootstrap.js did not publish window.__advancedFormsIslands"))
    })
    script.addEventListener("error", () => {
      reject(new Error(`Could not load ${bundleBase}flutter_bootstrap.js — run \`npm run examples:build\`.`))
    })

    document.head.append(script)
  })

  return engine
}

export interface IslandRequest {
  host: HTMLElement
  exampleId: string
  /** Omit for a fixed-height island: the engine then measures the host. */
  viewConstraints?: ViewConstraints
  /** Whether this island is on or near the screen, asked when making room. */
  isVisible: () => boolean
  /** Called when the view is torn down to make room for another island. */
  onEvicted: () => void
}

export interface AttachedIsland {
  detach(): void
}

interface Entry {
  viewId: number
  request: IslandRequest
  detached: boolean
}

/** Attached views, oldest first. */
const attached: Entry[] = []

let queue: Promise<unknown> = Promise.resolve()

const nextFrame = () => new Promise<void>(resolve => requestAnimationFrame(() => resolve()))

function detach(entry: Entry, evicted = false) {
  if (entry.detached) return
  entry.detached = true

  const index = attached.indexOf(entry)
  if (index !== -1) attached.splice(index, 1)

  void loadEngine().then(app => app.removeView(entry.viewId))
  if (evicted) entry.request.onEvicted()
}

/** Drops off-screen views before adding one, preferring to keep what is visible. */
function makeRoom() {
  while (attached.length >= maxAttachedViews) {
    detach(attached.find(entry => !entry.request.isVisible()) ?? attached[0], true)
  }
}

/**
 * Adds one view, serialized against every other island on the page.
 *
 * The serialization is deliberate: views that first lay out in the same frame
 * can end up sharing a size (flutter/flutter#185034), so each one is given a
 * couple of frames to settle before the next is added.
 */
export function attachIsland(request: IslandRequest): Promise<AttachedIsland> {
  const attach = async (): Promise<AttachedIsland> => {
    const app = await loadEngine()
    makeRoom()

    const entry: Entry = {
      viewId: app.addView({
        hostElement: request.host,
        initialData: { exampleId: request.exampleId },
        viewConstraints: request.viewConstraints,
      }),
      request,
      detached: false,
    }
    attached.push(entry)

    await nextFrame()
    await nextFrame()

    return { detach: () => detach(entry) }
  }

  const result = queue.then(attach, attach)
  queue = result.catch(() => undefined)
  return result
}

/** Vertical constraints that let the island size itself to its content. */
export const autoHeightConstraints: ViewConstraints = { minHeight: 0, maxHeight: Infinity }
