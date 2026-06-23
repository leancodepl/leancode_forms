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

## Reference

- The new architecture is documented in [`README.md`](./README.md).
- The full breaking-change summary is in [`CHANGELOG.md`](./CHANGELOG.md) under the 0.2.0 entry.
- The `example/` app demonstrates every pattern in the new shape.