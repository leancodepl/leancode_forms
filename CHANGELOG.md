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
* Replaced the `autovalidate` bool with `ValidationMode`, a named choice set once on the form: `disabled` (the default — nothing validates until submit), `onUserInteraction` (every edit validates the field being edited), `onUnfocus` (leaving an edited field validates it). Pass it to `AdvancedFormController(validationMode:)` or set it with `setValidationMode`; it reaches every leaf field and subform, including ones attached later. `setAutovalidate` is gone on both controllers, and `AdvancedFieldState.autovalidate` is now `AdvancedFieldState.mode`.
* `validate()` no longer escalates. It takes no parameters, never reads the mode and never changes it, so a form behaves the same before and after the first submit. Previously the first submit turned autovalidate on across the tree — and missed any subform attached afterwards, so one form could behave two ways. Call `form.setValidationMode(ValidationMode.onUserInteraction)` in your submit handler to keep the old UX.
* In every mode, a field the user has never edited validates nothing on its own — not on its own change, not on a dependency's change, and not on unfocus. `validate()` still checks it, so nothing gets through.
* `focusNode` and `focus()` moved up from `AdvancedTextFieldController` to `AdvancedFieldController`, so every field type has one. Existing code keeps compiling.
* `form.setValidationEnabled(bool)` reaches subforms, AND-ed down the tree, so a section that switched itself off stays off when its parent switches back on. It previously set the flag on the receiving form only, while the README claimed it applied to the whole tree.
* `form.validate()` on a subtree with `validationEnabled: false` skips that subtree's own fields rather than short-circuiting to `true` — the same fields `canSubmit` leaves out, so the two can no longer disagree.
* `form.validateWithAutovalidate()` is renamed to `form.revalidateSync()`, matching the field method of the same name. It was named after a bool that no longer exists.
* `reset()` keeps the validation mode and `readOnly`, and makes the field untouched again.
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
* `AdvancedTextFieldController` owns a `TextEditingController` (`field.textController`) kept in two-way sync with the value, and a `FocusNode` (`field.focusNode`) with a `focus()` shortcut.
* `AdvancedFieldController` gained an optional `String? name` for debugging, logging, and serialization.
* `AdvancedFieldController.revalidateSync()` re-runs the sync validator when the field's gate is open, for custom cross-field wiring; `AdvancedFormController.revalidateSync()` does the same across a whole tree.
* `AdvancedFieldController.prefill(value)`, a programmatic write that stores the value and clears the errors without counting as an edit. Use it for a value fetched from a server or a restored draft.
* `ValidationMode.onUnfocus`, and with it `AdvancedFieldController.handleUnfocus()`. Bind `field.focusNode` in your widget and the field validates when the user leaves it — reusing a settled answer, so tabbing in and out of an unchanged field costs no request; flushing a waiting debounce, because leaving means the typing is over; and retrying a check that failed. Call `handleUnfocus()` by hand for a picker or a dropdown that manages focus its own way.
* A field or a subform can claim a `ValidationMode` of its own — `field.setValidationMode(...)`, or `AdvancedFormController(validationMode:)` on a subform — and then keeps it when the parent's mode changes. `setValidationEnabled(false)` still outranks it: a switched-off section stays quiet whatever its children claimed. There is no way back to following the parent; pass `form.value.validationMode` to match it again.
* `AdvancedFormState.validationMode`, so a widget can drive itself from the mode.

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
