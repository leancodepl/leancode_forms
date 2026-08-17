# advanced_forms example app

A gallery app for [`advanced_forms`](../README.md): one screen per documented pattern, reachable from the home page. Nearly every pattern named in [README.md](../README.md) and [MIGRATION.md](../MIGRATION.md) has a working screen here — multi-select fields and read-only fields are the exceptions, documented in [README — Field controllers](../README.md#field-controllers) and [README — Read-only fields and server-side errors](../README.md#read-only-fields-and-server-side-errors) only.

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
| [`simple_form.dart`](lib/screens/simple_form.dart) | Submit-time validation, async email check, `timeout` / `failureToError`, the `hasFailedValidation` banner, `canSubmit` on the button | [README — Async validation](../README.md#async-validation) |
| [`password_form.dart`](lib/screens/password_form.dart) | Cross-field validation via `subscribeToFields`, a per-field validation mode via `setValidationMode`, a custom error type holding several rule violations | [README — Validation that depends on another field](../README.md#validation-that-depends-on-another-field) |
| [`optimized_rendering_form.dart`](lib/screens/optimized_rendering_form.dart) | Granular rebuilds and the `child:` optimization across three layouts | [README — Rendering fields](../README.md#rendering-fields) |
| [`quiz_form.dart`](lib/screens/quiz_form.dart) | Applying a server response with `setError` / `setError(null)` | [README — Read-only fields and server-side errors](../README.md#read-only-fields-and-server-side-errors) |
| [`complex_form.dart`](lib/screens/complex_form.dart) | Single-select dropdowns and swapping the active subform with `addSubform` / `removeSubform` | [README — Field controllers](../README.md#field-controllers), [README — Subforms](../README.md#subforms) |
| [`delivery_form.dart`](lib/screens/delivery_form.dart) | A dynamic list of subforms, validated and disposed by the parent | [README — Subforms](../README.md#subforms) |
| [`scroll_form.dart`](lib/screens/scroll_form.dart) | Scrolling to the first invalid field with `field.focusNode`, plus a plain `Stream` for one-off UI events | [README — Rendering fields](../README.md#rendering-fields), [MIGRATION 8](../MIGRATION.md#8-dropping-flutter_bloc-and-friends) |

[`lib/widgets/`](lib/widgets/) holds the reusable field widgets referenced from README — text, password, dropdown and switch fields — ready to copy and restyle. [`lib/controllers/password_field_controller.dart`](lib/controllers/password_field_controller.dart) is a custom field controller written against `AdvancedTextFieldController`.
