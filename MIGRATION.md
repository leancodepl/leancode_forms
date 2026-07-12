# Migrating from 0.1.x to 0.2.0

This guide is for anyone upgrading a form built on `leancode_forms` 0.1.x to 0.2.0.

At a high level, **0.2.0 keeps the same form-building model** — `FieldX` + `FormGroup` + validators + subforms — but rebuilds the foundation underneath:

- The library no longer depends on `flutter_bloc` or `rxdart`. Everything runs on `ValueNotifier` / `ChangeNotifier` from the Flutter SDK.
- Every `*Cubit` class is renamed to `*Controller`. The public API on each is otherwise nearly identical.
- Lifecycle is now synchronous (`dispose()` instead of `Future<void> close()`).
- `TextFieldController` now owns a `TextEditingController` and keeps it bidirectionally synced with the field value — killing a class of widget-level bugs.

Most call sites need only a class rename and an import cleanup.

---

## 1. Rename reference

| 0.1.x | 0.2.0 |
| --- | --- |
| `FieldCubit<T, E>` | `FieldController<T, E>` |
| `TextFieldCubit<E>` | `TextFieldController<E>` |
| `BooleanFieldCubit<E>` | `BooleanFieldController<E>` |
| `SingleSelectFieldCubit<V, E>` | `SingleSelectFieldController<V, E>` |
| `MultiSelectFieldCubit<V, E>` | `MultiSelectFieldController<V, E>` |
| `FormGroupCubit` | `FormController` |
| `FieldBuilder<T, E>` | **Kept** — now a wrapper around `ValueListenableBuilder`; `field:` param re-typed to `FieldController<T, E>` |
| `form.onValuesChangedStream` (`Stream<void>`) | `form.onValuesChanged` (`Listenable`) |
| `form.onStatusChangedStream` (`Stream<FieldStatus>`) | `form.onStatusChanged` (`Listenable`) |
| `Future<void> close()` | `void dispose()` |

Dependency changes for your `pubspec.yaml`:

- **Drop:** `flutter_bloc`, `rxdart`
- (Example/test only — not the library itself.) **Drop:** `bloc_test`, `bloc_presentation`, `flutter_hooks` if you used them; **add:** `provider` if you want a drop-in replacement for `BlocProvider` / `context.read`

---

## 2. Migrating your form classes

For most forms, the change is a search-and-replace of class names.

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
class SimpleFormController extends FormController {
  SimpleFormController() {
    registerFields([firstName, lastName, email]);
  }

  final firstName = TextFieldController(
    initialValue: 'John',
    validator: filled(ValidationError.empty),
  );
  final lastName = TextFieldController(initialValue: 'Foo');
  final email = TextFieldController(
    validator: filled(ValidationError.empty),
    asyncValidator: _onEmailChanged,
  );

  Future<ValidationError?> _onEmailChanged(String value) async { /* ... */ }
}
```

Reading the current state goes through `.value` (inherited from `ValueNotifier`):

```dart
// 0.1.x:
controller.firstName.state.value;

// 0.2.0:
controller.firstName.value.value;
```

The bloc-era `.state` getter has been removed — `.value` is the only access path on both `FieldController` and `FormController`.

> **Why the rebuild?** `ValueNotifier` is a synchronous state container: when you assign a new value, listeners run in the same call stack — no broadcast stream, no microtask hop. Same observable behavior in real apps, simpler mental model, no `rxdart` plumbing, and the whole library now sits on Flutter SDK primitives only.

---

## 3. Migrating your widgets — `FieldBuilder` stays

`FieldBuilder` is still here. We re-implemented it as a thin wrapper around the SDK's `ValueListenableBuilder` instead of `flutter_bloc`'s `BlocBuilder`. The constructor and builder signature are unchanged; only the `field:` parameter's static type went from `FieldCubit<T, E>` to `FieldController<T, E>` — and your specialized field types (`TextFieldController`, etc.) automatically satisfy that.

```dart
// Identical in 0.1.x and 0.2.0:
FieldBuilder<String, MyError>(
  field: controller.email,
  builder: (context, state) => Text(state.value),
)
```

If you want the SDK's `child:` optimization for a static subtree, drop down to `ValueListenableBuilder`:

```dart
ValueListenableBuilder<FieldState<String, MyError>>(
  valueListenable: controller.email,
  child: const ExpensiveStaticIcon(),
  builder: (context, state, child) => Row(
    children: [child!, Text(state.value)],
  ),
)
```

> **Why a wrapper, not removal?** Strictly speaking, `FieldBuilder` is now redundant — the SDK ships an equivalent. But keeping the name lets your existing widget code compile after a class rename and saves typing the `<FieldState<T, E>>` argument at every call site. Pure DX sugar.

---

## 4. Lifecycle: `close()` → `dispose()`

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

> **Why synchronous?** `Cubit.close()` returns a `Future` because it closes an underlying broadcast `StreamController`. `ChangeNotifier.dispose()` is synchronous — it just nulls out the listener list. No `await` needed in consumer code.

### Watch out — `dispose()` is not idempotent

Calling `dispose()` twice on a `ValueNotifier`/`ChangeNotifier` throws `'A ValueNotifier was used after being disposed'` in debug mode. The old `Cubit.close()` was idempotent and tolerated re-close silently — so 0.1.x code that disposed a field by hand *and* let `FormGroupCubit.close()` dispose it again worked by accident.

In 0.2.0:

- Let `FormController` own field disposal via `registerFields(...)`. Don't call `dispose()` on owned fields yourself.
- If you registered the same field twice (multi-`registerFields` patterns), it's still safe — the library tracks ownership with a `Set` and disposes each owned controller exactly once.

---

## 5. `TextFieldController` now owns its `TextEditingController`

In 0.1.x, every consumer widget had to own its own `TextEditingController`, seed it from `field.state.value`, and wire `onChanged: field.setValue` back the other way. That setup silently dropped any programmatic changes (`field.reset()`, `field.setValue('foo')`, cross-field updates) — the on-screen text didn't update because the widget's controller had already been seeded once.

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

That's it. The widget no longer needs `useTextEditingController`, `useEffect`, or an `onChanged` callback. `TextFieldController` allocates the `TextEditingController` internally, sets up bidirectional listeners on construction, and disposes everything in `dispose()`.

To migrate a custom text widget:

1. Remove the `useTextEditingController` (or any manually-allocated `TextEditingController`).
2. Remove `initialValue: state.value` and `onChanged: field.setValue` plumbing.
3. Pass `controller: field.textController` to the underlying `TextField`/`TextFormField`.

> **Why this changed.** `TextEditingController` is itself a `ValueNotifier<TextEditingValue>`. Letting both the widget and the field own a copy of the same string was the root cause of cursor jumps and "set-to-initial doesn't reset the text" bugs. Now there's one source of truth, owned at the field level where it belongs.

---

## 6. `FormController` exposes `Listenable`s, not `Stream`s

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

If you used `StreamSubscription` cancellation in `dispose`, replace it with `removeListener` paired to the original named callback. That means you can't use an inline closure for the listener — name it.

> **Why this changed.** The dual broadcast `StreamController`s in `FormGroupCubit` had to be re-merged with `Rx.merge` every time fields or subforms changed. We replaced them with per-field listeners plus closure-captured `lastValue`/`lastStatus` caches: pull-style reads, no rxdart, easier to read in source. The trade-off is the public API switches from `Stream<…>` to `Listenable` — close enough to be a mechanical change at most call sites.

---

## 7. What didn't change

Everything not listed above. Quick reassurance checklist — if your call site only uses these surfaces, the migration is "rename `*Cubit` to `*Controller`" and you're done:

- **Validators:** `Validator<T, E>` / `AsyncValidator<T, E>` typedefs unchanged. All ready-to-use validators (`filled`, `atLeastLength`, `notLongerThan`, `notNull`, `notEmpty`, `or`, `and`, `&`, `|`, etc.) have the same names and signatures.
- **Field methods:** `setValue`, `validate`, `setAutovalidate`, `markReadOnly`, `unmarkReadOnly`, `clearErrors`, `reset`, `setError`, `getValueSetter`, `subscribeToFields` — all unchanged on `FieldController`.
- **Form-group methods:** `registerFields`, `addSubform`, `removeSubform`, `setValidationEnabled`, `validateWithAutovalidate`, `resetAll`, `markReadOnly`, `clearErrors` — all unchanged on `FormController`.
- **Async validation flow:** `pending` → `validating` → `valid`/`invalid` sequence, debounce timer, cancel-on-new-value semantics — bit-for-bit identical.
- **`wasModified` / `validating` aggregate flags:** still tracked the same way. `DeepCollectionEquality` is still the baseline.
- **`subscribeToFields`:** still filters out status-only changes. Implementation switched from `Rx.combineLatest + distinct` to a manual `lastValues` cache; observable behavior is the same.

---

## 8. Migrating example/test code that used `flutter_bloc` directly

If your app uses `flutter_bloc`'s `BlocProvider` to inject the form controller, you have two options:

### Option A — switch to `provider`

`ChangeNotifierProvider` from the `provider` package is a near-drop-in replacement, and `context.read` / `context.watch` / `context.select` keep working the same way:

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

Hoist the controller into a `StatefulWidget` and pass it down through constructor args. Slightly more boilerplate per screen, zero deps.

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

- **`bloc_test`** has no direct replacement. Rewrite tests as plain `test(...)` blocks. Capture emissions with `addListener` if you need to assert sequences:
  ```dart
  final emissions = <FieldState<int, MyError>>[];
  field.addListener(() => emissions.add(field.value));
  field.setValue(10);
  expect(emissions, [const FieldState(value: 10)]);
  ```
- **`bloc_presentation`** (for "submit failed → emit a UI event") has no direct replacement. The example replaces it with a plain `Stream` exposed by the controller (see `example/lib/screens/scroll_form.dart`).
- **`flutter_hooks`** only matters if you used it for `useTextEditingController` / `useFocusNode` — both are unnecessary once `TextFieldController` owns the text controller. Drop if it was the only reason you had it.

---

## 9. Migrating a rich custom field

> Class names in this section use the current `Advanced*` prefix from the codebase.

If you've been using `leancode_lint` library for a while, you probably have a folder full of custom fields: `FieldCubit` subclasses with a business-typed value (a `Decimal`, a record, a DTO, basically not a raw string), their own error types, and a couple of domain methods. That's the intended way to use the library, and it's usually the part people worry about most before migrating: "do I have to rewrite 30 of these?"

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

- **You won't get extra rebuilds after the migration.** Previously, `Equatable` made sure that emitting an identical state didn't notify anyone. The new `FieldState` does the same through its `operator ==`, and Dart records compare by content — so calling `setValue` with an unchanged record is still a no-op for your listeners. No behavioral surprises hiding here.
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

- The new architecture is documented in [`README.md`](./README.md).
- The full breaking-change summary is in [`CHANGELOG.md`](./CHANGELOG.md) under the 0.2.0 entry.
- The `example/` app demonstrates every pattern in the new shape.