# Examples

Side-by-side snippets showing the same form scenario in three flavors:

1. **0.1.x (pre-migration)** — built on `flutter_bloc` + `rxdart`
2. **0.2.0 with `FieldBuilder`** — the recommended default; tiny wrapper around `ValueListenableBuilder`
3. **0.2.0 with `ValueListenableBuilder`** directly — for cases where you want the SDK primitive (e.g. the `child:` optimization)

For a step-by-step migration walkthrough see [MIGRATION.md](./MIGRATION.md).

---

## 0.1.x — pre-migration (BLoC-based)

> These examples won't compile against 0.2.0. They're here so you can recognize your old code and find the matching new-shape example below.

### 1. A simple text field with an error message

```dart
class _MyError {}

final field = TextFieldCubit<_MyError>(
  initialValue: '',
  validator: filled(_MyError()),
);

// In the widget tree:
FieldBuilder<String, _MyError>(
  field: field,
  builder: (context, state) {
    return TextFormField(
      onChanged: field.getValueSetter(),
      decoration: InputDecoration(
        errorText: state.error != null ? 'Required' : null,
      ),
    );
  },
);
```

### 2. A form with submit-time validation

```dart
class SimpleFormCubit extends FormGroupCubit {
  SimpleFormCubit() {
    registerFields([firstName, email]);
  }

  final firstName = TextFieldCubit(
    initialValue: 'John',
    validator: filled(ValidationError.empty),
  );

  final email = TextFieldCubit(
    validator: filled(ValidationError.empty),
  );

  void submit() {
    if (validate()) {
      print('First: ${firstName.state.value}');
      print('Email: ${email.state.value}');
    }
  }
}

// Provider:
BlocProvider<SimpleFormCubit>(
  create: (_) => SimpleFormCubit(),
  child: const SimpleForm(),
)

// Inside the widget tree:
context.read<SimpleFormCubit>().submit();
```

### 3. Async email validation

```dart
class SignupCubit extends FormGroupCubit {
  SignupCubit() {
    registerFields([email]);
  }

  final email = TextFieldCubit(
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

// Render:
FieldBuilder<String, ValidationError>(
  field: context.read<SignupCubit>().email,
  builder: (context, state) => TextFormField(
    onChanged: context.read<SignupCubit>().email.getValueSetter(),
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
)
```

### 4. Cross-field validation (password / repeat-password)

```dart
class PasswordFormCubit extends FormGroupCubit {
  PasswordFormCubit() {
    registerFields([password, repeatPassword]);
  }

  final password = TextFieldCubit(
    validator: atLeastLength(8, ValidationError.toShort),
  );

  late final repeatPassword = TextFieldCubit<ValidationError>(
    validator: (value) =>
        value == password.state.value ? null : ValidationError.doesNotMatch,
  )..subscribeToFields([password]);
}
```

---

## 0.2.0 — using `FieldBuilder` (recommended)

Same scenarios as above, ported to the new API. `FieldBuilder` is a thin wrapper around `ValueListenableBuilder` — it saves typing the `<FieldState<T, E>>` type argument, and keeps your widget code looking almost identical to the 0.1.x version.

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

Note the `controller: field.textController` — `TextFieldController` owns its own `TextEditingController` now, kept in two-way sync with the field value. No `onChanged: field.setValue` needed; programmatic resets (`field.reset()`, `field.clear()`) propagate to the visible text automatically.

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

// Inside the widget tree:
context.read<SimpleFormController>().submit();
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

// Render:
FieldBuilder<String, ValidationError>(
  field: context.read<SignupController>().email,
  builder: (context, state) => TextFormField(
    controller: context.read<SignupController>().email.textController,
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
)
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

`subscribeToFields` works exactly as before — only the implementation underneath changed (no more `rxdart`).

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

## 0.2.0 — using `ValueListenableBuilder` directly

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