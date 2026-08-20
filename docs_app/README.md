<!--
AI-Provenance:
  model: Cursor Grok 4.6
  harness: Cursor
  skills:
    - mark-ai-provenance
-->

# advanced-forms-docs

This is a Next.js application generated with [Create Fumadocs](https://github.com/fuma-nama/fumadocs).

MDX lives in the repo-root `docs/` folder. From this directory:

```bash
npm run dev
```

Open http://localhost:3000 to view the docs (notebook layout, pages served from `/`).

## Live Flutter examples

A page can run the code it shows. Wrap the Dart fences in `<AdvancedFormsExample>` and the snippet is compiled into a
real Flutter app at build time, then rendered above the code:

````mdx
<AdvancedFormsExample preview="SignupForm">
  ```dart
  class SignupForm extends StatefulWidget { ... }
  ```
</AdvancedFormsExample>
````

Every `dart` fence inside the element is concatenated into one file, in document order, so an example may stay split
across the fences the prose needs. The generated file imports `package:flutter/material.dart`,
`package:advanced_forms/advanced_forms.dart` and a docs-only support library, so snippets carry no imports.

- `preview` names the widget to mount. Omit it and the first `class X extends StatelessWidget|StatefulWidget` is used.
  It needs a `const X({super.key})` constructor.
- `height={320}` fixes the island's height. **An auto-height island must not use `Scaffold`**, which takes every pixel
  it is offered; use `height` for `Scaffold` and scrolling demos.
- `isolate` renders the example in an iframe instead of sharing the page's engine. Needs `height`. An escape hatch for
  an example that wants the page to itself.
- `caption` adds a line under the code.
- The `Docs*` widgets from `flutter/lib/support/` keep examples about validation from re-teaching
  `AdvancedFieldBuilder`. Using one makes the component say so on the page, so nobody copies it into an app expecting it
  to exist.

All the islands on a page share **one** Flutter engine, in
[multi-view mode](https://docs.flutter.dev/platform-integration/web/embedding-flutter-web): one download, one warm-up,
and each island is a view attached to its own `<div>` when it scrolls into sight.

### Working on an example

Islands on a page you are reading come from the last `npm run examples:build`; if that never ran they degrade to plain
code blocks with a note. Three loops, in the order you are likely to want them:

**Writing a snippet.** Rebuild the bundle and reload:

```bash
npm run examples:build && npm run dev   # ~25s for the Flutter build
```

**Iterating on an example's Dart, with hot reload.** The Flutter package has a standalone gallery that mounts any single
example by id:

```bash
cd flutter && flutter run -d chrome     # then `r` to hot reload
```

**Live islands inside the real docs page.** Point the docs at the Flutter dev server instead of the built bundle:

```bash
npm run examples:serve                                        # dev server on :5333
FLUTTER_EXAMPLES_DEV_SERVER=http://localhost:5333 npm run dev # docs, proxying it
npm run examples:watch                                        # regenerate Dart as MDX changes
```

Then edit the MDX, press `r` in the Flutter terminal, reload the page. This one needs the
[Dart Debug Extension](https://chromewebstore.google.com/detail/dart-debug-extension/eljbmlghnomdjgdjmbdekegdkbabckhm)
installed in the browser you open the docs in: `flutter run -d web-server` waits for a debugger to attach before it
starts the app, so without the extension the island loads its code and then sits there. The rewrite exists because the
debug asset server sends no CORS headers, unlike the release one.

### How it fits together

| Path                                         | What it does                                                         |
| -------------------------------------------- | -------------------------------------------------------------------- |
| `lib/flutter-examples/extract.mjs`           | Pulls the Dart out of the MDX and hashes it into an example id       |
| `lib/flutter-examples/remark-example-id.ts`  | Stamps that id onto the element the page renders                     |
| `scripts/flutter-examples.mjs`               | `generate` / `check` / `build` / `--watch`                           |
| `lib/flutter-examples/manifest.generated.ts` | Committed id → metadata map, so `next build` can spot a stale bundle |
| `flutter/`                                   | The Flutter package the snippets are compiled into                   |
| `components/flutter-island.tsx`              | Attaches and detaches one view                                       |
| `public/flutter-examples/`                   | Build output, gitignored                                             |

## Deployment

`npm run build` runs `flutter build web`, so **the Flutter SDK has to be present where the site is built**. Vercel's
build container has no Flutter, so `vercel.json` turns its Git integration off and `.github/workflows/docs.yml` builds
and deploys instead, using `vercel deploy --prebuilt`. It needs three repository secrets: `VERCEL_TOKEN`,
`VERCEL_ORG_ID` and `VERCEL_PROJECT_ID`. Without them the deploy job does nothing and the build job still guards every
pull request.

## Explore

- `lib/source.ts`: content source (`defineDocs` points at `../docs`).
- `lib/layout.shared.tsx`: shared notebook layout options.
- `source.config.ts`: global MDX options, including the example-id plugin.

| Route                                                 | Description            |
| ----------------------------------------------------- | ---------------------- |
| `app/(docs)/[[...slug]]`                              | Documentation pages    |
| `app/api/search/route.ts`                             | Search                 |
| `app/llms.txt` / `app/llms-full.txt` / `app/llms.mdx` | LLM markdown endpoints |
| `app/og`                                              | Open Graph images      |
