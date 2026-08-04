# Migrating from 0.1.x to 0.2.0

You have an app full of forms built on `leancode_forms` 0.1.x and you're wondering how much of your week this upgrade will eat. Short answer: for most codebases it's an afternoon, and most of that is search-and-replace.

The headline: **0.2.0 keeps the form-building model you already know** — fields, form groups, validators, subforms — and swaps the machinery underneath:

- `flutter_bloc` and `rxdart` are gone from the dependency tree. Everything runs on `ValueNotifier`/`ChangeNotifier`, straight from the Flutter SDK — so this library no longer dictates your state-management stack. Use bloc, provider, riverpod, or nothing at all; your forms won't care.
- Every `*Cubit` class is now an `Advanced*Controller` (e.g. `FieldCubit` → `AdvancedFieldController`). Same methods, same behavior, different name.
- Lifecycle is synchronous: `dispose()` instead of `Future<void> close()`.
- `AdvancedTextFieldController` now owns its `TextEditingController` and keeps it in sync with the field value — which kills a whole family of "the text on screen doesn't match the field" bugs you used to have to handle in widget code.

The whole migration, as a checklist:

1. Search-and-replace the class names ([section 1](#1-rename-reference) has the full table).
2. Replace `.state` reads with `.value` / `fieldValue` ([section 2](#2-migrating-your-form-classes)).
3. Add `, _` to your `FieldBuilder` builders ([section 3](#3-migrating-your-widgets--fieldbuilder-becomes-advancedfieldbuilder)).
4. Turn `close()` overrides into `dispose()` ([section 4](#4-lifecycle-close--dispose)).
5. Delete the `TextEditingController` plumbing from text widgets — the field owns it now ([section 5](#5-advancedtextfieldcontroller-now-owns-its-texteditingcontroller)).
6. Swap form-level stream subscriptions for listeners ([section 6](#6-advancedformcontroller-exposes-listenables-not-streams)).
7. If you had custom cubit-stream patterns, wire them to their named replacements ([section 9](#9-migrating-a-rich-custom-field)).

Steps 1–4 are mechanical; 5 deletes code; 6 and 7 usually touch a handful of files. Everything not on this list didn't change ([section 7](#7-what-didnt-change) is the reassurance checklist).

Below is each step in detail, roughly in the order you'll hit it.

---

## 1. Rename reference

Start here — for most files, this table *is* the migration:

| 0.1.x | 0.2.0 |
| --- | --- |
| `FieldCubit<T, E>` | `AdvancedFieldController<T, E>` |
| `TextFieldCubit<E>` | `AdvancedTextFieldController<E>` |
| `BooleanFieldCubit<E>` | `AdvancedBooleanFieldController<E>` |
| `SingleSelectFieldCubit<V, E>` | `AdvancedSingleSelectFieldController<V, E>` |
| `MultiSelectFieldCubit<V, E>` | `AdvancedMultiSelectFieldController<V, E>` |
| `FormGroupCubit` | `AdvancedFormController` |
| `FieldBuilder<T, E>` | `AdvancedFieldBuilder<T, E>` — now a wrapper around `ValueListenableBuilder`; `field:` re-typed to `AdvancedFieldController<T, E>`, `builder` gains a third `child` param |
| `form.onValuesChangedStream` (`Stream<void>`) | `form.onValuesChanged` (`Listenable`) |
| `form.onStatusChangedStream` (`Stream<FieldStatus>`) | `form.onStatusChanged` (`Listenable`) |
| `Future<void> close()` | `void dispose()` |

And in your `pubspec.yaml`:

- You can **drop `flutter_bloc` and `rxdart`** — unless something else in your app still needs them, of course.
- If your tests or DI used **`bloc_test`, `bloc_presentation`, or `flutter_hooks`** just for forms, those can go too. **Add `provider`** if you want a drop-in replacement for `BlocProvider`/`context.read` (see [section 8](#8-migrating-exampletest-code-that-used-flutter_bloc-directly)).

---

## 2. Migrating your form classes

Your form classes — the ones declaring fields and calling `registerFields` — migrate with a class rename and nothing else. Compare:

**0.1.x:**
```dart
class SimpleFormCubit extends FormGroupCubit {
  SimpleFormCubit() {
    registerFields([firstName, lastName, email]);
  }

  final firstName = TextFieldCubit(
    initialValue: 'John',
    validator: filled(ValidationError.empty),
  );
  final lastName = TextFieldCubit(initialValue: 'Foo');
  final email = TextFieldCubit(
    validator: filled(ValidationError.empty),
    asyncValidator: _onEmailChanged,
  );

  Future<ValidationError?> _onEmailChanged(String value) async { /* ... */ }
}
```

**0.2.0:**
```dart
class SimpleFormController extends AdvancedFormController {
  SimpleFormController() {
    registerFields([firstName, lastName, email]);
  }

  final firstName = AdvancedTextFieldController(
    initialValue: 'John',
    validator: filled(ValidationError.empty),
  );
  final lastName = AdvancedTextFieldController(initialValue: 'Foo');
  final email = AdvancedTextFieldController(
    validator: filled(ValidationError.empty),
    asyncValidator: _onEmailChanged,
  );

  Future<ValidationError?> _onEmailChanged(String value) async { /* ... */ }
}
```

The one thing you'll actually have to touch by hand: reading the current state. The bloc-era `.state` getter is gone; state lives under `.value` now, because that's what `ValueListenable` calls it:

```dart
// 0.1.x:
controller.firstName.state.value;

// 0.2.0:
controller.firstName.value.value;

// or, nicer:
controller.firstName.fieldValue;
```

Yes, `value.value` looks silly — that's why `fieldValue` exists as a shortcut to the inner value (and `error` for the current error). Prefer those in anything you write by hand.

> **Why the rebuild at all?** `ValueNotifier` is a synchronous state container: assign a new value and listeners run right there, in the same call stack — no broadcast stream, no microtask hop, nothing to await in tests. Your forms behave the same; there's just far less machinery between "value changed" and "widget rebuilt".

---

## 3. Migrating your widgets — `FieldBuilder` becomes `AdvancedFieldBuilder`

Good news first: your widget code barely changes. `FieldBuilder` lives on as `AdvancedFieldBuilder` — now a thin wrapper around the SDK's `ValueListenableBuilder` instead of `flutter_bloc`'s `BlocBuilder`. Beyond the rename, two small differences:

- The `field:` parameter's static type went from `FieldCubit<T, E>` to `AdvancedFieldController<T, E>` — your specialized field types (`AdvancedTextFieldController`, etc.) satisfy that automatically.
- The `builder` callback gained a third parameter, `child` (it's a `ValueWidgetBuilder` now). Add a `, _` to each builder's parameter list and you're done — or actually use it, see below.

```dart
// 0.1.x:
FieldBuilder<String, MyError>(
  field: controller.email,
  builder: (context, state) => Text(state.value),
)

// 0.2.0 — note the extra builder parameter:
AdvancedFieldBuilder<String, MyError>(
  field: controller.email,
  builder: (context, state, _) => Text(state.value),
)
```

That third parameter is the `child:` optimization for expensive static subtrees, which `BlocBuilder` never gave you — pass a subtree that doesn't depend on the field state and it's built once, then reused across rebuilds:

```dart
AdvancedFieldBuilder<String, MyError>(
  field: controller.email,
  child: const ExpensiveStaticIcon(),
  builder: (context, state, child) => Row(
    children: [child!, Text(state.value)],
  ),
)
```

And because fields are plain `ValueListenable`s now, you can also skip the wrapper entirely and use the SDK's `ValueListenableBuilder` — same thing, just with the `<AdvancedFieldState<String, MyError>>` type argument spelled out.

> **Why keep the builder at all if the SDK has an equivalent?** So your existing widget code compiles after a rename instead of a rewrite — and so you don't have to spell out `<AdvancedFieldState<T, E>>` at every call site. Pure convenience, kept deliberately.

---

## 4. Lifecycle: `close()` → `dispose()`

Cleanup code gets shorter — the `async` ceremony around closing cubits is gone:

**0.1.x:**
```dart
@override
Future<void> close() async {
  await field.close();
  return super.close();
}
```

**0.2.0:**
```dart
@override
void dispose() {
  field.dispose();
  super.dispose();
}
```

> **Why was `close()` async in the first place?** Because it closed a broadcast `StreamController` under the hood. `ChangeNotifier.dispose()` just clears a listener list — nothing to await, in the library or in your code.

### One thing to actually watch out for

`dispose()` is not idempotent: call it twice on a notifier in debug mode throws `'A ValueNotifier was used after being disposed'`. The old `Cubit.close()` silently tolerated a re-close — so if your 0.1.x code disposed a field by hand *and* let `FormGroupCubit.close()` dispose it again, that worked purely by accident, and 0.2.0 will call you out on it.

The fix is to pick one owner, and the easy pick is the form:

- Register fields with `registerFields(...)` and let `AdvancedFormController` dispose them. Don't call `dispose()` on registered fields yourself.
- Registering the same field twice (multi-`registerFields` patterns) is fine — ownership is tracked with a `Set`, so each field is disposed exactly once.

---

## 5. `AdvancedTextFieldController` now owns its `TextEditingController`

This is the change you'll be happiest about. In 0.1.x, every text widget had to allocate its own `TextEditingController`, seed it from `field.state.value`, and wire `onChanged: field.setValue` back the other way. And that setup had a hole in it: programmatic changes — `field.reset()`, `field.setValue('foo')`, one field updating another — never reached the screen, because the widget's controller was seeded once and then lived its own life. If you've ever had a "Reset" button that cleared the state but not the text boxes, this was why.

**0.1.x widget code:**
```dart
final c = useTextEditingController(text: field.state.value);
TextField(
  controller: c,
  onChanged: field.setValue,
);
```

**0.2.0 widget code:**
```dart
TextField(
  controller: field.textController,
);
```

That's the whole widget. No `useTextEditingController`, no `useEffect`, no `onChanged` callback. The field allocates the `TextEditingController` itself, keeps the two in sync in both directions, and disposes everything in `dispose()`.

Migrating a custom text widget is deleting code:

1. Delete the `useTextEditingController` (or manually-allocated `TextEditingController`).
2. Delete the `initialValue: state.value` and `onChanged: field.setValue` plumbing.
3. Pass `controller: field.textController` to the underlying `TextField`/`TextFormField`.

> **Why this works now.** `TextEditingController` is itself a `ValueNotifier<TextEditingValue>` — the same primitive the field is built on. Having both the widget and the field hold their own copy of the string was the root cause of cursor jumps and "reset doesn't reset" bugs. Now there's one source of truth, owned at the field level where it belongs.

---

## 6. `AdvancedFormController` exposes `Listenable`s, not `Stream`s

If you listened to form-level changes, the swap is mechanical — subscription objects become listener callbacks:

**0.1.x:**
```dart
final sub = form.onValuesChangedStream.listen((_) => doSomething());
// ...
await sub.cancel();
```

**0.2.0:**
```dart
form.onValuesChanged.addListener(doSomething);
// ...
form.onValuesChanged.removeListener(doSomething);
```

Same swap for `onStatusChanged` (was `onStatusChangedStream`).

One practical note: where you used to cancel a `StreamSubscription` in `dispose`, you now call `removeListener` with the same callback you added — which means the listener can't be an inline closure. Give it a name.

> **Why this changed.** The old implementation kept two broadcast `StreamController`s inside `FormGroupCubit` and had to `Rx.merge` them back together every time a field or subform was added. That's a lot of moving parts for "tell me when something changed". The new implementation is per-field listeners with a couple of cached values — you can read it top to bottom in the source and actually follow it. The cost is this rename at your call sites.

---

## 7. What didn't change

Everything not listed above — which is most of the library. This is the part that makes the migration an afternoon instead of a rewrite. If your code only touches these surfaces, "rename `*Cubit` to `Advanced*Controller`" is the entire job:

- **Validators.** The `Validator<T, E>` / `AsyncValidator<T, E>` typedefs are unchanged, and every ready-to-use validator (`filled`, `atLeastLength`, `notLongerThan`, `notNull`, `notEmpty`, `or`, `and`, `&`, `|`, …) keeps its name and signature. Your custom validators compile as-is.
- **Field methods.** `setValue`, `validate`, `setAutovalidate`, `markReadOnly`, `unmarkReadOnly`, `clearErrors`, `reset`, `setError`, `getValueSetter`, `subscribeToFields` — all still there, all behaving the same.
- **Form-group methods.** `registerFields`, `addSubform`, `removeSubform`, `setValidationEnabled`, `validateWithAutovalidate`, `resetAll`, `markReadOnly`, `clearErrors` — same story.
- **Async validation.** The `pending` → `validating` → `valid`/`invalid` sequence, the debounce timer, cancel-on-new-value — bit-for-bit identical. If you tuned debounce timings, they still mean what they meant.
- **`wasModified` / `validating` aggregate flags.** Tracked the same way, with `DeepCollectionEquality` still the baseline for "did the value actually change".
- **`subscribeToFields`.** Still filters out status-only changes so your dependent fields don't revalidate for nothing. The implementation moved from `Rx.combineLatest + distinct` to a plain cache, but you can't tell from the outside.

---

## 8. Migrating example/test code that used `flutter_bloc` directly

If `BlocProvider` was how the form controller got into your widget tree, you have two options — and neither is a redesign.

### Option A — switch to `provider`

`ChangeNotifierProvider` is a near-drop-in replacement, and `context.read` / `context.watch` / `context.select` keep working exactly as before:

```dart
// 0.1.x
BlocProvider<SimpleFormCubit>(
  create: (_) => SimpleFormCubit(),
  child: const SimpleForm(),
)

// 0.2.0 with `provider`
ChangeNotifierProvider<SimpleFormController>(
  create: (_) => SimpleFormController(),
  child: const SimpleForm(),
)
```

### Option B — plain Flutter, no DI dep

Since controllers are plain `ChangeNotifier`s now, you don't strictly need a DI package at all. Hoist the controller into a `StatefulWidget` and pass it down through constructor args — a bit more typing per screen, zero dependencies:

```dart
class SimpleFormScreen extends StatefulWidget {
  const SimpleFormScreen({super.key});
  @override
  State<SimpleFormScreen> createState() => _SimpleFormScreenState();
}

class _SimpleFormScreenState extends State<SimpleFormScreen> {
  late final controller = SimpleFormController();
  @override
  void dispose() { controller.dispose(); super.dispose(); }
  @override
  Widget build(_) => SimpleForm(controller: controller);
}
```

### Other example-side deps

- **`bloc_test`** — you won't miss it. Since notifiers are synchronous, a form test is a plain `test(...)` block with no `blocTest` DSL, no `wait:`, no async choreography. To assert a sequence of states, collect them with a listener:

  ```dart
  final emissions = <AdvancedFieldState<int, MyError>>[];
  field.addListener(() => emissions.add(field.value));
  field.setValue(10);
  expect(emissions, [const AdvancedFieldState(value: 10)]);
  ```

- **`bloc_presentation`** (the "submit failed → fire a one-off UI event" pattern) has no direct equivalent, but the pattern is a one-liner without it: expose a plain `Stream` from your controller. The example app does exactly this — see `example/lib/screens/scroll_form.dart`.
- **`flutter_hooks`** — if `useTextEditingController` / `useFocusNode` were the only reason you had it, you can drop it. `AdvancedTextFieldController` owns both now (see [section 5](#5-advancedtextfieldcontroller-now-owns-its-texteditingcontroller)).

---

## 9. Migrating a rich custom field

If you've been using this library for a while, you probably have a folder full of custom fields: `FieldCubit` subclasses with a business-typed value (a `Decimal`, a record, a DTO, basically not a raw string), their own error types, and a couple of domain methods. That's the intended way to use the library, and it's usually the part people worry about most before migrating: "do I have to rewrite 30 of these?"

You don't. Your field logic doesn't care whether it sits on a cubit or a `ChangeNotifier` — validators, error hierarchies, and domain methods carry over as-is. The migration is a rename plus one accessor change, and it's the same two edits in every file, so it's easy to knock out mechanically.

Here's a realistic field, before and after. It holds an amount paired with a unit, validates against min/max bounds that are recomputed on every pass (so they can depend on other app state), and accepts validation errors coming back from the server.

**OLD**

```dart
typedef QuantityFieldValue = ({String unit, num? amount});

sealed class QuantityFieldError {
  const QuantityFieldError();
}

final class QuantityNotFilledError extends QuantityFieldError {
  const QuantityNotFilledError();
}

final class QuantityBelowMinError extends QuantityFieldError {
  const QuantityBelowMinError({required this.min, required this.unit});
  final num min;
  final String unit;
}

final class QuantityBackendError extends QuantityFieldError {
  const QuantityBackendError(this.message);
  final String message;
}

typedef QuantityBounds = ({num min, num max});

class QuantityFieldCubit
    extends FieldCubit<QuantityFieldValue, QuantityFieldError> {
  QuantityFieldCubit({
    String initialUnit = 'kg',
    num? initialAmount,
    QuantityBounds? Function()? bounds,
  }) : super(
          initialValue: (unit: initialUnit, amount: initialAmount),
          // Recomputed on every validation pass, so the bound can react
          // to upstream state (e.g. the currently selected product).
          validator: (value) => _validate(value, bounds?.call()),
        );

  static QuantityFieldError? _validate(
    QuantityFieldValue value,
    QuantityBounds? bounds,
  ) {
    final amount = value.amount;
    if (amount == null) {
      return const QuantityNotFilledError();
    }
    if (bounds != null && amount < bounds.min) {
      return QuantityBelowMinError(min: bounds.min, unit: value.unit);
    }
    return null;
  }

  /// Replaces the numeric component while keeping the current unit.
  void setAmount(num? amount) =>
      setValue((unit: state.value.unit, amount: amount));

  /// Pushes a server-side validation error into the field.
  void setBackendError(String message) =>
      setError(QuantityBackendError(message));

  /// Clears a backend error by re-running the local validator.
  void clearBackendError() {
    if (state.validationError is QuantityBackendError) {
      validate();
    }
  }
}
```

**NEW** — same value type, same errors, same bounds callback, same methods. Two things change:

1. The base class: `FieldCubit` → `AdvancedFieldController` (and you'll probably rename your own class `*Cubit` → `*Controller` while you're at it).
2. How you read the current state: `state.value` → `fieldValue`, `state.validationError` → `value.validationError`.

That's the whole diff:

```dart
class QuantityFieldController
    extends AdvancedFieldController<QuantityFieldValue, QuantityFieldError> {
  QuantityFieldController({
    String initialUnit = 'kg',
    num? initialAmount,
    QuantityBounds? Function()? bounds,
    super.name, // optional: shows up in logs and FocusNode debugLabels
  }) : super(
          initialValue: (unit: initialUnit, amount: initialAmount),
          validator: (value) => _validate(value, bounds?.call()),
        );

  static QuantityFieldError? _validate(
    QuantityFieldValue value,
    QuantityBounds? bounds,
  ) {
    final amount = value.amount;
    if (amount == null) {
      return const QuantityNotFilledError();
    }
    if (bounds != null && amount < bounds.min) {
      return QuantityBelowMinError(min: bounds.min, unit: value.unit);
    }
    return null;
  }

  /// Replaces the numeric component while keeping the current unit.
  void setAmount(num? amount) =>
      setValue((unit: fieldValue.unit, amount: amount));

  /// Pushes a server-side validation error into the field.
  void setBackendError(String message) =>
      setError(QuantityBackendError(message));

  /// Clears a backend error by re-running the local validator.
  void clearBackendError() {
    if (value.validationError is QuantityBackendError) {
      validate();
    }
  }
}
```

A few things worth knowing while you do this:

- **You won't get extra rebuilds after the migration.** Previously, `Equatable` made sure that emitting an identical state didn't notify anyone. The new `AdvancedFieldState` does the same through its `operator ==`, and Dart records compare by content — so calling `setValue` with an unchanged record is still a no-op for your listeners. No behavioral surprises hiding here.
- **`fieldValue` exists so you don't have to write `value.value.unit`.** With a record-valued field, the "official" path to a component is state → record → component, which stacks up as `value.value.unit`. `fieldValue.unit` reads like `state.value.unit` used to. Same deal with `error` vs `value.error`. Small thing, but you'll hit it in every method of every custom field, so it's worth adopting from the start.
- **`name` is new and optional.** Give a field a name and it shows up in logs and `FocusNode` debug labels, which helps when you're staring at a form with fifteen fields and one of them misbehaves. Skip it if you don't need it — it changes nothing about behavior.

### "But I listened to cubit streams"

The old cubits exposed a `stream`, and if your project is anything like ours, you built listening patterns on top of it. Notifiers don't have streams — here's where each pattern goes, starting with the most common:

- **Field B revalidates when field A changes** — `subscribeToFields([fieldA])`, exactly like in old version. Nothing to migrate.
- **Do something when part of a field's value changes** — say, refresh the price when the selected product changes. If you had a `select`/`listen` extension on `FieldCubit` for this (many projects did), `onValueChange` is its drop-in replacement:

  ```dart
  final cleanup = productField.onValueChange(
    (value) => value.productId,
    (productId) => priceField.refreshFor(productId),
  );
  // Later, e.g. in dispose():
  cleanup();
  ```

- **Code that genuinely composes streams** — rxdart operators, `await for`, merging fields into a pipeline. You don't have to rewrite it today: bridge the field with `stream` and move on.

  ```dart
  quantityField.stream
      .map((state) => state.value.amount)
      .listen(recalculateTotals);
  ```

  Treat the bridge as harness, not architecture: it exists so a big migration doesn't stall on its hairiest corner, and the plan is to deprecate it once everyone's across. New code should use `addListener`, `subscribeToFields`, or the builders — they cover everything streams did here, without the extra moving parts.

---

## Reference

Stuck on something this guide doesn't cover?

- [`README.md`](./README.md) documents the new architecture from scratch — useful when you'd rather understand the model than pattern-match the diff.
- [`CHANGELOG.md`](./CHANGELOG.md) has the terse, complete breaking-change list under the 0.2.0 entry.
- The `example/` app shows every pattern in its migrated shape — when in doubt, crib from there.