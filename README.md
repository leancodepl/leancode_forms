<div align="center">

[![Banner][banner-img]][leancode-landing]

</div>

[![pub package](https://img.shields.io/pub/v/advanced_forms.svg)](https://pub.dev/packages/advanced_forms)
[![test](https://github.com/leancodepl/advanced_forms/actions/workflows/test.yml/badge.svg)](https://github.com/leancodepl/advanced_forms/actions/workflows/test.yml)
[![License: Apache 2.0][license-badge]][license-badge-link]

Forms in Flutter without a framework on top. `advanced_forms` gives you typed field controllers, composable validation, and form-level state tracking.

## General overview

<img width="2206" height="1065" alt="Untitled-2026-08-17-2217-5" src="https://github.com/user-attachments/assets/72f7812d-2420-489d-aec1-c28c8ae373b5" />

## Installation

```sh
flutter pub add advanced_forms
```

Migrating from 0.1.x, the bloc-based version? See [MIGRATION.md](./MIGRATION.md).

## Your first form

A controller holds the fields and registers them; a widget binds to each field:

```dart
class SignupFormController extends AdvancedFormController {
  SignupFormController() {
    registerFields([firstName, lastName]);
  }

  final firstName = AdvancedTextFieldController(
    validator: filled('First name is required'),
  );
  final lastName = AdvancedTextFieldController(
    validator: filled('Last name is required'),
  );

  Future<void> submit() async {
    if (await validate()) {
      // send it
    }
  }
}
```

```dart
class SignupForm extends StatefulWidget {
  const SignupForm({super.key});

  @override
  State<SignupForm> createState() => _SignupFormState();
}

class _SignupFormState extends State<SignupForm> {
  final _form = SignupFormController();

  @override
  void dispose() {
    _form.dispose();   // disposes the registered fields too
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SignupTextField(field: _form.firstName, label: 'First name'),
        _SignupTextField(field: _form.lastName, label: 'Last name'),
        ElevatedButton(onPressed: _form.submit, child: const Text('Submit')),
      ],
    );
  }
}
```

```dart
class _SignupTextField extends StatelessWidget {
  const _SignupTextField({required this.field, required this.label});

  final AdvancedTextFieldController<String> field;   // <String> is the error type
  final String label;

  @override
  Widget build(BuildContext context) {
    return AdvancedFieldBuilder<String, String>(
      field: field,
      builder: (context, state, _) => TextFormField(
        controller: field.textController,
        decoration: InputDecoration(labelText: label, errorText: state.error),
      ),
    );
  }
}
```

Fields stay quiet until the first `validate()`, then give live feedback.

Two rules to remember:

- **Call `registerFields()` once, with every field.** The form then owns their lifecycle — it disposes them, tracks whether anything was modified, and includes them in `validate()`, `resetAll()`, and the other form-wide operations. Calling it a second time *replaces* the field list, so the earlier batch stops participating while still being disposed at teardown.
- **Bind widgets to `field.textController`**, not to a controller of your own. See [Rendering fields](#rendering-fields).

Own the controller wherever you like — it's a `ChangeNotifier`, so any DI package works as well as the `StatefulWidget` above. `ChangeNotifierProvider` from `provider` is one widget, and it disposes the controller for you (`provider` is used in the snippets below; it is not a dependency of this package). Whoever owns the form controller disposes it, and that one call disposes the registered fields and the attached subforms.

## Where to next

- [MIGRATION.md](./MIGRATION.md) — coming from 0.1.x.
- `example/` — a runnable app where every pattern in these docs has a working screen. See [example/README.md](./example/README.md) for the screen guide.
- [API reference](https://pub.dev/documentation/advanced_forms/latest/) — the generated dartdoc, for every member and its edge cases.

## Rendering fields

`AdvancedFieldBuilder` rebuilds a subtree whenever its field notifies:

```dart
AdvancedFieldBuilder<String, MyError>(
  field: firstName,
  builder: (context, state, _) => TextFormField(
    controller: firstName.textController,
    decoration: InputDecoration(
      errorText: state.error != null ? translate(state.error!) : null,
    ),
  ),
);
```

It wraps `ValueListenableBuilder`, so the SDK widget works too if you'd rather spell out `ValueListenableBuilder<AdvancedFieldState<String, MyError>>` — the wrapper exists to hide that type argument.

Note what's *not* in the snippet: no `TextEditingController` allocation, no `onChanged`, no `initialValue` seeding. `AdvancedTextFieldController` owns its `TextEditingController` (`field.textController`) and keeps it in two-way sync — user input flows into the field state, and programmatic changes (`setValue`, `reset`) flow back into the visible text. It also owns a `FocusNode` (`field.focusNode`), so "jump to the first invalid field" is `field.focus()`. Working example: the "Scroll Form" screen in the example app (`example/lib/screens/scroll_form.dart`).

Rebuilds are granular by construction: each builder subscribes to one field, so a keystroke rebuilds that field's subtree and nothing else. `AdvancedFieldState` is value-equal, so setting a field to the value it already holds notifies nobody.

`builder`'s third parameter is a `child:` you can pass for a subtree that doesn't depend on field state — built once and reused on every rebuild. See `example/lib/widgets/form_text_field_with_icon.dart` and the "Optimized Rendering" screen in the example app.

For parent widgets, grab the controller with `context.read<SignupFormController>()` — no subscription, no parent rebuilds — and let each field widget subscribe to its own field.

## Form-level state

`AdvancedFormController` is itself a `ValueListenable<AdvancedFormState>`, so form-wide state renders the same way a field does:

```dart
ValueListenableBuilder<AdvancedFormState>(
  valueListenable: form,
  builder: (context, state, _) => ElevatedButton(
    onPressed: state.wasModified ? form.submit : null,
    child: const Text('Submit'),
  ),
);
```

`AdvancedFormState` carries `wasModified` (any field changed since `registerFields`), `fields` / `subforms`, `validationEnabled`, and `validationMode` — the configured mode, not reduced by `validationEnabled`. Four members are derived from the fields on every read, so they never report a field or subform that has since been removed:

| Member | Meaning |
| --- | --- |
| `validating` | An async check is in flight somewhere in the tree |
| `canSubmit` | Every field is `valid` **right now** — a snapshot of *known* errors, so it is true on a quiet form nobody has checked yet, and false while any check is pending or in flight. `await form.validate()` is the guarantee |
| `hasFailedValidation` | Some field's async check could not run — it threw or timed out. Drives one form-level banner |
| `validationErrors` | Every error in the form tree, sync or async, keyed by field, for an error summary |

With `provider`, `context.select<SignupFormController, bool>((c) => c.value.validating)` subscribes to one slice.

To react outside a builder, `form.onValuesChanged` and `form.onStatusChanged` are `Listenable`s covering the whole tree, subforms included. Pass a named callback so you can `removeListener` it later.

`AdvancedFormController` takes two optional constructor arguments: `debugName`, a label for logging across nested subforms, and `validateAll` — when true, a change to any field re-runs the **sync** validator on every *other* autovalidating field, which is what you want when fields validate against each other. No async check is restarted: a field whose own value did not change keeps its last answer, so typing starts no async checks. It is the blunt version of `subscribeToFields`, reaching the whole tree instead of the dependencies you name.

## Validation

A validator is a function — the `Validator<T, E extends Object>` typedef, `E? Function(T)`: value in, error out, `null` means valid. `E` is whatever type you choose, so plain `String`s are fine to start and a form can switch to an enum or sealed class later, independently of every other form:

```dart
final firstName = AdvancedTextFieldController(
  validator: (value) => value.isEmpty ? 'First name cannot be empty' : null,
);
```

Three rules cover every case:

1. **The validation mode decides which events make a field validate itself.** Set it once on the form; it reaches every field and subform.
2. **A field the user has never edited validates nothing on its own**, in every mode. `validate()` is what checks those, so a prefilled form does not greet the user with errors.
3. **A round runs the sync validator first, and the async validator only if sync passed.**

| `ValidationMode` | What the user sees |
| --- | --- |
| `manual` (default) | Nothing validates until submit. Editing a field still clears the error that described its old value |
| `onUserInteraction` | Every keystroke validates the field being edited; the async check waits out its debounce |
| `onUnfocus` | Leaving a field the user edited validates it. Tabbing through it, or leaving it unchanged, costs nothing |

```dart
final form = AdvancedFormController(
  validationMode: ValidationMode.onUnfocus,
);

// One field can opt out and manage its own mode from then on.
form.email.setValidationMode(ValidationMode.onUserInteraction);
```

`onUnfocus` needs the widget to bind the field's `focusNode`, or to call `field.handleUnfocus()` itself — which is what a picker or a dropdown does.

The field makes and owns that `focusNode`. Pass `focusNode:` to the constructor to bind one you already own instead — the field listens to it but never disposes it.

`await form.validate()` walks every field and subform, runs their async validators too, and returns `false` if anything is invalid. It neither consults the mode nor changes it: the mode you set is the mode the form keeps for its whole life.

To write a value the user did not type — prefilling from a profile fetch, for instance — use `field.prefill(value)`. It stores the value and clears the errors without making the field count as edited.

`validate()` is asynchronous because it may have to wait on the server. **Await it** — the result is the only thing that says the values were actually checked. Calling it again before the first call finishes gives you the same result, so a double-tapped submit button runs one pass.

```dart
Future<void> submit() async {
  if (await form.validate()) {
    await api.signUp(...);
  }
}
```

The form-level result is just a `bool` — "may this submit proceed?". The errors themselves stay on the fields, where the widgets displaying them are already subscribed.

Note that `valid` means *no error recorded*, not *checked and passed*: a field nobody has validated yet is `valid`, which is why `canSubmit` is fine for enabling a button but not for deciding a submit.

### Ready-to-use validators

- `filled`, `notEmpty`, `notNull` — reject empty strings (whitespace-only included), empty lists, and nulls,
- `notLongerThan`, `atLeastLength`, `exactly`, `nothing` — string length bounds, an exact match, and "must be empty",
- `positiveInteger`, `nonNegativeInteger`, `boundedNonNegativeInteger`, `positiveDecimal`, `nonNegativeDecimal` — numeric strings,
- `and` / `or` (also `&` and `|`), `conditionalValidator`, `dynamicValidator` — combine two validators, run one only while a condition holds, or rebuild one on each run for parameters that change at runtime.

```dart
final email = AdvancedTextFieldController(
  validator: filled(MyError.required) & atLeastLength(5, MyError.tooShort),
);
```

### Async validation

Some checks live on the server — "is this username taken?". Pass an `asyncValidation`, which all four field controllers accept:

```dart
final email = AdvancedTextFieldController(
  validator: filled(MyError.required),
  asyncValidation: AsyncValidation(
    validator: _checkEmailTaken,                   // Future<MyError?> Function(String)
    debounce: const Duration(milliseconds: 500),   // default 300ms
    timeout: const Duration(seconds: 5),           // optional, default: no bound
    onFailure: _reportCheckFailure,                // optional
    failureToError: (e, s) => MyError.checkFailed, // optional
  ),
);
```

The pass is debounced, and `await validate()` runs a waiting check at once rather than reporting the field bad for being busy. Changing the value — or `setError`, `clearErrors`, `reset`, `markReadOnly`, `dispose` — kills a live pass, and its later result is dropped. A settled answer is reused while it still describes the value, so a second submit press on an unchanged form makes no calls; a check that depends on state *outside* the value must be invalidated with `clearErrors()`. The status walks `pending` → `validating` → `valid`/`invalid`, so a spinner is one `state.isInProgress` check.

A validator that throws, or a pass that times out, is a *failure* — a technical fault, not a verdict on the value. The field lands on `FieldStatus.failedValidation` (`state.isFailedValidation`) instead of hanging on `validating`, it does not count as valid, and `form.value.hasFailedValidation` drives one banner for the whole form. Failure is not sticky, so the next `await validate()` retries it.

Every parameter is documented in the dartdoc on [`AsyncValidation`](https://pub.dev/documentation/advanced_forms/latest/advanced_forms/AsyncValidation-class.html). Working example: `SimpleFormScreen` in the example app.

### Validation that depends on another field

`subscribeToFields` re-runs this field's **sync** validator whenever the fields it depends on change value — that one thing, and nothing at all while this field is in `ValidationMode.manual`, or on a field the user has never edited:

```dart
final password = AdvancedTextFieldController(
  validator: atLeastLength(8, 'Password is too short'),
);

late final repeatPassword = AdvancedTextFieldController(
  validator: (value) =>
      value == password.fieldValue ? null : 'Passwords do not match',
)..subscribeToFields([password]);
```

It does exactly one thing: **re-run this field's sync validator.** It does not copy or derive values. For "when B changes, set A" — recompute a total, mirror one field into another, clear a dependent selection — use the form's `addRelation`:

```dart
addRelation(quantity, (value) => value, (qty) => total.setValue(qty * unitPrice));
```

`addRelation(source, select, onChange)` calls `onChange` whenever the part of `source`'s value picked by `select` changes (compared with `==`; status-only changes never fire). The form removes the listener in its own `dispose()`, so there is nothing to clean up.

Working example: `PasswordFormScreen` in the example app.

## Field controllers

- `AdvancedTextFieldController` — `String` value; owns a `TextEditingController` and a `FocusNode`,
- `AdvancedBooleanFieldController` — `bool` value, for checkboxes and switches,
- `AdvancedSingleSelectFieldController` — one choice from `options` (dropdowns, radio groups),
- `AdvancedMultiSelectFieldController` — a set of choices, with `toggleElement` / `addValue` / `removeValue`.

All support `reset()`, `markReadOnly()` / `unmarkReadOnly()`, and both sync and async validation. The text and boolean controllers default their `initialValue`; the two select controllers require both `initialValue` and `options`. All accept an optional `name`, which labels the field in diagnostics and gives logging or serialization a stable handle. Working example: `ComplexFormScreen` in the example app.

### Reading the current state

The full state is `field.value`, an `AdvancedFieldState<T, E>`. Two shortcuts cover most reads:

```dart
field.fieldValue;   // the current value — short for field.value.value
field.error;        // the current error, or null — short for field.value.error
```

### Read-only fields and server-side errors

```dart
field.markReadOnly();                  // setValue becomes a no-op unless force: true
field.setError(MyError.emailTaken);    // push an error in from outside, e.g. a server response
field.clearErrors();                   // clear everything, including the last async answer
```

`markReadOnly()` freezes the value; how the widget *looks* is yours to decide. Widgets with a nullable callback — `Switch`, `Checkbox`, `DropdownButton` — grey out on their own once `getValueSetter()` returns `null`. A text field does not: `TextField.readOnly` blocks typing but keeps the enabled styling, so pass `enabled: !state.readOnly` too when a frozen field should also look frozen.

`setError(null)` is what makes the "apply the server's response to every field" pattern work: fields the server accepted end up `valid` with nothing to show, rather than `invalid` with nothing to show.

`setError` writes `validationError` only. A code an async check recorded survives it, and the field stays `invalid` showing that code — use `clearErrors()` when you mean "forget everything, including the async answer". A pushed error is also not protected from the validators: once the field validates itself, anything that re-runs its sync validator — an edit, `subscribeToFields`, `validateAll` — overwrites `validationError` with whatever the validator returns.

`reset()` restores the initial value, clears both errors, and makes the field count as untouched again. It **keeps** its validation mode and `readOnly` — those are configuration, and configuration changes only through its own API.

`AdvancedFormController` has `markReadOnly()`, `clearErrors()`, and `setValidationEnabled(bool)` for the whole tree.

Working example: `QuizFormScreen` in the example app applies a server response with `setError`.

### Writing your own

Extend `AdvancedFieldController` — your value type, your error type, your domain methods, with validation and lifecycle contributed by the base class:

```dart
class IntegerFieldController<E extends Object> extends AdvancedFieldController<int, E> {
  IntegerFieldController({
    super.initialValue = 0,
    super.validator,
    super.asyncValidation,
    super.name,
  });

  bool get isNegative => fieldValue.isNegative;

  void negate() => setValue(-fieldValue);
}
```

This is the intended way to use the library. `example/lib/controllers/password_field_controller.dart` is a text field whose error type is `List<ValidationError>`, so one field reports several rule violations at once.

## Subforms

`addSubform` attaches another `AdvancedFormController` as a child, and its fields join the parent's `validate`, `markReadOnly`, `setValidationEnabled`, and the other broadcast operations. Use it for sections that appear dynamically, or to split a large form into readable pieces:

```dart
class BaseFormController extends AdvancedFormController {
  BaseFormController() {
    registerFields([field]);
  }

  final field = AdvancedTextFieldController();
  final subform = SubformController();

  void extendForm() => addSubform(subform);
}
```

`void removeSubform(form)` detaches a subform: it stops validating, notifying and counting towards the parent's state, and can be re-attached later with `addSubform`. It does not dispose it — the parent owns every subform it was ever given and disposes them all in its own `dispose()`, the same way it owns registered fields. So don't dispose subforms yourself; if you do, the parent skips them rather than disposing them twice. Calling `addSubform` with — or on — a disposed controller throws a descriptive `StateError` rather than crashing later, and so do `registerFields`, `setValidationEnabled` and `removeSubform` on one.

Working examples: `DeliveryListFormScreen` (a dynamic list) and `ComplexFormScreen` (swapping one subform for another).

## Reusable field widgets

The package deliberately ships no styled widgets — it gives you what a widget needs to bind to: the text controller, the focus node, the typed state, the error. For the extract-once pattern see the full set in `example/lib/widgets/`, ready to copy and restyle.

---

## 🛠️ Maintained by LeanCode

<div align="center">

  [<img src="https://leancodepublic.blob.core.windows.net/public/wide.png" alt="LeanCode Logo" width="300" />][leancode-landing]

</div>

This package is built with 💙 by **[LeanCode][leancode-landing]**.
We are **top-tier experts** focused on Flutter Enterprise solutions.

### Why LeanCode?

- **Creators of [Patrol][patrol-landing]** – the next-gen testing framework for Flutter.

- **Production-Ready** – We use this package in apps with millions of users.

- **Full-Cycle Product Development** – We take your product from scratch to long-term maintenance.

<div align="center">
  <br />

  **Need help with your Flutter project?**

  [**👉 Hire our team**][leancode-estimate]
  &nbsp;&nbsp;•&nbsp;&nbsp;
  [Check our other packages][leancode-packages]

</div>

Licensed under the [Apache License 2.0](./LICENSE).

[banner-img]: https://raw.githubusercontent.com/leancodepl/advanced_forms/refs/heads/main/doc/banner.png
[license-badge]: https://img.shields.io/github/license/leancodepl/advanced_forms
[license-badge-link]: https://github.com/leancodepl/advanced_forms/blob/main/LICENSE
[leancode-landing]: https://leancode.co/?utm_source=github.com&utm_medium=referral&utm_campaign=advanced-forms
[leancode-estimate]: https://leancode.co/get-estimate?utm_source=github.com&utm_medium=referral&utm_campaign=advanced-forms
[leancode-packages]: https://pub.dev/packages?q=publisher%3Aleancode.co&sort=downloads
[patrol-landing]: https://patrol.leancode.co/?utm_source=github.com&utm_medium=referral&utm_campaign=advanced-forms
