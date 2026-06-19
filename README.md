A package for creating and managing forms with `ValueNotifier` / `ChangeNotifier`.

## Getting Started

## Installation

```sh
flutter pub add leancode_forms
```

# Usage
Let's go through the basics of the package while explaining some of the key terms/concepts.
    
## Creating a Simple Form

To create a simple form, you need to define a `FormGroupController` that will manage its fields.
Common way to do this is by extending the `FormGroupController` class.

```dart
class SimpleFormController extends FormGroupController {
  SimpleFormController();
}
```

Next, inside the form controller, you define the form fields. You can either use one of the [predefined field controllers](#predefined-field-controllers) or [create a custom `FieldController`](#creating-custom-fieldcontroller). In this simple form, we use `TextFieldController` — the `FieldController` specialization for text inputs.

```dart
class SimpleFormController extends FormGroupController {
  SimpleFormController();

  final firstName = TextFieldController();
  final lastName = TextFieldController();
}
```

**Important:** To make the form manage the defined fields, you should register them via `registerFields()`. The form takes ownership and disposes them when the form itself is disposed.

```dart
class SimpleFormController extends FormGroupController {
  SimpleFormController() {
    registerFields([
      firstName,
      lastName,
    ]);
  }

  final firstName = TextFieldController();
  final lastName = TextFieldController();
}
```

You can provide the controller through any DI mechanism. With the `provider` package:

```dart
class SimpleForm extends StatelessWidget {
  const SimpleForm({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<SimpleFormController>(
      create: (_) => SimpleFormController(),
      child: /* Here the form fields */,
    );
  }
}
```

### Creating widgets for defined fields

Every `FieldController` is a wrapper around the `ValueNotifier<FieldState<T, E>>`, so you can render one with the SDK's `ValueListenableBuilder`:

```dart
final firstName = context.read<SimpleFormController>().firstName;

ValueListenableBuilder<FieldState<String, MyError>>(
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

Or use the shorthand `FieldBuilder` from this package. It is the same thing, but saves typing the `<FieldState<T, E>>` type argument:

```dart
FieldBuilder<String, MyError>(
  field: firstName,
  builder: (context, state) {
    return TextFormField(
      controller: firstName.textController,
      decoration: InputDecoration(
        errorText: state.error != null ? translate(state.error!) : null,
      ),
    );
  },
);
```
`FieldBuilder` is a thin wrapper around `ValueListenableBuilder`. Of course you can use `ValueListenableBuilder` directly when you need the SDK's `child:` optimization for a static subtree. that means, a part of your widget tree that doesn't depend on the field state (e.g. an expensive icon) and shouldn't be rebuilt on every change. `ValueListenableBuilder`'s `child:` parameter lets you build that piece once and reuse the same instance across every rebuild.

```dart
ValueListenableBuilder<FieldState<String, MyError>>(
  valueListenable: firstName,
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

`TextFieldController` owns its own `TextEditingController` (`field.textController`) and keeps it in two-way sync with the field value — user input flows into the field state, and programmatic changes (`setValue`, `reset`, `clear`) flow into the text controller.

### How the field modifications flow

Every `FieldController` is a `ValueListenable<FieldState<T, E>>`. Widgets subscribe to it directly (via `FieldBuilder` or `ValueListenableBuilder`), and only the subscribed subtree rebuilds when the field changes — the parent form widget doesn't need to participate.

The chain for a single keystroke in a text field:

```
user types 'h'
   ↓
TextFormField writes 'h' into field.textController       [Flutter SDK]
   ↓
field.textController.notifyListeners()
   ↓
TextFieldController._onTextControllerChanged             [internal sync]
   ↓ calls setValue('h')
field.value = FieldState(value: 'h', ...)
   ↓
field.notifyListeners()
   ↓
   ├── TextFieldController._onFieldChanged               [internal sync — noop here]
   └── ValueListenableBuilder's listener                 [UI rebuild]
         ↓
       only that one FormTextField's subtree rebuilds
```

Two layers of listeners are alive at all times on a `TextFieldController`:

- **Internal sync layer.** Two listeners set up in `TextFieldController`'s constructor: one keeps the field state in sync with the text buffer (`_onTextControllerChanged`), the other keeps the text buffer in sync with the field state (`_onFieldChanged`). This is how `field.reset()` actually updates the visible text, and how cross-field updates from `subscribeToFields` propagate to the UI.
- **Widget subscription layer.** Each `ValueListenableBuilder` / `FieldBuilder` in the widget tree subscribes independently to the field it cares about. When the field notifies, only that subtree rebuilds — not the rest of the form.

Practical implication for parents: use `context.read<MyFormController>()` to get the controller handle (no subscription, no parent rebuilds), then let each field widget subscribe to its own field on its own. The parent does not need to rebuild on field changes — the leaf widgets do that on their own, granularly.

For form-level state (e.g. a "saving..." indicator that depends on `controller.value.validating`), use `context.select<MyFormController, bool>((c) => c.value.validating)` — that subscribes only to changes in the selected slice, not to every field change in the form.

### Validating simple form fields

Pass a `Validator` to any `FieldController`. A validator takes a value and returns an error (any type you want), or `null` if the value is valid.

```dart
typedef Validator<T, E extends Object> = E? Function(T);
```

There is a set of [ready-to-use validators](#ready-to-use-validators), or you can write your own:

```dart
class SimpleFormController extends FormGroupController {
  SimpleFormController() {
    registerFields([
      firstName,
      lastName,
    ]);
  }

  final firstName = TextFieldController(
    validator: (value) {
      if (value.isEmpty) {
        return 'First name cannot be empty';
      }
      return null;
    },
  );

  final lastName = TextFieldController(
    validator: (value) {
      if (value.isEmpty) {
        return 'Last name cannot be empty';
      }
      return null;
    },
  );
}
```

Call `validate()` on a field to run its sync validator. Set `autovalidate` to `true` to run the validator on every value change.

To validate the whole form, call `validate()` on the form controller. It iterates through every field (and every subform) and returns `false` if any of them is invalid.

```dart
class SimpleFormController extends FormGroupController {
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

## Ready-to-use validators

There is a set of validators ready to use:

- `boundedNonNegativeInteger` — validates if a string represents a non-negative integer that is less than or equal to a specified upper bound,
- `positiveInteger` — validates if a string represents a positive integer (greater than 0),
- `nonNegativeInteger` — validates if a string represents a non-negative integer (greater than or equal to 0),
- `positiveDecimal` — validates if a string represents a positive decimal number (greater than 0),
- `nonNegativeDecimal` — validates if a string represents a non-negative decimal number (greater than or equal to 0),
- `exactly` — validates if a string is exactly equal to a specified string,
- `filled` — rejects null and empty strings (including whitespace-only strings),
- `notLongerThan` — rejects strings longer than a specified maximum length,
- `atLeastLength` — rejects strings shorter than a specified minimum length,
- `notNull` — rejects null values,
- `notEmpty` — rejects null and empty lists,
- `nothing` — matches empty strings and returns an error message if the string is not empty,
- `or` — combines multiple validators with logical OR; passes if at least one accepts,
- `and` — combines multiple validators with logical AND; passes only if all accept.

There are also `&` and `|` extension methods for combining validators with logical AND and OR, respectively.

## Async validators

To validate a field with an asynchronous function, pass an `asyncValidator` to a `FieldController`. An async validator is the same shape as a sync one but returns a `Future`. Async validators do **not** run when you call `validate()`.

### Validator order

If you pass both `validator` and `asyncValidator`, the async one only runs if the sync validator passes (returns null).

### Debouncing the async validator

When `autovalidate` is true, the async validator runs every time the value changes. The `asyncValidationDebounce` (default 300ms) prevents excessive calls while a user is typing.

### Field state during async validation

When async validation is triggered, the field's status transitions: `pending` → `validating` → `valid` / `invalid`. `FieldStatus.pending` covers the debounce window; `FieldStatus.validating` covers the in-flight future. If you call `validate()` on a field whose status is `pending` or `validating`, it returns `false`.

For an example of a form with async validation, see `SimpleFormScreen` in the example app.

## Validation based on another field's value

Sometimes a field's validity depends on another field's value (e.g. "password" vs. "confirm password"). Use `subscribeToFields` on a `FieldController`:

```dart
class PasswordFormController extends FormGroupController {
  PasswordFormController() {
    registerFields([
      password,
      repeatPassword,
    ]);
  }

  final password = TextFieldController(
    validator: atLeastLength(8, 'Password is too short'),
  );

  late final repeatPassword = TextFieldController(
    validator: (value) => value == password.value.value
        ? null
        : 'Passwords do not match',
  )..subscribeToFields([password]);
}
```

Every time the value of the `password` field changes, the `repeatPassword` validator runs (provided `autovalidate` is on). Status changes on the observed fields (e.g. async-validating) are filtered out — only genuine value changes trigger revalidation.

For a fully working example, see `PasswordFormScreen` in the example app.

## `FieldController`

### Predefined field controllers

The package ships with controllers covering the most common field shapes:

- `TextFieldController` — specialization for a `String` value; owns a `TextEditingController`,
- `BooleanFieldController` — specialization for a `bool` value,
- `SingleSelectFieldController` — specialization for a single choice of value from a list of options,
- `MultiSelectFieldController` — specialization for multiple choices from a list of options.

`TextFieldController`, `SingleSelectFieldController` and `MultiSelectFieldController` each expose a `clear()` method that resets the value to the initial one by calling `reset()`. `reset()` is also available on the base `FieldController`.

### Creating a custom `FieldController`

If none of the existing specializations fit, extend `FieldController` directly:

```dart
class IntegerFieldController<E extends Object> extends FieldController<int, E> {
  IntegerFieldController({
    super.initialValue = 0,
    super.validator,
    super.asyncValidator,
    super.asyncValidationDebounce,
    super.name,
  });

  bool get isNegative => value.value.isNegative;

  void negate() => setValue(-value.value);
}
```

## Creating a form field widget

For a one-off field you can just wrap it in `ValueListenableBuilder` inline. When you reuse the same field shape across the app, extract it into a `StatelessWidget`:

```dart
class FormTextField<E extends Object> extends StatelessWidget {
  const FormTextField({
    super.key,
    required this.field,
    required this.translateError,
    this.labelText,
    this.hintText,
  });

  final TextFieldController<E> field;
  final ErrorTranslator<E> translateError;
  final String? labelText;
  final String? hintText;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<FieldState<String, E>>(
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

## Subforms

When a form contains a subform that's dynamically added to the page and affects the overall validation result, `leancode_forms` lets you nest forms. `FormGroupController.addSubform` adds another `FormGroupController` as a child; its fields participate in `validate`, `markReadOnly`, `setValidationEnabled`, and the other broadcast operations. This is also a good way to split a large form into smaller, more readable pieces.

```dart
class BaseFormController extends FormGroupController {
  BaseFormController() {
    registerFields([field]);
  }

  final field = TextFieldController();
  final subform = SubformController();

  /// Adds the subform to the base form.
  void extendForm() {
    addSubform(subform);
  }
}

class SubformController extends FormGroupController {
  SubformController() {
    registerFields([subformField]);
  }

  final subformField = TextFieldController();
}
```
