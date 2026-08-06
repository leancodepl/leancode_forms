# Migrating from 0.1.x to 0.2.0

0.2.0 keeps the form-building model of 0.1.x — fields, form groups, validators, subforms — and replaces the state-management machinery underneath it:

- `flutter_bloc` and `rxdart` are no longer dependencies. Fields and forms mix in `ChangeNotifier` and implement `ValueListenable`, both from the Flutter SDK, so the library no longer constrains the app's state-management stack.
- Every `*Cubit` class is now an `Advanced*Controller` (`FieldCubit` → `AdvancedFieldController`). Most members carry over unchanged; [section 3](#3-behavior-changes-that-are-not-renames) covers the ones that don't.
- Lifecycle is synchronous: `void dispose()` replaces `Future<void> close()`.
- `AdvancedTextFieldController` owns its `TextEditingController` and `FocusNode`.

## 1. Migration checklist

1. Update `pubspec.yaml`: remove `flutter_bloc` and `rxdart`, plus `bloc_test`, `bloc_presentation`, and `flutter_hooks` if forms were the only reason for them. Add `provider` if you used `BlocProvider` ([section 8](#8-dropping-flutter_bloc-and-friends)).
2. Rename the classes ([section 2](#2-rename-reference)).
3. Replace `.state` reads with `.value` / `fieldValue` ([section 4](#4-form-classes-and-state-reads)).
4. Move `asyncValidator:` and `asyncValidationDebounce:` into `asyncValidation:` ([section 4](#4-form-classes-and-state-reads)).
5. Replace `clear()` with `reset()` ([section 2](#2-rename-reference)).
6. Migrate widgets: a third builder parameter, and delete `TextEditingController` plumbing ([section 5](#5-migrating-your-widgets)).
7. Convert `close()` overrides to `dispose()`, and `addDisposable(...)` registrations to explicit cleanup ([section 7](#7-lifecycle-close--dispose)).
8. Replace form-level stream subscriptions with listeners ([section 6](#6-form-listenables-instead-of-streams)).
9. Rewire custom cubit-stream patterns ([section 9](#9-migrating-a-custom-field)).
10. Check the behavior changes in [section 3](#3-behavior-changes-that-are-not-renames) against your code — they compile but behave differently.

---

## 2. Rename reference

| 0.1.x | 0.2.0 |
| --- | --- |
| `FieldCubit<T, E>` | `AdvancedFieldController<T, E>` |
| `TextFieldCubit<E>` | `AdvancedTextFieldController<E>` |
| `BooleanFieldCubit<E>` | `AdvancedBooleanFieldController<E>` |
| `SingleSelectFieldCubit<V, E>` | `AdvancedSingleSelectFieldController<V, E>` |
| `MultiSelectFieldCubit<V, E>` | `AdvancedMultiSelectFieldController<V, E>` |
| `FormGroupCubit` | `AdvancedFormController` |
| `FieldState<T, E>` | `AdvancedFieldState<T, E>` |
| `FormGroupState` | `AdvancedFormState` (same members) |
| `FieldBuilder<T, E>` | `AdvancedFieldBuilder<T, E>` — wraps `ValueListenableBuilder`; `builder` gains a third `child` param |
| `cubit.state` | `controller.value` (plus the `fieldValue` and `error` shortcuts) |
| `field.clear()` | **Removed** — call `field.reset()` |
| `asyncValidator:`, `asyncValidationDebounce:` | `asyncValidation: AsyncValidation(validator:, debounce:, onError:)` |
| `form.onValuesChangedStream` (`Stream<void>`) | `form.onValuesChanged` (`Listenable`) |
| `form.onStatusChangedStream` (`Stream<FieldStatus>`) | `form.onStatusChanged` (`Listenable`, no payload) |
| `BlocBuilder<FormGroupCubit, FormGroupState>` | `ValueListenableBuilder<AdvancedFormState>` — there is no `AdvancedFormBuilder` |
| `FieldCubit.stream` (inherited from `Cubit`) | `AdvancedFieldController.stream` — deprecated extension, removed in 0.3.0 ([section 9](#9-migrating-a-custom-field)) |
| `Future<void> close()` | `void dispose()` |
| `addDisposable(...)`, the `Disposable` mixin | **Removed** — override `dispose()` ([section 7](#7-lifecycle-close--dispose)) |

---

## 3. Behavior changes that are not renames

These compile after the renames but behave differently.

**A throwing async validator no longer hangs the field.** In 0.1.x an exception from `asyncValidator` left the internal `Completer` uncompleted, so the field stayed in `FieldStatus.validating` indefinitely and the exception surfaced as an uncaught async error. In 0.2.0 the field moves to `FieldStatus.failed` and the exception is reported through `FlutterError.reportError`, or through `AsyncValidation.onError` if you supply a handler. A `failed` field is not valid — `validate()` returns `false`, so a failed availability check cannot let a submit through. Setting a new value re-runs the validator.

**`FieldStatus` gained a `failed` value.** Previously exhaustive `switch`es over `FieldStatus` stop compiling until you add a `failed` arm. Map it alongside `invalid` unless you want to distinguish "the check could not run" from "the check returned an error".

**`subscribeToFields` fires more eagerly.** 0.1.x combined the observed fields with `Rx.combineLatest`, so nothing fired until *every* observed field had emitted at least once, and the first emission always passed `.distinct()` even for a status-only change. 0.2.0 compares each observed field's value against a cached baseline: it fires on the first value change to any one field, and never on a status-only change. Dependent fields that appeared not to revalidate in 0.1.x now will.

**Value equality is no longer deep.** `equatable` is gone, and `AdvancedFieldState.operator ==` compares members with `==`. For scalars and records this matches 0.1.x. For `List`/`Set`/`Map` values or error types, two equal-content-but-distinct instances now compare unequal, so `setValue` notifies where 0.1.x deduplicated. Most visible on `AdvancedMultiSelectFieldController`, whose value *is* a `Set` and whose `addValue` / `removeValue` allocate a new set on every call.

**`addSubform` throws instead of failing quietly.** It raises a `StateError` if either the parent or the subform has already been disposed.

**Form state settles synchronously.** 0.1.x routed field changes through a `.distinct()` subscription, so `wasModified` and `validating` updated a microtask later. They now update in the same call stack as the field change.

**Debounce timers and in-flight async validations are cancelled on dispose.** 0.1.x `close()` cancelled only the field subscription, so a timer could fire after close.

---

## 4. Form classes and state reads

Form classes — those declaring fields and calling `registerFields` — need the renames and the async-validation change:

```dart
class SimpleFormController extends AdvancedFormController {   // was: extends FormGroupCubit
  SimpleFormController() {
    registerFields([firstName, email]);                       // unchanged
  }

  final firstName = AdvancedTextFieldController(              // was: TextFieldCubit(
    initialValue: 'John',
    validator: filled(ValidationError.empty),                 // unchanged
  );

  final email = AdvancedTextFieldController(
    validator: filled(ValidationError.empty),
    asyncValidation: AsyncValidation(                          // was: asyncValidator: _check,
      validator: _check,                                       //      asyncValidationDebounce: …,
      debounce: Duration(milliseconds: 500),
    ),
  );
}
```

`debounce` defaults to 300 ms, matching the old `asyncValidationDebounce` default, so it can be omitted if you never set it.

State reads change as follows:

| 0.1.x | 0.2.0 |
| --- | --- |
| `field.state` | `field.value` |
| `field.state.value` | `field.fieldValue` (or `field.value.value`) |
| `field.state.error` | `field.error` (or `field.value.error`) |
| `field.state.validationError` | `field.value.validationError` |
| `form.state.wasModified` | `form.value.wasModified` |

Notification is synchronous for `setValue`, `setError`, `reset`, and the other setters — no broadcast stream and no microtask hop, so tests can assert immediately after the call. Async validation is unchanged: you still have to wait out the debounce plus the validator.

---

## 5. Migrating your widgets

### Builders

`AdvancedFieldBuilder` replaces `FieldBuilder`. Its `builder` is a `ValueWidgetBuilder`, so it takes a third `child` parameter:

```dart
builder: (context, state) => Text(state.value)      // 0.1.x
builder: (context, state, _) => Text(state.value)   // 0.2.0
```

If your widgets **subclassed** `FieldBuilder` — `class FormTextField<E> extends FieldBuilder<String, E>` — that pattern no longer carries its weight, because fields are `ValueListenable`s. Rewrite them as plain `StatelessWidget`s over `ValueListenableBuilder<AdvancedFieldState<T, E>>`, which is what every widget in `example/lib/widgets/` does.

### Text fields

In 0.1.x each text widget allocated its own `TextEditingController` and seeded it from `field.state.value`, so programmatic changes — `reset()`, `setValue('foo')`, one field updating another — never reached the screen. The field owns the controller now:

```dart
TextField(controller: field.textController);
```

To migrate a custom text widget:

1. Delete the `useTextEditingController` call or the manually allocated `TextEditingController`.
2. Delete the `initialValue: state.value` and `onChanged: field.setValue` plumbing.
3. Pass `controller: field.textController` to the underlying `TextField` or `TextFormField`.
4. Delete any `FocusNode`-adding field subclass — `AdvancedTextFieldController` owns a `focusNode` and a `focus()` shortcut, so a separate "focusable" variant of the widget is no longer needed.

`AdvancedTextFieldController` disposes both the text controller and the focus node in its own `dispose()`. Do not dispose them externally.

---

## 6. Form listenables instead of streams

| 0.1.x | 0.2.0 |
| --- | --- |
| `form.onValuesChangedStream.listen(f)` | `form.onValuesChanged.addListener(f)` |
| `form.onStatusChangedStream.listen(f)` | `form.onStatusChanged.addListener(f)` |
| `await subscription.cancel()` | `form.onValuesChanged.removeListener(f)` |

Two consequences:

- `removeListener` needs the same callback instance that was passed to `addListener`, so a listener you intend to remove has to be a named function or a stored closure, not an inline one.
- `onStatusChanged` carries no payload, where `onStatusChangedStream` emitted the changed `FieldStatus`. Read the status off the field, or `form.value.validating` for the aggregate.

To rebuild on form state, `AdvancedFormController` is itself a `ValueListenable<AdvancedFormState>`:

```dart
ValueListenableBuilder<AdvancedFormState>(
  valueListenable: form,
  builder: (context, state, _) => SubmitButton(enabled: state.wasModified),
)
```

---

## 7. Lifecycle: `close()` → `dispose()`

```dart
@override
Future<void> close() async {   // 0.1.x
  await field.close();
  return super.close();
}

@override
void dispose() {               // 0.2.0
  field.dispose();
  super.dispose();
}
```

The `Disposable` mixin is gone with it, so `addDisposable(subscription.cancel)` registrations become explicit cleanup in `dispose()`. Note that 0.1.x `FormGroupCubit` also exposed a public `Future<void> dispose()` through that mixin; `await form.dispose()` no longer compiles.

### Disposing twice

`dispose()` is not idempotent: a second call throws in debug mode (`'A AdvancedTextFieldController<…> was used after being disposed.'`). `Cubit.close()` tolerated it, so 0.1.x code that disposed a field by hand *and* let `FormGroupCubit.close()` dispose it again worked by accident.

Give every field and subform a single owner, and let the form be it:

- Fields registered with `registerFields(...)` are disposed by `AdvancedFormController`. Ownership is tracked in a `Set`, so registering the same field twice is safe.
- Subforms attached with `addSubform(...)` are disposed by the parent too. Do not also dispose them in your own `dispose()` override, and note that `removeSubform(...)` disposes by default — pass `close: false` to keep the subform alive.

---

## 8. Dropping `flutter_bloc` and friends

**`BlocProvider` → `ChangeNotifierProvider`.** `context.read` / `context.watch` / `context.select` behave as before:

```dart
BlocProvider<SimpleFormCubit>(create: (context) => SimpleFormCubit(), …)              // 0.1.x
ChangeNotifierProvider<SimpleFormController>(create: (context) => SimpleFormController(), …)
```

Two things to watch while converting screens:

- Prefer hoisting one `final controller = context.watch<SimpleFormController>();` at the top of `build` over repeated `context.read` calls.
- State your controller holds *outside* `AdvancedFormState` — a selected tab, a list of dynamically added rows — needs an explicit `notifyListeners()` now. In 0.1.x, `emit(FormGroupState(...))` rebuilt watchers as a side effect.

Or drop the DI dependency entirely: controllers are `ChangeNotifier`s, so a `StatefulWidget` can own one and dispose it in `dispose()`.

**`bloc_test`.** State setters are synchronous, so a form test is a plain `test(...)` block with no `blocTest` DSL. To assert a sequence of states, collect them with a listener:

```dart
final emissions = <AdvancedFieldState<int, MyError>>[];
field.addListener(() => emissions.add(field.value));
field.setValue(10);
expect(emissions, [const AdvancedFieldState(value: 10)]);
```

Async validation still needs a wait, since the debounce timer is unchanged.

**`bloc_presentation`.** The "submit failed → fire a one-off UI event" pattern has no direct equivalent; expose a plain `Stream` from the controller instead, as `example/lib/screens/scroll_form.dart` does.

**`flutter_hooks`.** If `useTextEditingController` and `useFocusNode` were the only reason for it, it can go — `AdvancedTextFieldController` owns both.

---

## 9. Migrating a custom field

Custom fields — subclasses with a domain-typed value, their own error type, and domain methods — migrate with two edits. Validators, error hierarchies, and domain methods carry over unchanged.

```dart
class QuantityFieldController                                    // was: QuantityFieldCubit
    extends AdvancedFieldController<QuantityValue, QuantityError> {   // was: extends FieldCubit<…>
  QuantityFieldController({QuantityBounds? Function()? bounds})
      : super(
          initialValue: (unit: 'kg', amount: null),              // unchanged
          validator: (value) => _validate(value, bounds?.call()),
        );

  void setAmount(num? amount) =>
      setValue((unit: fieldValue.unit, amount: amount));         // was: state.value.unit

  void clearBackendError() {
    if (value.validationError is QuantityBackendError) {         // was: state.validationError
      validate();
    }
  }
}
```

If the field holds a `String` and its widget binds a text controller, extend `AdvancedTextFieldController<E>` rather than `AdvancedFieldController<String, E>` — you get `textController` and `focusNode` with it.

### Replacing cubit-stream patterns

`FieldCubit` inherited `stream` from `Cubit`; notifiers have no stream.

**Field B revalidates when field A changes** — `subscribeToFields([fieldA])`, as in 0.1.x, but note the timing change in [section 3](#3-behavior-changes-that-are-not-renames).

**React to part of a field's value changing** — add a listener and compare the part yourself:

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

productField.addListener(onProductChanged);   // removeListener in dispose()
```

**Code that composes streams** — rxdart operators, `await for`, merging fields into a pipeline. The deprecated `stream` extension bridges a field to a broadcast stream so helpers written against `FieldCubit.stream` keep compiling:

```dart
final subscription = quantityField.stream
    .map((state) => state.value.amount)
    .listen(recalculateTotals);
```

Three caveats: every read of `stream` allocates a new `StreamController`, so store it rather than reading the getter repeatedly; the controller is never closed, so unlike `Cubit.stream` it does not terminate an `await for` loop; and it is removed in 0.3.0, so treat the deprecation warnings as the to-do list for a follow-up pass.

---

## 10. What didn't change

Every validator and the `Validator` / `AsyncValidator` / `ErrorTranslator` typedefs, so custom validators compile as-is. Every field and form method not named in [section 2](#2-rename-reference) — including `setValue`, `validate`, `setAutovalidate`, `markReadOnly`, `setError`, `getValueSetter`, `registerFields`, `addSubform`, `resetAll`, `setValidationEnabled`, `validateWithAutovalidate`. The `pending` → `validating` → `valid`/`invalid` sequence, the debounce, and cancel-on-new-value. `wasModified` and `validating`, still computed with `DeepCollectionEquality` against the baseline values.

---

## 11. Reference

- [`README.md`](./README.md) documents the 0.2.0 architecture from scratch.
- [`EXAMPLES.md`](./EXAMPLES.md) walks through the common form patterns.
- [`CHANGELOG.md`](./CHANGELOG.md) has the terse breaking-change list under the 0.2.0 entry.
- The `example/` app is fully migrated and is the best reference for what a real conversion looks like.
