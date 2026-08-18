# advanced_forms example app

A gallery app for [`advanced_forms`](https://github.com/leancodepl/advanced_forms/blob/main/README.md): one screen per documented pattern, reachable from the home page. Nearly every pattern named in [README.md](https://github.com/leancodepl/advanced_forms/blob/main/README.md) and [MIGRATION.md](https://github.com/leancodepl/advanced_forms/blob/main/MIGRATION.md) has a working screen here — multi-select fields and read-only fields are the exceptions, documented in [README — Field controllers](https://github.com/leancodepl/advanced_forms/blob/main/README.md#field-controllers) and [README — Read-only fields and server-side errors](https://github.com/leancodepl/advanced_forms/blob/main/README.md#read-only-fields-and-server-side-errors) only.

## How to run

```sh
cd example
flutter pub get
flutter run
```

Any Flutter target works — the app uses no platform plugins.

## Screen guide

| Screen (`lib/screens/`) | Demonstrates | Explained in |
| --- | --- | --- |
| [`simple_form.dart`](https://github.com/leancodepl/advanced_forms/blob/main/example/lib/screens/simple_form.dart) | Submit-time validation, async email check, `timeout` / `failureToError`, the `hasFailedValidation` banner, `canSubmit` on the button | [README — Async validation](https://github.com/leancodepl/advanced_forms/blob/main/README.md#async-validation) |
| [`password_form.dart`](https://github.com/leancodepl/advanced_forms/blob/main/example/lib/screens/password_form.dart) | Cross-field validation via `subscribeToFields`, a per-field validation mode via `setValidationMode`, a custom error type holding several rule violations | [README — Validation that depends on another field](https://github.com/leancodepl/advanced_forms/blob/main/README.md#validation-that-depends-on-another-field) |
| [`optimized_rendering_form.dart`](https://github.com/leancodepl/advanced_forms/blob/main/example/lib/screens/optimized_rendering_form.dart) | Granular rebuilds and the `child:` optimization across three layouts | [README — Rendering fields](https://github.com/leancodepl/advanced_forms/blob/main/README.md#rendering-fields) |
| [`quiz_form.dart`](https://github.com/leancodepl/advanced_forms/blob/main/example/lib/screens/quiz_form.dart) | Applying a server response with `setError` / `setError(null)` | [README — Read-only fields and server-side errors](https://github.com/leancodepl/advanced_forms/blob/main/README.md#read-only-fields-and-server-side-errors) |
| [`complex_form.dart`](https://github.com/leancodepl/advanced_forms/blob/main/example/lib/screens/complex_form.dart) | Single-select dropdowns and swapping the active subform with `addSubform` / `removeSubform` | [README — Field controllers](https://github.com/leancodepl/advanced_forms/blob/main/README.md#field-controllers), [README — Subforms](https://github.com/leancodepl/advanced_forms/blob/main/README.md#subforms) |
| [`delivery_form.dart`](https://github.com/leancodepl/advanced_forms/blob/main/example/lib/screens/delivery_form.dart) | A dynamic list of subforms, validated and disposed by the parent | [README — Subforms](https://github.com/leancodepl/advanced_forms/blob/main/README.md#subforms) |
| [`step_form.dart`](https://github.com/leancodepl/advanced_forms/blob/main/example/lib/screens/step_form.dart) | A multi-page wizard: one subform per page in a `PageView`, the wizard provided above them, `await step.validate()` on Next, the parent's `validate()` on Submit, and a conditional page that `setValidationEnabled(false)` drops from both the flow and the validation | [README — Subforms](https://github.com/leancodepl/advanced_forms/blob/main/README.md#subforms) |
| [`scroll_form.dart`](https://github.com/leancodepl/advanced_forms/blob/main/example/lib/screens/scroll_form.dart) | Scrolling to the first invalid field with `field.focusNode`, plus a plain `Stream` for one-off UI events | [README — Rendering fields](https://github.com/leancodepl/advanced_forms/blob/main/README.md#rendering-fields), [MIGRATION 8](../MIGRATION.md#8-dropping-flutter_bloc-and-friends) |

[`lib/widgets/`](https://github.com/leancodepl/advanced_forms/blob/main/example/lib/widgets/) holds the reusable field widgets referenced from README — text, password, dropdown and switch fields — ready to copy and restyle. [`lib/controllers/password_field_controller.dart`](https://github.com/leancodepl/advanced_forms/blob/main/example/lib/controllers/password_field_controller.dart) is a custom field controller written against `AdvancedTextFieldController`.
