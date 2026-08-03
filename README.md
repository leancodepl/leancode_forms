Forms in Flutter without a framework on top. `leancode_forms` gives you typed field controllers, composable validation, and form-level state tracking — built entirely on `ValueNotifier`/`ChangeNotifier` from the Flutter SDK.

## Why this package

Every Flutter app has forms, and every team ends up hand-rolling the same things: keeping `TextEditingController`s in sync with state, deciding when validators run, disabling the submit button while an async check is in flight, remembering to dispose everything. This package is that plumbing, written once and tested — so a new form in your app is a class with some fields in it, not an afternoon of wiring.

What you're signing up for:

- **Nothing but the SDK underneath.** The only dependencies are `flutter` and `collection`. No stream library, no state-management framework, no lock-in — controllers are plain `ChangeNotifier`s, so they compose with bloc, provider, riverpod, hooks, or nothing at all.
- **Opinionated where it saves you time.** Fields own their `TextEditingController` and `FocusNode`. Forms own their fields' lifecycle. Validation has one shape (`value in, error out`). You stop making these decisions per screen.
- **Typed end to end.** A field is an `AdvancedFieldController<T, E>` — `T` is your value type, `E` is *your* error type. Errors are values you can translate, pattern-match, and test, not strings baked into widgets.
- **Small enough to read.** The whole library is a handful of files. When you wonder what `validate()` actually does, the answer is a two-minute read of the source, not an issue tracker archaeology session.

And the mental model fits in three sentences. A **field** is a `ValueNotifier` holding a value plus a validator. A **form** is a group that owns fields and can validate, reset, or dispose them together. **Widgets** subscribe to fields the same way they subscribe to any `ValueListenable`. If you've used `ValueNotifier`, you already know how this package works — everything else is convenience on top.

## Installation

```sh
flutter pub add leancode_forms
```

Migrating from 0.1.x (the bloc-based version)? See [MIGRATION.md](./MIGRATION.md) — for most codebases it's an afternoon of renames.

## Your first form — complete and runnable

Here is an entire working form: two validated fields, bound inputs, and a submit button. No setup beyond the import, no DI package, no custom error types — errors are plain `String`s for now:

```dart
import 'package:flutter/material.dart';
import 'package:leancode_forms/leancode_forms.dart';

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
}

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final form = SignupFormController();

  @override
  void dispose() {
    form.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _SignupTextField(field: form.firstName, label: 'First name'),
          _SignupTextField(field: form.lastName, label: 'Last name'),
          ElevatedButton(
            onPressed: () {
              if (form.validate()) {
                // send it
              }
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }
}

class _SignupTextField extends StatelessWidget {
  const _SignupTextField({required this.field, required this.label});

  final AdvancedTextFieldController<String> field;
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

That's the whole thing — and it's also most of the API surface you'll use day to day. Paste it into a fresh project and it runs: the fields stay quiet while the user types, the first tap on Submit validates everything and turns on live feedback, error texts appear under the right inputs, and disposal is one call because the form owns its fields. Everything else in this README is a variation on this pattern.

Three things in that snippet carry all the weight:

- **The controller is a plain Dart class.** Fields are final members, living next to the logic that uses them, and the whole class is unit-testable without a widget tree.
- **`registerFields()` is the one rule to remember.** The form takes ownership — it disposes fields when it's disposed, tracks whether anything was modified, and includes them in form-wide operations like `validate()` and `resetAll()`. You never write per-field cleanup code.
- **The widget binds with `field.textController`.** No `TextEditingController` allocation, no `onChanged`, no seeding — more on this below.

On a bigger app you'll probably want the controller in the tree instead of a `State` field. It's just a `ChangeNotifier`, so any DI works; with `provider` it's one widget:

```dart
ChangeNotifierProvider<SignupFormController>(
  create: (_) => SignupFormController(),
  child: const SignupForm(),
)
```

## Rendering fields

The quickstart used `AdvancedFieldBuilder`; here's what it's made of, and when to reach for the alternatives. Every `AdvancedFieldController` is a `ValueListenable<AdvancedFieldState<T, E>>`, so the SDK's own `ValueListenableBuilder` renders one with no adapter:

```dart
final firstName = context.read<SignupFormController>().firstName;

ValueListenableBuilder<AdvancedFieldState<String, MyError>>(
  valueListenable: firstName,
  builder: (context, state, _) {
    return TextFormField(
      controller: firstName.textController,
      decoration: InputDecoration(
        errorText: state.error != null ? translate(state.error!) : null,
      ),
    );
  },
);
```

Or use `AdvancedFieldBuilder` from this package — the same thing, minus typing the `<AdvancedFieldState<T, E>>` argument at every call site:

```dart
AdvancedFieldBuilder<String, MyError>(
  field: firstName,
  builder: (context, state, _) {
    return TextFormField(
      controller: firstName.textController,
      decoration: InputDecoration(
        errorText: state.error != null ? translate(state.error!) : null,
      ),
    );
  },
);
```

Notice what's *not* in these snippets: no `TextEditingController` allocation, no `onChanged` callback, no `initialValue` seeding. `AdvancedTextFieldController` owns its `TextEditingController` (`field.textController`) and keeps it in two-way sync — user input flows into the field state, and programmatic changes (`setValue`, `reset`) flow back into the visible text. It also owns a `FocusNode` (`field.focusNode`), so "jump to the first invalid field" is `field.focus()` instead of focus-management plumbing in your widgets.

### Skipping rebuilds for static subtrees

Both `AdvancedFieldBuilder` and `ValueListenableBuilder` accept a `child:` — a subtree that doesn't depend on the field state and shouldn't be rebuilt on every keystroke (an expensive icon, an image, a chart). Build it once, reuse it forever:

```dart
AdvancedFieldBuilder<String, MyError>(
  field: firstName,
  child: const Icon(Icons.email),                       // built once
  builder: (context, state, child) => Row(
    children: [
      child!,                                            // reused on every rebuild
      const SizedBox(width: 8),
      Expanded(
        child: TextFormField(
          controller: firstName.textController,
          decoration: InputDecoration(
            errorText: state.error != null ? translate(state.error!) : null,
          ),
        ),
      ),
    ],
  ),
);
```

See `example/lib/widgets/form_text_field_with_icon.dart` for the widget, and `example/lib/screens/optimized_rendering_form.dart` for a runnable screen that uses it (accessible from the example app's home page under "Optimized Rendering").

### How a change actually flows

Rebuilds are granular by construction: each widget subscribes to exactly the field it renders, so a keystroke rebuilds one text field's subtree — not the form, not its parent. The full chain for a single keystroke:

```
user types 'h'
   ↓
TextFormField writes 'h' into field.textController       [Flutter SDK]
   ↓
field.textController.notifyListeners()
   ↓
AdvancedTextFieldController._onTextControllerChanged             [internal sync]
   ↓ calls setValue('h')
field.value = AdvancedFieldState(value: 'h', ...)
   ↓
field.notifyListeners()
   ↓
   ├── AdvancedTextFieldController._onFieldChanged               [internal sync — noop here]
   └── ValueListenableBuilder's listener                 [UI rebuild]
         ↓
       only that one FormTextField's subtree rebuilds
```

Two layers of listeners are alive at all times on an `AdvancedTextFieldController`:

- **Internal sync layer.** Two listeners set up in the constructor: one keeps the field state in sync with the text buffer, the other keeps the text buffer in sync with the field state. This is how `field.reset()` actually updates the visible text, and how cross-field updates propagate to the UI.
- **Widget subscription layer.** Each `AdvancedFieldBuilder` / `ValueListenableBuilder` subscribes independently to the field it cares about. When the field notifies, only that subtree rebuilds.

Practical implication for parent widgets: grab the controller with `context.read<MyFormController>()` (no subscription, no parent rebuilds) and let each field widget subscribe to its own field. For form-level state — say, a "saving…" indicator driven by `controller.value.validating` — use `context.select<MyFormController, bool>((c) => c.value.validating)`, which subscribes to just that slice.

One more thing you get for free: `AdvancedFieldState` is value-equal, so setting a field to the value it already has notifies nobody. No defensive `distinct()` logic on your side.

## Validation

A validator is a function: value in, error out, `null` means valid. That's the entire contract — no schema DSL, no annotations, no builder:

```dart
typedef Validator<T, E extends Object> = E? Function(T);
```

`E` is whatever type you choose, and plain `String`s — like the quickstart uses — are perfectly fine:

```dart
final firstName = AdvancedTextFieldController(
  validator: (value) {
    if (value.isEmpty) {
      return 'First name cannot be empty';
    }
    return null;
  },
);
```

When a form grows enough to need translated or structured errors, switch that form's `E` to an enum or a sealed class and pattern-match in the widget. Nothing forces the decision upfront, and each form makes it independently.

You control *when* validators run:

- **On submit** — call `validate()` on the form; it walks every field (and subform) and returns `false` if anything is invalid.
- **As the user types** — enable `autovalidate` on a field and its validator runs on every change. `AdvancedFormController.validate()` turns autovalidate on for all fields by default, which gives you the common UX for free: quiet until the first submit, live feedback after.

```dart
class SignupFormController extends AdvancedFormController {
  /* fields */

  void submit() {
    if (validate()) {
      print('Form is valid');
    } else {
      print('Form is invalid!');
    }
  }
}
```

Note the form-level result is just a `bool` — "may this submit proceed?". The actual errors stay on the fields, right where the widgets that display them are subscribed. If you need them all in one place (e.g. an error summary), `controller.value.validationErrors` collects them across the whole form tree.

### Ready-to-use validators

The common cases ship with the package, so you don't rewrite "required field" for the nth time:

- `filled` — rejects null and empty strings (including whitespace-only strings),
- `notLongerThan` / `atLeastLength` — string length bounds,
- `positiveInteger`, `nonNegativeInteger`, `boundedNonNegativeInteger` — integer strings,
- `positiveDecimal`, `nonNegativeDecimal` — decimal strings,
- `exactly` — requires an exact string match,
- `notNull` — rejects null values,
- `notEmpty` — rejects null and empty lists,
- `nothing` — requires an empty string,
- `and` / `or` — combine validators (also available as `&` and `|` operators),
- `conditionalValidator` — runs a validator only while a condition holds,
- `dynamicValidator` — builds the validator lazily on each run, for parameters that change at runtime.

```dart
final email = AdvancedTextFieldController(
  validator: filled(MyError.required) & atLeastLength(5, MyError.tooShort),
);
```

### Async validation

Some checks live on the server — "is this username taken?". Pass an `asyncValidator` (same shape, returns a `Future`) and the field handles the whole dance:

- **Debouncing** — the validator doesn't fire on every keystroke; it waits for a pause in typing (`asyncValidationDebounce`, default 300ms, tune per field).
- **Cancellation** — if the value changes while a check is in flight, the stale result is discarded. No out-of-order responses overwriting fresh state.
- **Status you can render** — the field's status walks through `pending` → `validating` → `valid`/`invalid`, so a spinner next to the field is one `state.isInProgress` check.
- **Submit safety** — `validate()` returns `false` while an async check is unresolved, so you can't accidentally submit a form whose validity is still unknown.

If a field has both a sync and an async validator, the async one only runs once the sync one passes — no point asking the server about an empty string.

For a working example, see `SimpleFormScreen` in the example app.

### Validation that depends on another field

The classic: "repeat password" must match "password". Call `subscribeToFields` and the field revalidates whenever the fields it depends on change value:

```dart
class PasswordFormController extends AdvancedFormController {
  PasswordFormController() {
    registerFields([
      password,
      repeatPassword,
    ]);
  }

  final password = AdvancedTextFieldController(
    validator: atLeastLength(8, 'Password is too short'),
  );

  late final repeatPassword = AdvancedTextFieldController(
    validator: (value) => value == password.fieldValue
        ? null
        : 'Passwords do not match',
  )..subscribeToFields([password]);
}
```

Revalidation kicks in once `autovalidate` is on (which `AdvancedFormController.validate()` enables on first submit). Status changes on the observed fields (e.g. an async validator running) are filtered out — only genuine value changes trigger revalidation, so dependent fields don't churn for nothing.

`subscribeToFields` does exactly one thing: **it re-runs this field's validator.** It does *not* copy or derive values — if you need "when field B changes, update field A's value" (recompute a total, mirror one field into another, clear a dependent selection), `subscribeToFields` won't do it. Reach for a plain `addListener` on the source field and call `setValue` on the target yourself:

```dart
// Update `total` whenever `quantity` changes — a value dependency, not a validation one.
quantity.addListener(() {
  total.setValue(quantity.fieldValue * unitPrice);
});
```

For a fully working example, see `PasswordFormScreen` in the example app.

## Field controllers

### What ships in the box

- `AdvancedTextFieldController` — `String` value; owns a `TextEditingController` and a `FocusNode`,
- `AdvancedBooleanFieldController` — `bool` value, for checkboxes and switches,
- `AdvancedSingleSelectFieldController` — one choice from a list of `options` (dropdowns, radio groups),
- `AdvancedMultiSelectFieldController` — a set of choices, with `toggleElement` / `addValue` / `removeValue` helpers.

All of them support `reset()` (back to the initial value), `markReadOnly()` / `unmarkReadOnly()`, and sync validation; `AdvancedTextFieldController` and `AdvancedBooleanFieldController` also take an `asyncValidator`. All accept an optional `name`, which shows up in logs and `FocusNode` debug labels — worth setting on forms big enough to make "which field is misbehaving?" a real question.

### Reading the current state

The full state lives under `value` (a `AdvancedFieldState<T, E>`), but the two things you reach for constantly have shortcuts:

```dart
field.fieldValue;   // the current value — short for field.value.value
field.error;        // the current error, or null — short for field.value.error
```

Use these in your controller logic; they read the way `state.value` used to if you're coming from the bloc version.

### Writing your own

When the built-ins don't fit, extend `AdvancedFieldController` directly. Your value type, your error type, your domain methods — the base class contributes validation, state management, and lifecycle:

```dart
class IntegerFieldController<E extends Object> extends AdvancedFieldController<int, E> {
  IntegerFieldController({
    super.initialValue = 0,
    super.validator,
    super.asyncValidator,
    super.asyncValidationDebounce,
    super.name,
  });

  bool get isNegative => fieldValue.isNegative;

  void negate() => setValue(-fieldValue);
}
```

This is the intended way to use the library, not an escape hatch — real apps end up with `MoneyFieldController`, `PhoneNumberFieldController`, `QuantityFieldController`, each a small class that's trivial to unit-test. For a richer example (record-valued field, custom error hierarchy, server-side errors), see [MIGRATION.md, section 9](./MIGRATION.md#9-migrating-a-rich-custom-field).

## Reusable field widgets

For a one-off field, an inline `AdvancedFieldBuilder` is fine. When the same field shape repeats across the app, extract it once:

```dart
class FormTextField<E extends Object> extends StatelessWidget {
  const FormTextField({
    super.key,
    required this.field,
    required this.translateError,
    this.labelText,
    this.hintText,
  });

  final AdvancedTextFieldController<E> field;
  final ErrorTranslator<E> translateError;
  final String? labelText;
  final String? hintText;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AdvancedFieldState<String, E>>(
      valueListenable: field,
      builder: (context, state, _) => TextFormField(
        controller: field.textController,
        decoration: InputDecoration(
          labelText: labelText,
          hintText: hintText,
          errorText: state.error != null ? translateError(state.error!) : null,
        ),
      ),
    );
  }
}
```

The package deliberately ships no styled widgets — every project has its own design system, and a forms library shouldn't fight it. What it gives you instead is everything a widget needs to bind to: the text controller, the focus node, the typed state, the error. The `example/` app has a full set of these widgets you can copy and restyle.

## Subforms

Forms nest. `addSubform` attaches another `AdvancedFormController` as a child, and its fields join the parent's `validate`, `markReadOnly`, `setValidationEnabled`, and the other broadcast operations. Use it for parts of a form that appear dynamically (an "add invoice data" section behind a checkbox), or simply to split a large form into readable pieces:

```dart
class BaseFormController extends AdvancedFormController {
  BaseFormController() {
    registerFields([field]);
  }

  final field = AdvancedTextFieldController();
  final subform = SubformController();

  /// Adds the subform to the base form.
  void extendForm() {
    addSubform(subform);
  }
}

class SubformController extends AdvancedFormController {
  SubformController() {
    registerFields([subformField]);
  }

  final subformField = AdvancedTextFieldController();
}
```

`removeSubform` detaches (and by default disposes) a subform. And if you call `addSubform` on a disposed controller — or pass a disposed form in — you get a descriptive `StateError` right away, instead of a use-after-dispose crash to bisect later.

## Where to next

- [EXAMPLES.md](./EXAMPLES.md) — copy-paste recipes for the common scenarios, from a single text field to derived-state listening.
- [MIGRATION.md](./MIGRATION.md) — coming from the 0.1.x bloc-based version? Start here.
- `example/` — a runnable app where every pattern in these docs has a working screen.
