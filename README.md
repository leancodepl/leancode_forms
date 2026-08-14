Forms in Flutter without a framework on top. `leancode_forms` gives you typed field controllers, composable validation, and form-level state tracking.

Fields and forms mix in `ChangeNotifier` and implement `ValueListenable`, both from the Flutter SDK — the only dependencies are `flutter` and `collection`. A field is an `AdvancedFieldController<T, E>`: `T` is your value type, `E` is *your* error type, so errors stay values you can translate, pattern-match, and test.

## Installation

```sh
flutter pub add leancode_forms
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
Column(
  children: [
    _SignupTextField(field: form.firstName, label: 'First name'),
    _SignupTextField(field: form.lastName, label: 'Last name'),
    ElevatedButton(onPressed: form.submit, child: const Text('Submit')),
  ],
)
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

Own the controller wherever you like — it's a `ChangeNotifier`, so a `StatefulWidget` or any DI package works. `ChangeNotifierProvider` from `provider` is one widget (`provider` is used in the snippets below; it is not a dependency of this package).

## Where to next

- [EXAMPLES.md](./EXAMPLES.md) — copy-paste recipes, from a single text field to derived-state listening.
- [MIGRATION.md](./MIGRATION.md) — coming from 0.1.x.
- `example/` — a runnable app where every pattern in these docs has a working screen.

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

Note what's *not* in the snippet: no `TextEditingController` allocation, no `onChanged`, no `initialValue` seeding. `AdvancedTextFieldController` owns its `TextEditingController` (`field.textController`) and keeps it in two-way sync — user input flows into the field state, and programmatic changes (`setValue`, `reset`) flow back into the visible text. It also owns a `FocusNode` (`field.focusNode`), so "jump to the first invalid field" is `field.focus()`.

Rebuilds are granular by construction: each builder subscribes to one field, so a keystroke rebuilds that field's subtree and nothing else. `AdvancedFieldState` is value-equal, so setting a field to the value it already holds notifies nobody.

`builder`'s third parameter is a `child:` you can pass for a subtree that doesn't depend on field state — built once and reused on every rebuild. See [EXAMPLES.md](./EXAMPLES.md#2-using-the-child-optimization), `example/lib/widgets/form_text_field_with_icon.dart`, and the "Optimized Rendering" screen in the example app.

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

`AdvancedFormState` carries `wasModified` (any field changed since `registerFields`), `fields` / `subforms`, and `validationEnabled`. Four members are derived from the fields on every read, so they can never outlive the child that justified them:

| Member | Meaning |
| --- | --- |
| `validating` | An async check is in flight somewhere in the tree |
| `canSubmit` | Every field is `valid` **right now** — a snapshot of *known* errors, so it is true on a quiet form nobody has checked yet. `await form.validate()` is the guarantee |
| `hasFailedValidation` | Some field's async check could not run — it threw or timed out. Drives one form-level banner |
| `validationErrors` | Every error in the form tree, sync or async, keyed by field, for an error summary |

With `provider`, `context.select<SignupFormController, bool>((c) => c.value.validating)` subscribes to one slice.

To react outside a builder, `form.onValuesChanged` and `form.onStatusChanged` are `Listenable`s covering the whole tree, subforms included. Pass a named callback so you can `removeListener` it later.

`AdvancedFormController` takes two optional constructor arguments: `debugName`, a label for logging across nested subforms, and `validateAll` — when true, a change to any field re-runs the **sync** validator on every *other* autovalidating field, which is what you want when fields validate against each other. No async check is restarted: a field whose own value did not change keeps its last answer, so typing starts no async checks. It is the blunt version of `subscribeToFields`, reaching the whole tree instead of the dependencies you name.

## Validation

A validator is a function: value in, error out, `null` means valid.

```dart
typedef Validator<T, E extends Object> = E? Function(T);
```

`E` is whatever type you choose — plain `String`s are fine to start, and a form can switch to an enum or sealed class later, independently of every other form:

```dart
final firstName = AdvancedTextFieldController(
  validator: (value) => value.isEmpty ? 'First name cannot be empty' : null,
);
```

Two rules cover every case:

1. **The gate decides when a round starts.** The gate is `autovalidate`, per field.
2. **A round runs the sync validator first, and the async validator only if sync passed.**

| `autovalidate` | on `setValue` | on `await validate()` |
| --- | --- | --- |
| `false` | Store the value, clear both errors. Nothing runs — a form nobody has submitted runs no async checks | Sync; async only if sync passed |
| `true` | Sync; async only if sync passed (async debounced) | Sync; async only if sync passed (async immediate) |

So you control *when* validators run:

- **On submit** — `await form.validate()` walks every field and subform, runs their async validators too, and returns `false` if anything is invalid. It also turns autovalidate on for all fields, which gives the usual UX: quiet until the first submit, live feedback after. Pass `validate(enableAutovalidate: false)` to check without switching that on.
- **As the user types** — `field.setAutovalidate(true)`, or `form.setAutovalidate(true)` for all of them.

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

- `filled` — rejects null and empty strings, including whitespace-only ones,
- `notLongerThan` / `atLeastLength` — string length bounds,
- `positiveInteger`, `nonNegativeInteger`, `boundedNonNegativeInteger` — integer strings,
- `positiveDecimal`, `nonNegativeDecimal` — decimal strings,
- `exactly` — requires an exact string match,
- `notNull` — rejects null values,
- `notEmpty` — rejects null and empty lists,
- `nothing` — requires an empty string,
- `and` / `or` — combine validators (also available as `&` and `|`),
- `conditionalValidator` — runs a validator only while a condition holds,
- `dynamicValidator` — builds the validator lazily on each run, for parameters that change at runtime.

```dart
final email = AdvancedTextFieldController(
  validator: filled(MyError.required) & atLeastLength(5, MyError.tooShort),
);
```

### Async validation

Some checks live on the server — "is this username taken?". Pass an `asyncValidation`:

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

- **Debouncing** — the validator waits for a pause in typing rather than firing on every keystroke. `validate()` ignores the debounce: a check that is still waiting is run at once.
- **Cancellation** — the value changing, `setError`, `clearErrors`, `reset`, `markReadOnly` and `dispose` all kill a live round. A killed round can never write state again, and its later result is dropped.
- **No wasted calls** — a settled answer is reused while it still describes the value the field holds, so a second submit press on an unchanged form makes no calls. The async validator is treated as a function of its value; a check that depends on state *outside* the value must be invalidated explicitly with `clearErrors()`.
- **Status you can render** — the status walks `pending` → `validating` → `valid`/`invalid`, so a spinner is one `state.isInProgress` check.
- **Submit safety** — `await validate()` waits for the answer rather than reporting the field bad for being busy.

#### When the check itself falls over

An *error* is a code describing what is wrong with the value. A *failure* is the validator throwing, or its round timing out — a technical fault, not a verdict. The two are kept apart:

- The field lands on `FieldStatus.failedValidation` (`state.isFailedValidation`) instead of hanging on `validating`, and it does not count as valid, so `validate()` returns `false`.
- The exception goes to `AsyncValidation.onFailure`, or to `FlutterError.reportError` if you don't pass one.
- `field.lastFailure` carries the exception, its stack trace and whether it timed out, for logs and crash reporting. It is diagnostic only and takes no part in state comparison or rebuilds.
- `form.value.hasFailedValidation` drives one banner for the whole form. Per-field text is opt-in: pass `failureToError` to turn the exception into an error code, which then displays through the normal path.
- Failure is **not sticky**. A failed round records no answer, so the next `await validate()` re-runs it — submit is the retry, and there is no separate API for it.

Only `AdvancedTextFieldController` and `AdvancedBooleanFieldController` accept `asyncValidation`. Working example: `SimpleFormScreen` in the example app.

### Validation that depends on another field

`subscribeToFields` re-runs this field's **sync** validator whenever the fields it depends on change value:

```dart
final password = AdvancedTextFieldController(
  validator: atLeastLength(8, 'Password is too short'),
);

late final repeatPassword = AdvancedTextFieldController(
  validator: (value) =>
      value == password.fieldValue ? null : 'Passwords do not match',
)..subscribeToFields([password]);
```

Status changes on the observed fields — an async validator starting, say — are filtered out, so dependent fields don't churn for nothing. Nothing happens at all while this field's gate is closed. With the gate open `validationError` is rewritten, so an error pushed in with `setError` gives way to whatever the validator now returns.

The async validator is deliberately *not* re-run: this field's own value did not change, so its last answer is still current and no async check is owed.

It does exactly one thing: **re-run this field's sync validator.** It does not copy or derive values. For "when B changes, set A" — recompute a total, mirror one field into another, clear a dependent selection — use `addListener` and `setValue`:

```dart
quantity.addListener(() => total.setValue(quantity.fieldValue * unitPrice));
```

Working example: `PasswordFormScreen` in the example app.

## Field controllers

- `AdvancedTextFieldController` — `String` value; owns a `TextEditingController` and a `FocusNode`,
- `AdvancedBooleanFieldController` — `bool` value, for checkboxes and switches,
- `AdvancedSingleSelectFieldController` — one choice from `options` (dropdowns, radio groups),
- `AdvancedMultiSelectFieldController` — a set of choices, with `toggleElement` / `addValue` / `removeValue`.

All support `reset()`, `markReadOnly()` / `unmarkReadOnly()`, and sync validation. The text and boolean controllers default their `initialValue`; the two select controllers require both `initialValue` and `options`. All accept an optional `name`, which labels the field in diagnostics and gives logging or serialization a stable handle.

### Reading the current state

The full state is `field.value`, an `AdvancedFieldState<T, E>`. Two shortcuts cover most reads:

```dart
field.fieldValue;   // the current value — short for field.value.value
field.error;        // the current error, or null — short for field.value.error
```

### Read-only fields and server-side errors

```dart
field.markReadOnly();          // setValue becomes a no-op
Switch(
  value: state.value,
  onChanged: field.getValueSetter(),   // null while read-only, so the widget disables itself
);

field.setError(MyError.emailTaken);    // push an error in from outside, e.g. a server response
field.setError(null);                  // clear validationError — status follows
field.clearErrors();                   // clear everything, including the last async answer
```

`setError(null)` is what makes the "apply the server's response to every field" pattern work: fields the server accepted end up `valid` with nothing to show, rather than `invalid` with nothing to show.

`setError` writes `validationError` only. A code an async check recorded survives it, and the field stays `invalid` showing that code — use `clearErrors()` when you mean "forget everything, including the async answer". A pushed error is also not protected from the validators: while the field's gate is open, anything that re-runs its sync validator — an edit, `subscribeToFields`, `validateAll` — overwrites `validationError` with whatever the validator returns.

`reset()` restores the initial value and clears both errors. It **keeps** `autovalidate` and `readOnly` — those are configuration, and configuration changes only through its own API.

`AdvancedFormController` has `markReadOnly()`, `clearErrors()`, and `setValidationEnabled(bool)` for the whole tree. `example/lib/screens/quiz_form.dart` uses `setError` for server-returned errors.

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

## Reusable field widgets

The package deliberately ships no styled widgets — it gives you what a widget needs to bind to: the text controller, the focus node, the typed state, the error. For the extract-once pattern see [EXAMPLES.md](./EXAMPLES.md#5-a-reusable-custom-form-widget) and the full set in `example/lib/widgets/`, ready to copy and restyle.

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

`void removeSubform(form, {bool close = true})` detaches a subform and disposes it unless you pass `close: false`. The parent disposes attached subforms in its own `dispose()`, so don't dispose them yourself as well. Calling `addSubform` with — or on — a disposed controller throws a descriptive `StateError` rather than crashing later, and so do `registerFields`, `setValidationEnabled` and `removeSubform` on one.
