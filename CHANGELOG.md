## 0.2.0

> Upgrading from 0.1.x? See [MIGRATION.md](./MIGRATION.md) for a step-by-step guide.

* **Breaking:** We've rebuilt the library on `ValueNotifier` / `ChangeNotifier`. That means `flutter_bloc` and `rxdart` are no longer dependencies.
* **Breaking:** Renamed core classes:
  * `FieldCubit` → `AdvancedFieldController`
  * `TextFieldCubit` → `AdvancedTextFieldController`
  * `BooleanFieldCubit` → `AdvancedBooleanFieldController`
  * `SingleSelectFieldCubit` → `AdvancedSingleSelectFieldController`
  * `MultiSelectFieldCubit` → `AdvancedMultiSelectFieldController`
  * `FormGroupCubit` → `AdvancedFormController`
  * `FieldState` → `AdvancedFieldState`
  * `FormGroupState` → `AdvancedFormState`
  * `FieldBuilder` → `AdvancedFieldBuilder`
* **Breaking:** `AdvancedFieldBuilder` is now a thin wrapper around `ValueListenableBuilder` instead of `BlocBuilder`. The `field:` parameter is typed `AdvancedFieldController<T, E>`, and `builder` is a `ValueWidgetBuilder`, so it takes a third `child` parameter. You can also use `ValueListenableBuilder` directly.
* **Breaking:** Lifecycle method renamed from `close()` to `dispose()` on both controllers.
* **Breaking:** The `asyncValidator` and `asyncValidationDebounce` parameters are replaced by a single `asyncValidation: AsyncValidation(validator:, debounce:, timeout:, onFailure:, failureToError:)`.
* **Breaking:** `validate()` returns `Future<bool>` on both controllers and now runs the async validators. **Await it** — the result is the only thing that says the values were checked.
* **Breaking:** `reset()` keeps `autovalidate` and `readOnly`. Previously `form.resetAll()` unlocked fields your code had locked, and undid the autovalidate that `form.validate()` turned on.
* **Breaking:** `setError(null)` clears `validationError` and the status follows, instead of leaving the field `invalid` with nothing to show. This is what makes "apply the server's response to every field" work. It leaves `asyncError` alone — use `clearErrors()` for both.
* **Breaking:** `removeSubform` returns `void`. Disposal is synchronous now, so drop the `await` — in 0.1.x it waited for every field and nested subform to close.
* **Breaking:** `registerFields`, `setValidationEnabled` and `removeSubform` throw a `StateError` on a disposed form, as `addSubform` already did.
* **Breaking:** `FieldStatus` has a new `failedValidation` value, for a check that could not run. Exhaustive `switch`es over `FieldStatus` need an arm for it.
* **Breaking:** `AdvancedFormState.validationErrors` is keyed on `AdvancedFieldState.error`, so a field invalid from an async check now appears in an error summary.
* **Breaking:** `select` and `addValue` assert that the value is one of `options`, and so does `toggleElement` when it adds. Seeding a selection before `options` is filled now throws in debug builds.
* An error never outlives the value it described. Changing the value clears both errors, and so does starting a check — so the message goes blank while a check runs, then comes back if the answer is still bad. Render `state.error` only when `!state.isInProgress` to hold the old text instead.
* Cross-field checks re-run the **sync** validator only, both through `subscribeToFields` and through `validateAll: true`. The field's own value did not change, so its last answer still stands and nothing is owed to the network. 0.1.x skipped fields that already carried an async error, so a cross-field rule stopped being re-evaluated once a server check had failed.
* A settled async answer is reused while it still describes the value, so a second submit press on an unchanged form makes no network calls.
* Added `AsyncValidation.timeout` (default: no bound) and `AsyncValidation.failureToError` for an opt-in displayable code; `AdvancedFieldController.lastFailure` carrying the exception, its stack trace and whether it timed out; `AdvancedFormState.canSubmit`, `AdvancedFormState.hasFailedValidation` and `AdvancedFormState.copyWith`; and `AdvancedFieldState.toString()`.
* Fixed, in the async validation path:
  * A result arriving late no longer overwrites a newer value, nor undoes `reset()`, `clearErrors()`, `setError()` or `setValidationEnabled(false)`.
  * A validator that throws before its first `await` no longer leaves the field stuck on `validating` forever.
  * `markReadOnly()` stops a running check, so a frozen field no longer goes on changing status by itself.
  * Removing a subform while it was being checked no longer leaves the form stuck reporting `validating`.
  * `addSubform` and `removeSubform` recompute `wasModified`, so a removed subform no longer latches the parent as modified forever.
  * Text typed into a read-only text field is reverted at once, instead of staying on screen until some later change.
* **Breaking:** `AdvancedFormController` exposes `onValuesChanged` and `onStatusChanged` as `Listenable`s (previously `Stream`s named `onValuesChangedStream` / `onStatusChangedStream`). `onStatusChanged` carries no payload, where `onStatusChangedStream` emitted the changed `FieldStatus`.
* `AdvancedTextFieldController` now owns a `TextEditingController` (`field.textController`) kept in two-way sync with the field value. Widgets bind to it directly; programmatic changes (`setValue`, `reset`) propagate to the text controller, and user input propagates back. Removes the dual-write bug class around resetting fields, set-to-initial flows, etc.
* `AdvancedTextFieldController` now owns a `FocusNode` (`field.focusNode`) and exposes a `focus()` shortcut. Enables scroll-to-first-invalid, sequential focus navigation, and programmatic focus from validators without subclassing.
* `AdvancedFieldController` gained an optional `String? name` parameter for debugging, logging, and serialization.
* `Disposable` mixin removed (lifecycle is handled by `ChangeNotifier.dispose`).
* **Deprecated:** `AdvancedFieldController.stream` replaces the `stream` that `FieldCubit` inherited from `Cubit`, so stream-based code keeps compiling through the migration. It ships deprecated and will be removed in 0.3.0 — use `addListener`, `subscribeToFields`, or the builder widgets instead.
* **Breaking:** Removed `clear()` from the text, single-select, and multi-select controllers — it only called `reset()`. Call `reset()` instead.
* **Breaking:** Dropped the `equatable` dependency. `AdvancedFieldState` and `AdvancedFormState` now implement `==` / `hashCode` by hand, comparing members with `==` rather than `EquatableMixin`'s deep collection equality. Identical for scalar and record values; for `List` / `Set` / `Map` values or error types, two equal-content-but-distinct instances now compare unequal, so a set-to-equal-value notifies where it previously deduplicated.

## 0.1.2

* Bumped `bloc` to `^9.0.0`.

## 0.1.1

* Bumped `rxdart` to `^0.28.0`.

## 0.1.0

* Write README.md

## 0.0.1

* Initial version of the library.
