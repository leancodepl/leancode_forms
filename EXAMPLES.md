# Examples

## Using `AdvancedFieldBuilder` (recommended)

Common form scenarios using `AdvancedFieldBuilder` — a thin wrapper around `ValueListenableBuilder` that saves typing the `<AdvancedFieldState<T, E>>` type argument and reads as "build for a field" at call sites.

### 1. A simple text field with an error message

```dart
class _MyError {}

final field = AdvancedTextFieldController<_MyError>(
  initialValue: '',
  validator: filled(_MyError()),
);

// In the widget tree:
AdvancedFieldBuilder<String, _MyError>(
  field: field,
  builder: (context, state, _) {
    return TextFormField(
      controller: field.textController,           // <-- no manual wiring
      decoration: InputDecoration(
        errorText: state.error != null ? 'Required' : null,
      ),
    );
  },
);
```

Note the `controller: field.textController` — `AdvancedTextFieldController` owns its own `TextEditingController`, kept in two-way sync with the field value. Programmatic changes (`field.reset()`, `field.setValue(...)`) propagate to the visible text automatically.

### 2. A form with submit-time validation

```dart
class SimpleFormController extends AdvancedFormController {
  SimpleFormController() {
    registerFields([firstName, email]);
  }

  final firstName = AdvancedTextFieldController(
    initialValue: 'John',
    validator: filled(ValidationError.empty),
  );

  final email = AdvancedTextFieldController(
    validator: filled(ValidationError.empty),
  );

  Future<void> submit() async {
    if (await validate()) {
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
class SignupController extends AdvancedFormController {
  SignupController() {
    registerFields([email]);
  }

  final email = AdvancedTextFieldController(
    validator: filled(ValidationError.empty),
    asyncValidation: AsyncValidation(
      validator: _checkEmail,
      debounce: const Duration(milliseconds: 500),
    ),
  );

  Future<ValidationError?> _checkEmail(String value) async {
    final taken = ['taken@example.com'];
    await Future<void>.delayed(const Duration(milliseconds: 700));
    return taken.contains(value) ? ValidationError.emailTaken : null;
  }
}

// Let's select field reference
final email = context.select<SignupController, AdvancedTextFieldController<ValidationError>>(
  (c) => c.email,
);

return AdvancedFieldBuilder<String, ValidationError>(
  field: email,
  builder: (context, state, _) => TextFormField(
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
class PasswordFormController extends AdvancedFormController {
  PasswordFormController() {
    registerFields([password, repeatPassword]);
  }

  final password = AdvancedTextFieldController(
    validator: atLeastLength(8, ValidationError.toShort),
  );

  late final repeatPassword = AdvancedTextFieldController<ValidationError>(
    validator: (value) =>
        value == password.value.value ? null : ValidationError.doesNotMatch,
  )..subscribeToFields([password]);
}
```

`subscribeToFields` listens to the given fields and re-runs this field's **sync** validator whenever any of their values change. The async validator is not re-run: this field's own value did not change, so its last answer is still current. It only revalidates — it does not update this field's *value* in response to another field. For a value dependency ("when B changes, set A"), use the form's `addRelation(source, select, onChange)` — it fires when the selected part of `source`'s value changes and is cleaned up when the form is disposed.

### 5. A reusable custom form widget

Wrap `AdvancedFieldBuilder` in a `StatelessWidget` to keep call sites tidy across a real app:

```dart
class FormTextField<E extends Object> extends StatelessWidget {
  const FormTextField({
    super.key,
    required this.field,
    required this.translateError,
    this.labelText,
  });

  final AdvancedTextFieldController<E> field;
  final ErrorTranslator<E> translateError;
  final String? labelText;

  @override
  Widget build(BuildContext context) {
    return AdvancedFieldBuilder<String, E>(
      field: field,
      builder: (context, state, _) => TextFormField(
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

`AdvancedFieldBuilder` is shorthand. When you want the SDK primitive instead, drop down to `ValueListenableBuilder`. Reasons to reach for it:

- **No extra import** beyond `flutter/widgets.dart` (`AdvancedFieldBuilder` adds a dependency on `package:leancode_forms`).
- **Consistency with other notifier-based code** in your codebase.

Trade-off: you have to type the `<AdvancedFieldState<T, E>>` type argument explicitly.

### 1. A simple text field — explicit form

```dart
ValueListenableBuilder<AdvancedFieldState<String, _MyError>>(
  valueListenable: field,
  builder: (context, state, _) => TextFormField(
    controller: field.textController,
    decoration: InputDecoration(
      errorText: state.error != null ? 'Required' : null,
    ),
  ),
);
```

Same output as the `AdvancedFieldBuilder` version — the only difference is the spelled-out type argument.

### 2. Using the `child:` optimization

If part of the subtree is expensive but invariant in the field state, pass it as `child:` so it's built once and reused on every rebuild:

```dart
ValueListenableBuilder<AdvancedFieldState<String, _MyError>>(
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

`AdvancedFieldBuilder` forwards `child:` to `ValueListenableBuilder`, so the same optimization works there too — pick whichever reads better.

### 3. Watching only a derived slice — combine with `ValueListenable` adapters

`AdvancedFieldController` is a full `ValueListenable<AdvancedFieldState<T, E>>`. If a part of your UI cares only about, say, `state.isValidating`, you can wrap it once and listen to the derived notifier directly. (Pattern using `ValueListenableBuilder.builder` with a small selector helper.)

```dart
ValueListenableBuilder<AdvancedFieldState<String, _MyError>>(
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

You could of course do the same inside an `AdvancedFieldBuilder`. The point is that with `ValueListenableBuilder` you stay on SDK types end to end — useful if you're already composing with other `ValueListenable`s elsewhere in the screen (animations, scroll positions, theme observers).

### 4. Listening outside a widget tree

Both `AdvancedFieldBuilder` and `ValueListenableBuilder` are widgets. If you need to react to changes from a non-widget context (a service, another controller, a `late final` initializer), skip both and use `addListener` directly:

```dart
void _onChange() {
  print('value is now ${field.value.value}, status ${field.value.status}');
}

field.addListener(_onChange);
// later:
field.removeListener(_onChange);
```

Same primitive `AdvancedFieldBuilder` and `ValueListenableBuilder` use internally — just without the widget plumbing.

Coming from 0.1.x and its cubit streams? The deprecated `stream` helper bridges the gap while you migrate — see [Migrating a custom field](./MIGRATION.md#9-migrating-a-custom-field) in the migration guide.

---

## When to pick which

| Situation | Use |
| --- | --- |
| Most form widgets | `AdvancedFieldBuilder` |
| Migrating from 0.1.x code that used `FieldBuilder` | `AdvancedFieldBuilder` (rename, add `, _` to the builder) |
| Need the `child:` optimization for a static subtree | Either — both expose `child:` |
| Already composing with other `ValueListenable`s on the screen | `ValueListenableBuilder` |
| Reacting outside a widget tree | `field.addListener(...)` directly |

There's no behavioral difference between `AdvancedFieldBuilder` and `ValueListenableBuilder` — the first is the second wrapped in 30 lines. Pick whichever reads better at the call site.