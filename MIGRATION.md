# Migrating from 0.1.x to 0.2.0

0.2.0 keeps the form-building model of 0.1.x — fields, form groups, validators, subforms — and replaces the state-management machinery underneath it:

- `flutter_bloc` and `rxdart` are no longer dependencies. Fields and forms are built on `ValueNotifier`/`ChangeNotifier` from the Flutter SDK, so the library no longer constrains the app's state-management stack.
- Every `*Cubit` class is now an `Advanced*Controller` (`FieldCubit` → `AdvancedFieldController`). Methods and behavior are unchanged.
- Lifecycle is synchronous: `void dispose()` replaces `Future<void> close()`.
- `AdvancedTextFieldController` owns its `TextEditingController` and keeps it in sync with the field value in both directions.

## Migration steps

1. Rename the classes ([section 1](#1-rename-reference)).
2. Replace `.state` reads with `.value` / `fieldValue` ([section 2](#2-migrating-your-form-classes)).
3. Move `asyncValidator:` and `asyncValidationDebounce:` into `asyncValidation:` ([section 2](#2-migrating-your-form-classes)).
4. Add a third parameter to `FieldBuilder` builders ([section 3](#3-migrating-your-widgets--fieldbuilder-becomes-advancedfieldbuilder)).
5. Convert `close()` overrides to `dispose()` ([section 4](#4-lifecycle-close--dispose)).
6. Delete `TextEditingController` plumbing from text widgets ([section 5](#5-advancedtextfieldcontroller-now-owns-its-texteditingcontroller)).
7. Replace form-level stream subscriptions with listeners ([section 6](#6-advancedformcontroller-exposes-listenables-not-streams)).
8. Handle the new `FieldStatus.failed` value if you switch over `FieldStatus` ([behavior changes](#behavior-changes-that-are-not-renames)).
9. Rewire custom cubit-stream patterns ([section 9](#9-migrating-a-rich-custom-field)).

Steps 1–5 are mechanical. Step 6 removes code. Steps 7–9 typically touch a handful of files. [Section 7](#7-what-didnt-change) lists the API surface that did not change.

---

## Behavior changes that are not renames

Two changes are not covered by renaming, and both are worth checking before you start.

**A throwing async validator no longer hangs the field.** In 0.1.x, an exception from `asyncValidator` left the internal `Completer` uncompleted, so the field stayed in `FieldStatus.validating` indefinitely and the exception surfaced as an uncaught async error. In 0.2.0 the field moves to `FieldStatus.failed`, and the exception is reported through `FlutterError.reportError` — or through `AsyncValidation.onError` if you supply a handler:

```dart
AdvancedTextFieldController<ValidationError>(
  asyncValidation: AsyncValidation(
    validator: _checkEmailAvailable,
    onError: (error, stackTrace) async => _log.warning('email check failed', error, stackTrace),
  ),
);
```

A `failed` field is not valid: `validate()` returns `false` for it, so a failed availability check cannot let a submit through. Setting a new value re-runs the validator.

**`FieldStatus` gained a `failed` value.** Non-exhaustive `switch` statements over `FieldStatus` in your code will stop compiling. Map `failed` to the same branch as `invalid` unless you want to distinguish "check could not run" from "check returned an error" in the UI.

---

## 1. Rename reference

| 0.1.x | 0.2.0 |
| --- | --- |
| `FieldCubit<T, E>` | `AdvancedFieldController<T, E>` |
| `TextFieldCubit<E>` | `AdvancedTextFieldController<E>` |
| `BooleanFieldCubit<E>` | `AdvancedBooleanFieldController<E>` |
| `SingleSelectFieldCubit<V, E>` | `AdvancedSingleSelectFieldController<V, E>` |
| `MultiSelectFieldCubit<V, E>` | `AdvancedMultiSelectFieldController<V, E>` |
| `FormGroupCubit` | `AdvancedFormController` |
| `FieldBuilder<T, E>` | `AdvancedFieldBuilder<T, E>` — wraps `ValueListenableBuilder`; `field:` re-typed to `AdvancedFieldController<T, E>`, `builder` gains a third `child` param |
| `cubit.state` | `controller.value` (plus the `fieldValue` and `error` shortcuts) |
| `asyncValidator:`, `asyncValidationDebounce:` | `asyncValidation: AsyncValidation(validator:, debounce:, onError:)` |
| `form.onValuesChangedStream` (`Stream<void>`) | `form.onValuesChanged` (`Listenable`) |
| `form.onStatusChangedStream` (`Stream<FieldStatus>`) | `form.onStatusChanged` (`Listenable`) |
| `FieldCubit.stream` (inherited from `Cubit`) | `AdvancedFieldController.stream` — deprecated migration bridge, removed in 0.3.0 ([section 9](#9-migrating-a-rich-custom-field)) |
| `Future<void> close()` | `void dispose()` |

In `pubspec.yaml`:

- Remove `flutter_bloc` and `rxdart` unless other code depends on them.
- Remove `bloc_test`, `bloc_presentation`, and `flutter_hooks` if forms were the only reason they were there.
- Add `provider` if you want a drop-in replacement for `BlocProvider` and `context.read` (see [section 8](#8-migrating-exampletest-code-that-used-flutter_bloc-directly)).

---

## 2. Migrating your form classes

Form classes — those declaring fields and calling `registerFields` — need the class renames and the async-validation parameter change.

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
    asyncValidationDebounce: Duration(milliseconds: 500),
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
    asyncValidation: AsyncValidation(
      validator: _onEmailChanged,
      debounce: Duration(milliseconds: 500),
    ),
  );

  Future<ValidationError?> _onEmailChanged(String value) async { /* ... */ }
}
```

`debounce` defaults to 300 ms, the same default `asyncValidationDebounce` had, so it can be omitted if you never set it.

### Reading state

The `.state` getter is gone. State lives under `.value`, the name `ValueListenable` uses:

```dart
// 0.1.x:
controller.firstName.state.value;

// 0.2.0:
controller.firstName.value.value;

// or, via the shortcut:
controller.firstName.fieldValue;
```

`fieldValue` returns the inner value and `error` returns the current error, so hand-written code can avoid `value.value` and `value.error`.

Notification is synchronous: assigning a new value runs listeners in the same call stack, with no broadcast stream and no microtask hop. Tests do not need to await a state change.

---

## 3. Migrating your widgets — `FieldBuilder` becomes `AdvancedFieldBuilder`

`FieldBuilder` becomes `AdvancedFieldBuilder`, a wrapper around `ValueListenableBuilder` rather than `BlocBuilder`. Two differences beyond the rename:

- The `field:` parameter is typed `AdvancedFieldController<T, E>`. Specialized field types such as `AdvancedTextFieldController` satisfy it without changes.
- `builder` is a `ValueWidgetBuilder`, so it takes a third `child` parameter. Add `, _` to each builder's parameter list.

```dart
// 0.1.x:
FieldBuilder<String, MyError>(
  field: controller.email,
  builder: (context, state) => Text(state.value),
)

// 0.2.0:
AdvancedFieldBuilder<String, MyError>(
  field: controller.email,
  builder: (context, state, _) => Text(state.value),
)
```

The third parameter carries the `child:` optimization: a subtree that does not depend on field state is built once and reused across rebuilds.

```dart
AdvancedFieldBuilder<String, MyError>(
  field: controller.email,
  child: const ExpensiveStaticIcon(),
  builder: (context, state, child) => Row(
    children: [child!, Text(state.value)],
  ),
)
```

Fields are `ValueListenable`s, so `ValueListenableBuilder<AdvancedFieldState<String, MyError>>` works directly as well. `AdvancedFieldBuilder` exists so that existing widget code compiles after a rename and so that call sites do not have to spell out the state type argument.

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

`close()` was asynchronous because it closed a broadcast `StreamController`. `ChangeNotifier.dispose()` clears a listener list, so there is nothing to await.

### Disposing twice

`dispose()` is not idempotent: calling it twice on a notifier in debug mode throws `'A ValueNotifier was used after being disposed'`. `Cubit.close()` tolerated a second call, so 0.1.x code that disposed a field by hand *and* let `FormGroupCubit.close()` dispose it again worked by accident and now fails.

Assign each field a single owner. The form is the straightforward choice:

- Register fields with `registerFields(...)` and let `AdvancedFormController` dispose them. Do not call `dispose()` on registered fields yourself.
- Registering the same field more than once is safe — ownership is tracked in a `Set`, so each field is disposed exactly once.

---

## 5. `AdvancedTextFieldController` now owns its `TextEditingController`

In 0.1.x, each text widget allocated its own `TextEditingController`, seeded it from `field.state.value`, and wired `onChanged: field.setValue` back. Programmatic changes — `field.reset()`, `field.setValue('foo')`, one field updating another — did not reach the widget, because its controller was seeded once and then held its own copy of the string.

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

To migrate a custom text widget:

1. Delete the `useTextEditingController` call or the manually allocated `TextEditingController`.
2. Delete the `initialValue: state.value` and `onChanged: field.setValue` plumbing.
3. Pass `controller: field.textController` to the underlying `TextField` or `TextFormField`.

`AdvancedTextFieldController` allocates the `TextEditingController` and a `FocusNode`, keeps the text controller and the field value in sync in both directions, and disposes both in `dispose()`. Do not dispose them externally.

---

## 6. `AdvancedFormController` exposes `Listenable`s, not `Stream`s

Subscriptions become listener callbacks:

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

`onStatusChanged` replaces `onStatusChangedStream` the same way.

`removeListener` needs the same callback instance that was passed to `addListener`, so where you previously cancelled a `StreamSubscription` in `dispose`, the listener has to be a named function or a stored closure rather than an inline one.

---

## 7. What didn't change

The following API surface is unchanged. Code that only touches it needs the renames and nothing else.

- **Validators.** The `Validator<T, E>` and `AsyncValidator<T, E>` typedefs, and every built-in validator (`filled`, `atLeastLength`, `notLongerThan`, `notNull`, `notEmpty`, `or`, `and`, `&`, `|`, …), keep their names and signatures. Custom validators compile as-is.
- **Field methods.** `setValue`, `validate`, `setAutovalidate`, `markReadOnly`, `unmarkReadOnly`, `clearErrors`, `reset`, `setError`, `getValueSetter`, `subscribeToFields`.
- **Form-group methods.** `registerFields`, `addSubform`, `removeSubform`, `setValidationEnabled`, `validateWithAutovalidate`, `resetAll`, `markReadOnly`, `clearErrors`.
- **Async validation sequence.** The `pending` → `validating` → `valid`/`invalid` transitions, the debounce timer, and cancel-on-new-value are unchanged. Only the throwing case differs (see [behavior changes](#behavior-changes-that-are-not-renames)).
- **`wasModified` and `validating` aggregate flags.** Computed as before, with `DeepCollectionEquality` comparing against the baseline values.
- **`subscribeToFields`.** Still ignores status-only changes, so dependent fields do not revalidate without a value change. The implementation moved from `Rx.combineLatest` + `distinct` to a cached comparison; the observable behavior is the same.

---

## 8. Migrating example/test code that used `flutter_bloc` directly

If `BlocProvider` supplied the form controller to the widget tree, there are two options.

### Option A — use `provider`

`ChangeNotifierProvider` is a near-drop-in replacement, and `context.read` / `context.watch` / `context.select` behave as before:

```dart
// 0.1.x
BlocProvider<SimpleFormCubit>(
  create: (context) => SimpleFormCubit(),
  child: const SimpleForm(),
)

// 0.2.0 with `provider`
ChangeNotifierProvider<SimpleFormController>(
  create: (context) => SimpleFormController(),
  child: const SimpleForm(),
)
```

### Option B — plain Flutter, no DI dependency

Controllers are `ChangeNotifier`s, so a `StatefulWidget` can own one and pass it down through constructor arguments:

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
  Widget build(BuildContext context) => SimpleForm(controller: controller);
}
```

### Other test-side dependencies

- **`bloc_test`.** Because notifiers are synchronous, a form test is a plain `test(...)` block — no `blocTest` DSL and no `wait:`. To assert a sequence of states, collect them with a listener:

  ```dart
  final emissions = <AdvancedFieldState<int, MyError>>[];
  field.addListener(() => emissions.add(field.value));
  field.setValue(10);
  expect(emissions, [const AdvancedFieldState(value: 10)]);
  ```

- **`bloc_presentation`.** The "submit failed → fire a one-off UI event" pattern has no direct equivalent. Expose a plain `Stream` from the controller instead; `example/lib/screens/scroll_form.dart` shows this.
- **`flutter_hooks`.** If `useTextEditingController` and `useFocusNode` were the only reason for the dependency, it can go — `AdvancedTextFieldController` owns both (see [section 5](#5-advancedtextfieldcontroller-now-owns-its-texteditingcontroller)).

---

## 9. Migrating a rich custom field

Custom fields — `FieldCubit` subclasses with a domain-typed value, their own error type, and domain methods — migrate with two edits per file:

1. Change the base class from `FieldCubit` to `AdvancedFieldController`.
2. Change state reads: `state.value` → `fieldValue`, `state.validationError` → `value.validationError`.

Validators, error hierarchies, and domain methods carry over unchanged.

The example below holds an amount paired with a unit, validates against bounds recomputed on every pass (so they can depend on other app state), and accepts validation errors returned by a server.

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

**NEW** — same value type, errors, bounds callback, and methods:

```dart
class QuantityFieldController
    extends AdvancedFieldController<QuantityFieldValue, QuantityFieldError> {
  QuantityFieldController({
    String initialUnit = 'kg',
    num? initialAmount,
    QuantityBounds? Function()? bounds,
    super.name, // optional: labels the field in diagnostics
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

Notes:

- **Rebuild counts do not change.** `Equatable` previously suppressed notifications for an identical state; `AdvancedFieldState.operator ==` does the same, and Dart records compare by content. Calling `setValue` with an unchanged record still notifies nobody.
- **Use `fieldValue` for composite values.** The full path to a record component is state → record → component, which reads as `value.value.unit`. `fieldValue.unit` is the equivalent of the old `state.value.unit`. The same applies to `error` versus `value.error`.
- **`name` is new and optional.** It labels the field in `FlutterError` reports from async validation and in the `debugLabel` of the `FocusNode` owned by `AdvancedTextFieldController`, and it gives serialization and logging code a stable handle. It does not affect behavior.

### Replacing cubit-stream patterns

`FieldCubit` inherited `stream` from `Cubit`; notifiers have no stream. Each pattern maps as follows:

- **Field B revalidates when field A changes** — `subscribeToFields([fieldA])`, as in 0.1.x. Nothing to migrate.
- **React to part of a field's value changing** — add a listener and compare the selected part yourself:

  ```dart
  var lastProductId = productField.fieldValue.productId;

  void onProductChanged() {
    final productId = productField.fieldValue.productId;
    if (productId == lastProductId) {
      return;
    }
    lastProductId = productId;
    priceField.refreshFor(productId);
  }

  productField.addListener(onProductChanged);
  // Later, e.g. in dispose():
  productField.removeListener(onProductChanged);
  ```

- **Code that composes streams** — rxdart operators, `await for`, merging fields into a pipeline. The deprecated `stream` getter bridges a field to a broadcast `Stream<AdvancedFieldState<T, E>>` so helpers written against `FieldCubit.stream` keep compiling:

  ```dart
  final subscription = quantityField.stream
      .map((state) => state.value.amount)
      .listen(recalculateTotals);
  ```

  Each read of `stream` allocates a new `StreamController`, so store the stream in a variable rather than reading the getter repeatedly.

  The getter is deprecated from the day it ships: it exists so a migration does not stall on stream-heavy code, and it will be removed in 0.3.0. Treat the deprecation warnings as the to-do list for a follow-up pass, and use `addListener`, `subscribeToFields`, or the builder widgets in anything new.

---

## Reference

- [`README.md`](./README.md) documents the 0.2.0 architecture from scratch.
- [`CHANGELOG.md`](./CHANGELOG.md) has the complete breaking-change list under the 0.2.0 entry.
- The `example/` app shows every pattern in its migrated form.
