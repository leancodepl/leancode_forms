## 0.2.0

> Upgrading from 0.1.x? See [MIGRATION.md](./MIGRATION.md) for a step-by-step guide.

### Breaking changes

* Minimum Flutter is now 3.13.0 (was 3.10.0).
* Rebuilt on `ChangeNotifier` / `ValueListenable`, so `flutter_bloc` and `rxdart` are no longer dependencies.
* Renamed the core classes:
  * `FieldCubit` → `AdvancedFieldController`
  * `TextFieldCubit` → `AdvancedTextFieldController`
  * `BooleanFieldCubit` → `AdvancedBooleanFieldController`
  * `SingleSelectFieldCubit` → `AdvancedSingleSelectFieldController`
  * `MultiSelectFieldCubit` → `AdvancedMultiSelectFieldController`
  * `FormGroupCubit` → `AdvancedFormController`
  * `FieldState` → `AdvancedFieldState`
  * `FormGroupState` → `AdvancedFormState`
  * `FieldBuilder` → `AdvancedFieldBuilder`
* Renamed `close()` to `dispose()` on both controllers, and removed the `Disposable` mixin.
* `AdvancedFieldBuilder` wraps `ValueListenableBuilder` instead of `BlocBuilder`, so `builder` is a `ValueWidgetBuilder` and takes a third `child` parameter. `ValueListenableBuilder` works directly too.
* Replaced `asyncValidator` and `asyncValidationDebounce` with `asyncValidation: AsyncValidation(validator:, debounce:, timeout:, onFailure:, failureToError:)`.
* `validate()` returns `Future<bool>` on both controllers and now runs the async validators. **Await it.**
* `autovalidate` is replaced by a named validation mode. `ValidationMode` has three members — `disabled` (the default), `onUserInteraction` (what `autovalidate: true` did) and the new `onUnfocus`. Set it on `AdvancedFormController` through the constructor or `setValidationMode`, and it reaches every field and subform in the tree, including ones registered or attached later. `AdvancedFieldState.autovalidate` becomes `AdvancedFieldState.mode`, and `setAutovalidate(bool)` becomes `setValidationMode(ValidationMode)` on both controllers.
* `validate()` no longer turns validation on and lost its `enableAutovalidate` parameter on both controllers. The mode you set is the mode the form keeps for its whole life, which is what makes a subform attached after the first submit behave exactly like one attached at build time.
* In every mode, a field the user has never edited validates nothing on its own — not on its own change, not when a field it depends on changes, and not on losing focus. `await form.validate()` still checks those, so a bad prefilled value cannot get through. Use the new `field.prefill(value)` for a value the user did not type: it stores the value and clears the errors without making the field count as edited.
* `form.validateWithAutovalidate()` is renamed to `form.revalidateSync()`, matching the field method it broadcasts.
* `setValidationEnabled(false)` now reaches subforms, and a switched-off subtree stops counting entirely: its fields validate nothing, and they are excluded from `canSubmit`, `validating`, `hasFailedValidation` and `validationErrors` as well as from `validate()`. It composes with a parent's switch by AND, so a section that opted out stays out.
* `reset()` keeps the validation mode and `readOnly`, and makes the field count as untouched again. Previously `form.resetAll()` unlocked fields your code had locked, and undid the autovalidate that `form.validate()` turned on.
* `setError(null)` clears `validationError` and the status follows, instead of leaving the field `invalid` with nothing to show. It leaves `asyncError` alone — use `clearErrors()` for both.
* An error never outlives the value it described: changing the value clears both errors, and so does starting a check.
* `removeSubform` returns `void` — drop the `await`.
* A disposed controller throws a `StateError` from `registerFields`, `setValidationEnabled`, `addSubform`, `removeSubform` and `subscribeToFields`.
* `FieldStatus` has a new `failedValidation` value, for a check that could not run. Exhaustive `switch`es need an arm for it.
* `AdvancedFormState.validationErrors` reports each field's `error` (sync **or** async) instead of `validationError`.
* `select` and `addValue` assert that the value is one of `options`, and so does `toggleElement` when it adds.
* `onValuesChangedStream` / `onStatusChangedStream` are now the `Listenable`s `onValuesChanged` / `onStatusChanged`. `onStatusChanged` carries no payload.
* Removed `clear()` from the text, single-select, and multi-select controllers — call `reset()`.

### Added

* `AsyncValidation.timeout` bounds how long a check may run (default: no bound), and `AsyncValidation.failureToError` turns a failed check into a displayable error code.
* `AdvancedFieldController.lastFailure` carries the exception, its stack trace, and whether the check timed out.
* `AdvancedFormState.canSubmit` and `AdvancedFormState.hasFailedValidation` report submit readiness and failed checks across the whole form.
* The single-select and multi-select controllers accept `asyncValidation`, which they could not before.
* `AdvancedTextFieldController` owns a `TextEditingController` (`field.textController`) kept in two-way sync with the value. Every `AdvancedFieldController` owns a `FocusNode` (`field.focusNode`) with a `focus()` shortcut, so a dropdown or a date picker gets one too — not just text fields.
* `AdvancedFieldController` gained an optional `String? name` for debugging, logging, and serialization.
* `AdvancedFieldController.revalidateSync()` re-runs the sync validator when the field validates itself, for custom cross-field wiring.
* `ValidationMode.onUnfocus` validates a field when the user leaves it. Leaving flushes a debounce in any mode; a value unchanged since its last check reuses that answer, so repeated focus cycles cost no requests, and a check that failed is retried. Bind the field's `focusNode` for it to fire, or call `field.handleUnfocus()` from a widget that manages focus itself, such as a picker.
* A field may opt out of its form's mode with `field.setValidationMode(...)`, and a subform with its own mode — from its constructor or its setter — keeps it. A later change of the parent's mode reaches every other child. `validationEnabled` still outranks every mode.

### Changed

* Cross-field checks re-run the **sync** validator only, both through `subscribeToFields` and through `validateAll: true`.
* A settled async answer is reused while it still describes the value, so a second submit press on an unchanged form runs no async validators.

### Fixed

* An async result arriving late no longer overwrites a newer value, nor undoes `reset()`, `clearErrors()`, `setError()` or `setValidationEnabled(false)`.
* A validator that throws before its first `await` no longer leaves the field stuck on `validating` forever.
* `markReadOnly()` stops a running check, and removing a subform mid-check no longer leaves the form stuck reporting `validating`.
* `addSubform` and `removeSubform` recompute `wasModified`, so a removed subform no longer latches the parent as modified.
* Text typed into a read-only text field is reverted immediately.

### Deprecated

* `AdvancedFieldController.stream` replaces the `stream` that `FieldCubit` inherited from `Cubit`. It ships deprecated and is removed in 0.3.0 — use `addListener`, `subscribeToFields`, or the builder widgets.

## 0.1.2

* Bumped `bloc` to `^9.0.0`.

## 0.1.1

* Bumped `rxdart` to `^0.28.0`.

## 0.1.0

* Documented the public API in README.md.

## 0.0.1

* Initial version of the library.
