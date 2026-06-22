# Examples

## Using `FieldBuilder` (recommended)

Common form scenarios using `FieldBuilder` — a thin wrapper around `ValueListenableBuilder` that saves typing the `<FieldState<T, E>>` type argument and reads as "build for a field" at call sites.

### 1. A simple text field with an error message

```dart
class _MyError {}

final field = TextFieldController<_MyError>(
  initialValue: '',
  validator: filled(_MyError()),
);

// In the widget tree:
FieldBuilder<String, _MyError>(
  field: field,
  builder: (context, state) {
    return TextFormField(
      controller: field.textController,           // <-- no manual wiring
      decoration: InputDecoration(
        errorText: state.error != null ? 'Required' : null,
      ),
    );
  },
);
```

Note the `controller: field.textController` — `TextFieldController` owns its own `TextEditingController`, kept in two-way sync with the field value. Programmatic resets (`field.reset()`, `field.clear()`) propagate to the visible text automatically.

### 2. A form with submit-time validation

```dart
class SimpleFormController extends FormGroupController {
  SimpleFormController() {
    registerFields([firstName, email]);
  }

  final firstName = TextFieldController(
    initialValue: 'John',
    validator: filled(ValidationError.empty),
  );

  final email = TextFieldController(
    validator: filled(ValidationError.empty),
  );

  void submit() {
    if (validate()) {
      print('First: ${firstName.value.value}');
      print('Email: ${email.value.value}');
    }
  }
}

// Provider (using the `provider` package):
ChangeNotifierProvider<SimpleFormController>(
  create: (_) => SimpleFormController(),
  child: const SimpleForm(),
)

// Inside the SimpleForm widget — context.read is the right call here,
// because we want a stable reference for the onPressed callback (no
// subscription to rebuilds).
ElevatedButton(
  onPressed: () => context.read<SimpleFormController>().submit(),
  child: const Text('Submit'),
)
```

### 3. Async email validation

```dart
class SignupController extends FormGroupController {
  SignupController() {
    registerFields([email]);
  }

  final email = TextFieldController(
    validator: filled(ValidationError.empty),
    asyncValidator: _checkEmail,
    asyncValidationDebounce: const Duration(milliseconds: 500),
  );

  Future<ValidationError?> _checkEmail(String value) async {
    final taken = ['taken@example.com'];
    await Future<void>.delayed(const Duration(milliseconds: 700));
    return taken.contains(value) ? ValidationError.emailTaken : null;
  }
}

// Inside the widget's build method — grab the field once, then close
// over it inside the builder instead of re-fetching from context:
final email = context.read<SignupController>().email;

return FieldBuilder<String, ValidationError>(
  field: email,
  builder: (context, state) => TextFormField(
    controller: email.textController,
    decoration: InputDecoration(
      errorText: state.error?.toString(),
      suffix: state.isValidating
          ? const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(),
            )
          : null,
    ),
  ),
);
```

### 4. Cross-field validation (password / repeat-password)

```dart
class PasswordFormController extends FormGroupController {
  PasswordFormController() {
    registerFields([password, repeatPassword]);
  }

  final password = TextFieldController(
    validator: atLeastLength(8, ValidationError.toShort),
  );

  late final repeatPassword = TextFieldController<ValidationError>(
    validator: (value) =>
        value == password.value.value ? null : ValidationError.doesNotMatch,
  )..subscribeToFields([password]);
}
```

`subscribeToFields` listens to the given fields and re-runs this field's validator whenever any of their values change.

### 5. A reusable custom form widget

Wrap `FieldBuilder` in a `StatelessWidget` to keep call sites tidy across a real app:

```dart
class FormTextField<E extends Object> extends StatelessWidget {
  const FormTextField({
    super.key,
    required this.field,
    required this.translateError,
    this.labelText,
  });

  final TextFieldController<E> field;
  final ErrorTranslator<E> translateError;
  final String? labelText;

  @override
  Widget build(BuildContext context) {
    return FieldBuilder<String, E>(
      field: field,
      builder: (context, state) => TextFormField(
        controller: field.textController,
        decoration: InputDecoration(
          labelText: labelText,
          errorText: state.error != null ? translateError(state.error!) : null,
        ),
      ),
    );
  }
}
```

Call site:
```dart
FormTextField(
  field: controller.email,
  translateError: validatorTranslator,
  labelText: 'Email',
)
```

---

## Using `ValueListenableBuilder` directly

`FieldBuilder` is shorthand. When you want the SDK primitive instead, drop down to `ValueListenableBuilder`. Reasons to reach for it:

- **The `child:` optimization** — keep an expensive subtree out of the rebuild path.
- **No extra import** beyond `flutter/widgets.dart` (`FieldBuilder` adds a dependency on `package:leancode_forms`).
- **Consistency with other notifier-based code** in your codebase.

Trade-off: you have to type the `<FieldState<T, E>>` type argument explicitly.

### 1. A simple text field — explicit form

```dart
ValueListenableBuilder<FieldState<String, _MyError>>(
  valueListenable: field,
  builder: (context, state, _) => TextFormField(
    controller: field.textController,
    decoration: InputDecoration(
      errorText: state.error != null ? 'Required' : null,
    ),
  ),
);
```

Same output as the `FieldBuilder` version. Six extra characters of type argument, one extra `_` for the unused `child` slot.

### 2. Using the `child:` optimization

If part of the subtree is expensive but invariant in the field state, pass it as `child:` so it's built once and reused on every rebuild:

```dart
ValueListenableBuilder<FieldState<String, _MyError>>(
  valueListenable: field,
  child: const _ExpensiveLeadingIcon(),       // built once
  builder: (context, state, child) {
    return Row(
      children: [
        child!,                                 // reused on every rebuild
        Expanded(
          child: TextFormField(
            controller: field.textController,
            decoration: InputDecoration(
              errorText: state.error != null ? 'Required' : null,
            ),
          ),
        ),
      ],
    );
  },
);
```

`FieldBuilder` doesn't expose `child:` (the goal there is brevity, not knobs). If you need this optimization, `ValueListenableBuilder` is the right tool.

### 3. Watching only a derived slice — combine with `ValueListenable` adapters

`FieldController` is a full `ValueListenable<FieldState<T, E>>`. If a part of your UI cares only about, say, `state.isValidating`, you can wrap it once and listen to the derived notifier directly. (Pattern using `ValueListenableBuilder.builder` with a small selector helper.)

```dart
ValueListenableBuilder<FieldState<String, _MyError>>(
  valueListenable: field,
  builder: (context, state, _) {
    // Only this subtree rebuilds; surrounding widgets can subscribe separately.
    if (state.isValidating) {
      return const LinearProgressIndicator();
    }
    if (state.error != null) {
      return Text('Error: ${state.error}', style: const TextStyle(color: Colors.red));
    }
    return const SizedBox.shrink();
  },
);
```

You could of course do the same inside a `FieldBuilder`. The point is that with `ValueListenableBuilder` you stay on SDK types end to end — useful if you're already composing with other `ValueListenable`s elsewhere in the screen (animations, scroll positions, theme observers).

### 4. Listening outside a widget tree

Both `FieldBuilder` and `ValueListenableBuilder` are widgets. If you need to react to changes from a non-widget context (a service, another controller, a `late final` initializer), skip both and use `addListener` directly:

```dart
void _onChange() {
  print('value is now ${field.value.value}, status ${field.value.status}');
}

field.addListener(_onChange);
// later:
field.removeListener(_onChange);
```

Same primitive `FieldBuilder` and `ValueListenableBuilder` use internally — just without the widget plumbing.

---

## When to pick which

| Situation | Use |
| --- | --- |
| Most form widgets | `FieldBuilder` |
| Migrating from 0.1.x code that already used `FieldBuilder` | `FieldBuilder` (just rename the field type) |
| Need the `child:` optimization for a static subtree | `ValueListenableBuilder` |
| Already composing with other `ValueListenable`s on the screen | `ValueListenableBuilder` |
| Reacting outside a widget tree | `field.addListener(...)` directly |

There's no behavioral difference between `FieldBuilder` and `ValueListenableBuilder` — the first is the second wrapped in 30 lines. Pick whichever reads better at the call site.