---
name: leancode-forms
description: Build Flutter forms with the leancode_forms package (AdvancedFormController, AdvancedTextFieldController, AdvancedFieldBuilder). Use whenever the user creates a form, adds or edits form fields, wires validation (sync, async, or cross-field), builds dropdowns/checkboxes/multi-selects/sliders bound to field controllers, handles submit buttons or server-side errors, or works with subforms in a project that depends on leancode_forms — even if they never say the word "form".
---

# leancode_forms

Typed form controllers for Flutter, no framework on top. Everything is `ChangeNotifier` + `ValueListenable` from the SDK. One import: `package:leancode_forms/leancode_forms.dart`.

The model in one paragraph: a **form controller** (`AdvancedFormController`) owns **field controllers** (`AdvancedFieldController<T, E>`). `T` is the value type, `E` is *your* error type (`E extends Object`, never nullable — `null` means "no error"). Plain `String` errors are fine; an enum or sealed class scales better. Widgets subscribe to one field each via `AdvancedFieldBuilder`; the form aggregates tree-wide state (modified, validating, errors).

Snippets below assume in scope: `MyError`, your error enum; `form`, a form controller; `translate`, an `ErrorTranslator<MyError>`.

## Quick start — a complete form

```dart
import 'package:leancode_forms/leancode_forms.dart';

enum SignupError { required, tooShort }

class SignupFormController extends AdvancedFormController {
  SignupFormController() {
    registerFields([email, password]);
  }

  final email = AdvancedTextFieldController(
    validator: filled(SignupError.required),
  );

  final password = AdvancedTextFieldController(
    validator: filled(SignupError.required) &
        atLeastLength(8, SignupError.tooShort),
  );

  Future<bool> submit() async {
    if (!await validate()) {
      return false;
    }
    // values were checked — safe to send: email.fieldValue, password.fieldValue
    return true;
  }
}
```

```dart
// Widget side. In SignupScreen.build:
final form = context.read<SignupFormController>();
Column(
  children: [
    _SignupField(field: form.email, label: 'Email'),
    _SignupField(field: form.password, label: 'Password'),
    ElevatedButton(
      onPressed: () async {
        await form.submit(); // async: await it, never pass a bare VoidCallback
      },
      child: const Text('Sign up'),
    ),
  ],
)

class _SignupField extends StatelessWidget {
  const _SignupField({required this.field, required this.label});

  final AdvancedTextFieldController<SignupError> field;
  final String label;

  @override
  Widget build(BuildContext context) {
    return AdvancedFieldBuilder<String, SignupError>(
      field: field,
      builder: (context, state, _) => TextFormField(
        controller: field.textController, // NEVER your own TextEditingController
        focusNode: field.focusNode,
        readOnly: state.readOnly, // add enabled: !state.readOnly to also look disabled
        decoration: InputDecoration(
          labelText: label,
          errorText: switch (state.error) {
            SignupError.required => 'This field is required',
            SignupError.tooShort => 'At least 8 characters',
            null => null,
          },
        ),
      ),
    );
  }
}
```

Default UX out of the box: fields stay quiet until the first `validate()` (usually the submit), then give live feedback on every edit.

Two rules prevent most bugs. **Call `registerFields()` once, in the constructor, with every field** (the parameter is `List<AdvancedFieldController<dynamic, dynamic>>`, so mixed value types go in one list) — the form then owns their lifecycle (disposal, `wasModified` tracking, `validate()`, `resetAll()`...), and a second call *replaces* the list, so earlier fields stop participating though they are still disposed with the form. **Bind text widgets to `field.textController`** — the field owns a `TextEditingController` and a `FocusNode` and keeps them in two-way sync, so do not allocate your own and do not wire `onChanged` + `initialValue` for text fields.

## Field controllers

| Controller | Value type | Constructor and notes |
| --- | --- | --- |
| `AdvancedTextFieldController<E>` | `String` | `{initialValue = '', validator, asyncValidation, name}`; owns `textController` + `focusNode`, has `focus()` |
| `AdvancedBooleanFieldController<E>` | `bool` | `{initialValue = false, validator, asyncValidation, name}` |
| `AdvancedSingleSelectFieldController<V, E>` | `V?` | `{required V? initialValue, required List<V> options, validator, asyncValidation, name}`; set with `select(V? option)`, `null` clears |
| `AdvancedMultiSelectFieldController<V, E>` | `Set<V>` | `{required Set<V> initialValue, required List<V> options, validator, asyncValidation, name}`; set with `toggleElement` / `addValue` / `removeValue` |

`name` labels the field in error reports and as the `FocusNode` debug label. All support `reset()`, `markReadOnly()` / `unmarkReadOnly()`, `setError()`, `clearErrors()`, `setAutovalidate()`, `getValueSetter()` (a `ValueSetter<T>?` — `null` while read-only, so a widget with a nullable `onChanged` disables itself), `validate()`, `subscribeToFields()`.

- `options` is a **non-nullable** `List<V>`; only `initialValue` is nullable, on the single select. A required dropdown is `initialValue: null` plus `validator: notNull(MyError.required)`.
- `select(option)` and `addValue(value)` **assert** the argument is one of `options` — a debug crash for a value built outside the list.
- With no `validator`, `E` infers to its bound `Object`. That compiles and then breaks every `switch` on your error enum, so spell it out: `AdvancedTextFieldController<MyError>()`.
- Need something else? `AdvancedFieldController<T, E>` is **concrete** — construct it directly for any value with no controller of its own, a slider, a stepper, a rating or a derived total: `AdvancedFieldController<int, MyError>(initialValue: 0, name: 'total')`, whose full constructor is `{required T initialValue, Validator<T, E>? validator, AsyncValidation<T, E>? asyncValidation, String? name}`. It validates like any other field, and ordinary user writes need no `force:` — that is only for writing to a field you have marked read-only. Extend it, forwarding those, only when you want domain methods on top of `void setValue(T newValue, {bool force = false})`. To transform the text the user types (normalize, mask, uppercase), extend `AdvancedTextFieldController<E>` and override `setValue` — the supported way:

```dart
class PhoneFieldController extends AdvancedTextFieldController<MyError> {
  PhoneFieldController({
    String initialValue = '',
    super.validator, // super-parameters forward the rest unchanged
  }) : super(initialValue: _digits(initialValue));

  static String _digits(String value) => value.replaceAll(RegExp(r'\D'), '');

  @override
  void setValue(String newValue, {bool force = false}) =>
      super.setValue(_digits(newValue), force: force);
}
```

Why it works: every write to `textController` — keystroke, paste or programmatic `.text =` — goes through the public `setValue`, so the override always runs, and the transformed value is written back into `textController` in the same turn with the caret kept on the same characters. Normalize `initialValue` before it reaches `super`, as above — `reset()` returns to *that* value without passing through `setValue`. Named super-parameters mix freely with the explicit `super(...)` call that carries the normalized value, so forward everything you do not transform as `super.validator`, `super.asyncValidation`, `super.name`. The subclass may stay generic — `class PhoneFieldController<E extends Object> extends AdvancedTextFieldController<E>` — which is what a reusable field widget wants.

### Field state — `AdvancedFieldState<T, E>`

`AdvancedFieldBuilder` hands you this; `field.value` **is** this state object, `field.fieldValue` the value inside it. State is value-equal, so a no-op write notifies nobody.

| Member | Meaning |
| --- | --- |
| `value` | the current value — `field.fieldValue` is the shortcut |
| `error` | `validationError ?? asyncError` — `field.error` is the shortcut |
| `validationError` / `asyncError` | what the sync path (validator or `setError`) / the async round recorded |
| `status` | `FieldStatus.valid` \| `invalid` \| `pending` \| `validating` \| `failedValidation` |
| `isValid` / `isInvalid` | status is `valid` / `invalid` |
| `isPending` / `isValidating` / `isInProgress` | waiting out the debounce / request in flight / either |
| `isFailedValidation` | the async validator threw or timed out |
| `readOnly` | `setValue` is a no-op (pass `force: true` to override) |
| `autovalidate` | the gate — whether a value change runs the validators |

`state.autovalidate` is the only "has this been validated at least once" signal, because `validate()` turns it on across the tree. There is **no** form-level "was submitted" flag; keep your own bool if you need one.

## Binding widgets

`AdvancedFieldBuilder<T, E>` wraps `ValueListenableBuilder` and rebuilds only when its own field notifies, so a keystroke rebuilds one subtree. Its third builder parameter is a `child:` passthrough — pass a subtree that does not depend on field state and it is built once.

Type arguments match the controller: `<String, E>` for text, `<bool, E>` for boolean, `<V?, E>` for single select, `<Set<V>, E>` for multi select. Null the callback while `state.readOnly` — `getValueSetter()` returns null for exactly that, so use it wherever the callback is a `ValueSetter<T>?`, and `state.readOnly ? null : …` where it is not. A scalar field binds the same way: `Slider(value: state.value.toDouble(), onChanged: setter == null ? null : (v) => setter(v.round()))`, wrapped in an `InputDecorator` when it needs `errorText`.

```dart
// Checkbox — CheckboxListTile.onChanged is ValueChanged<bool?>?, so adapt the setter.
// SwitchListTile: its onChanged is exactly ValueSetter<bool>?, so pass getValueSetter() straight in.
// No errorText here: render state.error yourself, or wrap in an InputDecorator.
AdvancedFieldBuilder<bool, MyError>(
  field: form.acceptTerms,
  builder: (context, state, _) {
    final setter = form.acceptTerms.getValueSetter();
    return CheckboxListTile(
      value: state.value,
      onChanged: setter == null ? null : (v) => setter(v ?? false),
      title: const Text('Accept terms'),
      subtitle: state.error == null ? null : const Text('Required'),
    );
  },
)

// Multi-select chips — no errorText here; wrap the Wrap in the InputDecorator shown below
AdvancedFieldBuilder<Set<Topping>, MyError>(
  field: form.toppings,
  builder: (context, state, _) => Wrap(
    children: [
      for (final option in form.toppings.options)
        FilterChip(
          label: Text(option.name),
          selected: state.value.contains(option),
          onSelected:
              state.readOnly ? null : (_) => form.toppings.toggleElement(option),
        ),
    ],
  ),
)

// Dropdown — DropdownButton in an InputDecorator compiles on every Flutter version
AdvancedFieldBuilder<Country?, MyError>(
  field: form.country,
  builder: (context, state, _) {
    final error = state.error; // promote E? to E: ErrorTranslator takes a non-null E
    return InputDecorator(
      decoration: InputDecoration(
        errorText: error == null ? null : translate(error),
      ),
      child: DropdownButton<Country>(
        value: state.value,
        isExpanded: true,
        items: [
          for (final option in form.country.options)
            DropdownMenuItem(value: option, child: Text(option.name)),
        ],
        onChanged: state.readOnly ? null : form.country.select,
      ),
    );
  },
)
```

`ErrorTranslator<E>` is `String Function(E)` from the package — a plain function, so write it wherever the labels belong: `String translate(MyError e) => switch (e) { MyError.required => 'Required', MyError.tooShort => 'Too short', … };`. One shared translator per error enum is the cheapest start, but the same code often wants different wording per field ("Required" vs. "Pick a country"), so pass a field-specific translator where it reads better — the widget takes the function, not the enum. It takes a **non-null** `E` while `state.error` is `E?`, so promote before calling it, as above. In a real app wrap each binding once in a reusable widget taking `field` + `ErrorTranslator<E> translateError` and call it everywhere; a generic select wrapper binds `AdvancedFieldBuilder<V?, E>` over `AdvancedSingleSelectFieldController<V, E>`.

If you reach for `DropdownButtonFormField` instead, its selected-value parameter is `value:` up to Flutter 3.33 and `initialValue:` from 3.35 on, where `value:` is deprecated — check the project's SDK first. The package floor is `flutter: >=3.13.0`.

## Validation

A validator is a function: value in, error code out, `null` means valid.

```dart
typedef Validator<T, E extends Object> = E? Function(T);
```

When validators run — two rules:

1. **The gate decides when a round starts.** The gate is `autovalidate`, per field, off by default. `field.setAutovalidate(true)` / `form.setAutovalidate(true)` opens it early; flipping it validates nothing by itself, so the form still starts quiet, unmodified and error-free.
2. **A round runs the sync validator first; the async validator only if sync passed.**

| `autovalidate` | on `setValue` (user edits) | on `await validate()` |
| --- | --- | --- |
| `false` (default) | stores value, clears errors, runs nothing | sync; async only if sync passed |
| `true` | sync; async if sync passed (debounced) | sync; async if sync passed (immediate) |

- **Submit**: `await form.validate()` validates every field and subform, returns `false` if anything is invalid, and switches autovalidate on everywhere (→ live feedback after the first submit). Opt out with `validate(enableAutovalidate: false)`. Double-tapping submit is safe — a second call joins the first, it does not start a second pass.
- **Always `await validate()` before using the values.** `state.isValid` / `form.value.canSubmit` mean "no error recorded *right now*" — a field nobody checked yet counts as valid. A passing `validate()` is also what licenses a `!` on a nullable field value.

### Built-in validators

Every string validator is typed `Validator<String?, E>`, even though `AdvancedTextFieldController` holds a non-nullable `String`. Assigning one to `validator:` is fine; **combining** is where it bites (see below).

| Validator | `T` | Rejects |
| --- | --- | --- |
| `filled(e)` | `String?` | null, empty, whitespace-only |
| `notLongerThan(max, e)` | `String?` | `length > max` — `max` itself passes, null passes |
| `atLeastLength(min, e)` | `String?` | null, `length < min` — `min` itself passes |
| `exactly(s, e)` | `String?` | anything not equal to `s` |
| `nothing(e)` | `String?` | any non-empty string |
| `positiveInteger(e)` / `nonNegativeInteger(e)` | `String?` | null, non-numeric, and `<= 0` / `< 0` after `int.tryParse` |
| `positiveDecimal(e)` / `nonNegativeDecimal(e)` | `String?` | the same with `double.tryParse` |
| `boundedNonNegativeInteger(max, e)` | `String?` | anything but `0..max` or the literal string `>max` |
| `notNull(e)` | `T?` (any) | null |
| `notEmpty(e)` | `List<T>?` | null, empty list |

`conditionalValidator(v, () => enabled)` runs `v` only while the getter returns true; `dynamicValidator(() => buildValidator())` rebuilds the validator on each call. Both keep `T`.

**There is no bool validator, and `notEmpty` does not fit a `Set`.** Write a closure:

```dart
validator: (value) => value ? null : MyError.mustAccept,        // bool field
validator: (value) => value.isEmpty ? MyError.pickOne : null,   // Set<V> field
```

Combine with `&` (all must pass) and `|` (one must pass), or `and([...])` / `or([...])`, which take an optional shared error code as their second argument. `&` short-circuits — the right side runs only if the left passes — and the left-most error wins, in both operators. Both sides must have the **same `T`**, so write custom string closures over `String?` — an unannotated `(value) => ...` infers `String` and will not combine:

```dart
validator: filled(MyError.required) &
    ((String? value) =>
        (value?.contains('@') ?? false) ? null : MyError.invalidEmail),
```

Do not wrap the fields in Flutter's `Form` — you need no `Form`, no `GlobalKey<FormState>` and no `autovalidateMode`; this package *is* the validation system, and a second one fights it. (A `TextFormField` outside a `Form` is fine — unregistered, it is a `TextField` with a decoration.)

## Async validation

For checks that live on the server ("is this username taken?"). Every field controller takes `asyncValidation`, selects included. A verdict your own save call returns is not this — push it with `setError` (see *Server errors*).

```dart
late final username = AdvancedTextFieldController(
  validator: filled(MyError.required),
  asyncValidation: AsyncValidation<String, MyError>( // arity is <T, E>
    validator: (value) async =>          // Future<MyError?> Function(String)
        await api.isTaken(value) ? MyError.taken : null,
    debounce: const Duration(milliseconds: 500), // default 300ms
    timeout: const Duration(seconds: 5), // default: unbounded; bounds the validator run, not the debounce
    failureToError: (e, s) => MyError.checkFailed, // E? Function(Object, StackTrace) — per-field text
    onFailure: (e, s) async => log(e), // Future<void> Function(Object, StackTrace) — omit it and the failure goes to FlutterError.reportError; a throw from onFailure or failureToError is reported there too, never rethrown
  ),
)..setAutovalidate(true); // see "live before the first submit" below
```

What you get without extra code:

- **Debounced while typing**, immediate on `validate()`.
- **Cancellation**: a value change kills the in-flight round; a stale answer can never land.
- **No wasted calls**: a settled answer is reused while the value is unchanged — a second submit on an untouched form makes no network calls. Any `setValue` drops that answer, so an edit always re-checks. If the check depends on state *outside* the value, invalidate with `field.clearErrors()`.
- **Renderable status**: `state.isPending` (waiting out debounce), `state.isValidating` (request running), `state.isInProgress` (either) — a spinner is one check: `suffixIcon: state.isInProgress ? const Padding(padding: EdgeInsets.all(12), child: SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))) : null`. The `Padding` keeps it inside `suffixIcon`'s box.
- **Submit waits**: `await form.validate()` waits for the answer instead of failing a busy field.

**Live before the first submit.** The gate is closed by default, so `setValue` runs *nothing* — no check, no spinner — until the first `validate()`. When the task asks for a live availability check, open the gate at construction with `..setAutovalidate(true)` as above. The price: every settled keystroke starts one debounced round.

**Optional async check.** `conditionalValidator` is sync-only and `AsyncValidation` has no skip flag, so guard inside the async validator itself — `validator: (value) async => value.trim().isEmpty ? null : await api.isTaken(value) ? MyError.taken : null`. The round still starts (the field shows `validating` for a tick) but makes no network call.

**Failure ≠ error.** The validator *throwing* (or timing out) is a technical fault, not a verdict: the field lands on `FieldStatus.failedValidation`, does not count as valid, and `validate()` returns `false`. `form.value.hasFailedValidation` drives one "could not verify, try again" banner. Supplying `failureToError` maps the fault to an error code **and keeps** the field on `failedValidation`, so the per-field text and the banner show together — they are independent. Omit it when the banner is all you want: a failed round then carries no error code and no per-field text appears. Failure is not sticky — the next `validate()` retries, so submit is the retry button. `field.lastFailure` is the diagnostic detail behind that status — an `AsyncValidationFailure?` (`error`, `stackTrace`, `timedOut`), non-null only while the field is on `failedValidation`.

## Cross-field logic

**Rule depends on another field** (repeat-password): `subscribeToFields` re-runs *this* field's **sync** validator when the listed fields' values change. Use `late final` because the closure references a sibling — or an instance field, such as an injected `api`:

```dart
final password = AdvancedTextFieldController(
  validator: atLeastLength(8, MyError.tooShort),
);

late final repeatPassword = AdvancedTextFieldController<MyError>(
  validator: (value) =>
      value == password.fieldValue ? null : MyError.doesNotMatch,
)..subscribeToFields([password]);
```

It deliberately does *not* re-run async validators (the field's own value did not change — no network call owed) and does nothing while the field's gate is closed. To make the cross-check live before the first submit, chain `..setAutovalidate(true)` after `..subscribeToFields([password])`. Like `registerFields`, a second `subscribeToFields` call **replaces** the previous subscription.

**Two fields watching each other** — one rule spanning a pair, where either field can break it or fix it. Say a booking form has `adults` and `children` counts and the rule is "book at least one person", so editing either field must re-check both. Wire them in the **constructor body**, after `registerFields`, and never in a cascade — `adults.subscribeToFields([children]); children.subscribeToFields([adults]);`. A cascade `..subscribeToFields([sibling])` inside a `late final` initializer evaluates the sibling **eagerly**, so a mutual pair **stack-overflows at construction**; a mutually-referencing `late final` pair also needs an **explicit type** (`late final AdvancedTextFieldController<MyError> adults = ...`) or the analyzer reports `top_level_cycle`. No loop results — the subscription re-runs only when a watched **value** changes, not when a sibling's error or status changes. An error only appears on a field whose **own** validator returns it, so the pair's rule goes in **both** validators; the subscriptions are only what re-runs them. `validateAll: true` is the blunt alternative — it replaces the subscriptions, not the duplication.

**Value depends on another field** ("when B changes, set A" — totals, mirroring, clearing a dependent selection): use `addListener` + `setValue`, e.g. `quantity.addListener(() => total.setValue((int.tryParse(quantity.fieldValue) ?? 0) * unitPrice, force: true));` with `total` an `AdvancedFieldController<int, MyError>` — a text field's `fieldValue` is a `String`, and `String * int` compiles in Dart and repeats the string. A derived field is usually a display field you `markReadOnly()`, and `setValue` on a read-only field is a **no-op**, so pass `force: true` as above. Seed it **before** `registerFields`, or give it the derived `initialValue:` — seeding it afterwards captures the baseline at the stale value, and `wasModified` is then true before the user touches anything. Unlike `subscribeToFields`, `addListener` fires on **any** state change of the source (a gate flip, an error appearing), not only on a value change — which is why the derivation must be idempotent, and why mutual subscriptions cannot loop. A *destructive* one — `city.select(null)` when `country` changes — must first compare the source against the value it last saw, or the `setAutovalidate` sweep inside `validate()` wipes the user's choice on submit. Attaching or detaching subforms and calling `setValidationEnabled` from such a listener is supported too.

**Everything depends on everything**: pass `validateAll: true` up to the superclass — `MyForm() : super(validateAll: true)` — and any **value** change re-runs the sync validator on every open-gated field in the tree. Blunt but correct when most fields cross-validate. `debugName` is the superclass's other argument: a label for your own logging, never read by the package.

## Form-level state and the submit button

The form is a `ValueListenable<AdvancedFormState>`:

```dart
ValueListenableBuilder<AdvancedFormState>(
  valueListenable: form,
  builder: (context, state, _) => ElevatedButton(
    onPressed: state.validating
        ? null
        : () async {
            final ok = await form.submit();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'Saved' : 'Fix the errors above')));
            }
          },
    child: state.validating
        ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator())
        : const Text('Submit'),
  ),
)
```

**Do not gate a validate-on-submit button on `canSubmit`.** It is false while any round is pending or validating, and false while a field sits in `failedValidation` — so the button dies exactly when the user needs to retry, and the "submit is the retry button" promise breaks. Gate on nothing, or on `!state.validating`; add `state.wasModified` only when the task asks for "disabled until modified".

**A submit request in flight is yours to track.** `validating` covers async *validators* only; the package knows nothing about your network call. Keep your own flag (a `ValueNotifier<bool>` on the controller) and set it **before** `await validate()`, the first await in a submit, or a double tap sends two requests. Subclassing the form controller for this is fine: `notifyListeners()` is callable and `dispose()` is overridable — dispose your own objects first, then call `super.dispose()` last.

| Member | Meaning |
| --- | --- |
| `wasModified` | any field differs from its value at `registerFields` time, or a subform was modified |
| `canSubmit` | every field in the tree is `valid` *right now* — a snapshot of known errors, never a replacement for `await validate()` |
| `validating` | an async round is pending or in flight somewhere in the tree |
| `hasFailedValidation` | some async check threw or timed out — drive one form-level banner |
| `validationErrors` | every current error keyed by field controller; the values are `dynamic`, so cast to `E` for an error summary |
| `validationEnabled` | false → this form's `validate()` returns `true` without running |
| `fields` / `subforms` / `allFields` | this form's fields / attached subforms / both — an `Iterable<AdvancedFieldController<dynamic, dynamic>>`: own fields in `registerFields` order, then each subform's, recursively |

With provider, subscribe to one slice: `context.select<SignupFormController, bool>((c) => c.value.validating)`. Outside widgets, `form.onValuesChanged` / `form.onStatusChanged` are `Listenable`s covering the whole tree, subforms included.

Focus the first broken field after a failed submit — as a method on the form controller:

```dart
Future<void> submitAndFocus() async {
  if (await validate()) {
    return;
  }
  for (final field in value.allFields) {
    if (!field.value.isValid && field is AdvancedTextFieldController<MyError>) {
      field.focus();
      return;
    }
  }
}
```

Only `AdvancedTextFieldController` has `focus()` and `focusNode`; dropdowns, checkboxes and multi-selects have no focus node, so scroll to or highlight those yourself. `focus()` is a safe no-op on a disposed controller, but reading `focusNode` on one **throws** a `StateError` — never touch `focusNode` from a widget that can outlive its form.

## Server errors, read-only, reset

```dart
field.setError(MyError.emailTaken); // push an error in (e.g. from a 422 response)
field.setError(null);               // clear it — status follows
field.clearErrors();                // forget everything, incl. the async verdict
field.markReadOnly();               // setValue becomes a no-op; validate() still works
field.reset();                      // back to initialValue; clears both errors, the async verdict and
                                    // lastFailure, so the next validate() re-checks. Works read-only
                                    // (that guard is in setValue); keeps readOnly + autovalidate — config
form.markReadOnly(); form.clearErrors(); form.resetAll(); // whole tree
form.setValidationEnabled(false);   // validate() returns true, errors cleared
form..resetAll()..setAutovalidate(false);
```

Push server errors **after** the `await`, never before: `validate()` and anything else that re-runs the sync validator (an edit on an open gate, `subscribeToFields`, `validateAll`) overwrites a pushed code — `validate()` does it whatever the gate says. That is also why a rejection clears itself on the next submit or the next edit, with no bookkeeping. `setError` writes the *sync* slot only; a code recorded by an async round survives it — use `clearErrors()` to wipe both. Applying a server response to every field works because `setError(null)` leaves accepted fields cleanly valid. A map over mixed field types is `Map<String, AdvancedFieldController<dynamic, MyError>>` — spell `E` out, inference widens it to `Object`.

`hasFailedValidation` clears on any `setValue`, `clearErrors()`, `reset()`, `setError(null)`, or the next `validate()`. `markReadOnly()` is the exception: it keeps the `failedValidation` status, so a frozen field can go on blocking submit.

## Subforms

Split big forms, or attach sections that appear dynamically. Subform fields join the parent's `validate`, `markReadOnly`, `resetAll`, `wasModified` and the rest — but **only while attached**.

### Optional section that is toggled — keep it attached, disable validation

Prefer this. The subform stays in the tree, so `resetAll`, `markReadOnly`, `clearErrors`, `setAutovalidate` and `dispose()` all still reach it, and no ownership changes hands.

```dart
class CheckoutFormController extends AdvancedFormController {
  CheckoutFormController() {
    registerFields([email, sameAsBilling]);
    addSubform(shipping);
    sameAsBilling.addListener(
      () => setShippingEnabled(!sameAsBilling.fieldValue),
    );
    setShippingEnabled(!sameAsBilling.fieldValue); // seed it: listeners fire on change only
  }

  final email = AdvancedTextFieldController(validator: filled(MyError.required));
  final sameAsBilling = AdvancedBooleanFieldController<MyError>();
  final shipping = ShippingFormController(); // another AdvancedFormController

  void setShippingEnabled(bool enabled) {
    if (enabled) {
      shipping.setAutovalidate(false);
    }
    shipping.setValidationEnabled(enabled);
  }
}
```

`validationEnabled` starts `true` and only `setValidationEnabled` ever writes it — `resetAll()` leaves it alone — so seed the gate at construction and again in whatever method calls `resetAll()`, or a section that should start off blocks the first submit. `setValidationEnabled(true)` re-runs the sync validators at once. A *disabled* form's own `validate()` leaves the gates as it found them, but a parent's `validate()` sweeps `setAutovalidate(true)` across the whole tree, and that sweep never consults `validationEnabled` — so gates still open inside a disabled subform even though nothing runs there. Without the `setAutovalidate(false)` above, the re-enabled section flashes errors on untouched fields. The setter is idempotent, so it needs no last-seen-value guard even though `validate()`'s sweep re-enters it — the same sweep re-opens the gates straight after.

A disabled subform's `validate()` returns `true` without running anything, and its errors were cleared when you disabled it, so it cannot block submit. It is **not** removed from the aggregates: its fields still count toward `canSubmit`, `validating`, `hasFailedValidation` and `wasModified`, so an error pushed in with `setError` (or written by `validateAll: true`) still blocks a `canSubmit`-gated button.

### Section that genuinely appears and disappears — attach and detach

```dart
void enableGift() => addSubform(gift);
void disableGift() => removeSubform(gift); // close: true by default — `gift` is disposed
```

- `close: true` (the default) disposes the subform, so build a fresh one per appearance; adding a disposed controller back throws a `StateError`. Reuse one controller across appearances with `close: false` — that hands ownership back to you, and the parent disposes only subforms still attached, so your own `dispose()` must dispose it while it is detached.
- A detached subform is out of reach of `validate`, `resetAll`, `markReadOnly`, `clearErrors` and `setAutovalidate`.
- A subform attached *after* the first `validate()` has closed gates; call `sub.setAutovalidate(true)` on attach if that section should also give live feedback.
- `addSubform` is a no-op when already attached and `removeSubform` when not, so a toggle needs no bookkeeping flag.

## Lifecycle and ownership

- The form disposes every field passed to `registerFields` and every **attached** subform. **Never dispose those yourself.** You dispose only the form.
- Any ownership works because the controller is a `ChangeNotifier`: `ChangeNotifierProvider(create: (_) => MyFormController())` disposes it for you; in a `StatefulWidget`, dispose it in `State.dispose`.
- Get the controller in widgets with `context.read` (actions, stable references) and subscribe with `AdvancedFieldBuilder` / `ValueListenableBuilder` / `context.select` (rebuilds).
- `registerFields`, `addSubform`, `removeSubform`, `setValidationEnabled` and `subscribeToFields` throw a `StateError` on a disposed controller — `registerFields` also when any field in the list is disposed. `validate()` does not — it returns `false`, so a submit after teardown fails quietly.

**Prefilled / edit forms.** `wasModified` is baselined at `registerFields` time. A controller that registers fields in its constructor and *then* loads server data reports `wasModified: true` forever, so a "disabled until modified" button is live from the start. Either build the field controllers with the loaded data as `initialValue:`, or re-call `registerFields(sameList)` once the data arrives to re-baseline. Re-baselining does not move `reset()` — that always returns to the constructor's `initialValue`, so after a re-baseline `resetAll()` lands off the baseline and flips `wasModified` back to true. Prefer the `initialValue:` route whenever the form has a discard button.
