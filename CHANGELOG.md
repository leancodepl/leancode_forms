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
* **Breaking:** `validate()` is now `Future<bool>` on both `AdvancedFieldController` and `AdvancedFormController`, and it runs the async validators. `await` it — it is the only thing that says the values were actually checked. Concurrent calls coalesce, so a double-tapped submit runs one pass.
* **Breaking:** `AsyncValidation.onError` is renamed to `AsyncValidation.onFailure`, and `AsyncValidationErrorHandler` to `AsyncValidationFailureHandler`. `onError` wore the word reserved for error codes while it actually handles a technical fault; the signature and the contract are unchanged.
* **Breaking:** `autovalidate` now gates the async validator too. Previously `setValue` ran it whether or not autovalidate was on, so a quiet form made network calls and `validate()` never reached an async validator. One rule now covers both: the gate decides whether a value change starts a round, and a round runs the sync validator first and the async validator only if sync passed.
* **Breaking:** `AdvancedFormState.validating` is a getter derived from the fields rather than a stored field, so `removeSubform` during validation can no longer latch it true forever. Reading it is unchanged; only code constructing `AdvancedFormState(validating: ...)` breaks.
* **Breaking:** `AdvancedFormState.validationErrors` keys on `AdvancedFieldState.error` rather than `validationError`, so a field invalid from an async check appears in an error summary.
* **Breaking:** `reset()` keeps `autovalidate` and `readOnly`. Previously `form.resetAll()` unlocked fields business logic had locked and silently undid the autovalidate `form.validate()` had escalated.
* **Breaking:** `setError(null)` clears the error and the status follows, instead of leaving the field `invalid` with nothing to show. This is what makes the "apply the server's response to every field" pattern work.
* **Breaking:** `subscribeToFields` re-runs the sync validator only — the dependent field's own value did not change, so its last async answer is still current. It also does nothing while that field's gate is closed, so a sibling's edit cannot erase a server-pushed error.
* **Breaking:** `validateWithAutovalidate()` re-runs the change path on fields whose gate is open, rather than `validate()`. One keystroke therefore cannot fire an immediate network call for every other field in the tree.
* A round now belongs to the value it was started for. `setValue`, `setError`, `clearErrors`, `reset`, `markReadOnly`, `setValidationEnabled(false)` and `dispose` all kill the armed or in-flight round, which can then never write state, notify, or report. Fixes a family of bugs where a stale round resurrected an earlier value or undid a just-applied change.
* A settled async answer is reused while it still describes the value the field holds, so a second submit press on an unchanged form makes no network calls.
* Every round settles exactly once, with an explicit outcome. A validator that throws **synchronously** now takes the same path as a rejected future instead of escaping as an uncaught zone error and wedging the field in `validating`.
* `FieldStatus.failedValidation` and `AdvancedFieldState.isFailedValidation` (renamed from `failed` / `isFailed`, both unreleased). Failure is not sticky — a failed round records no answer, so the next `validate()` retries it.
* Added `AsyncValidation.timeout` (default: no bound), `AsyncValidation.failureToError` for an opt-in displayable code, `AdvancedFieldController.lastFailure` carrying the exception, its stack trace and whether it timed out, `AdvancedFormState.canSubmit`, `AdvancedFormState.hasFailedValidation`, and `AdvancedFieldState.toString()`.
* `AdvancedTextFieldController` treats its `textController` as a projection of the field state: after every inbound mutation the text is reconciled with `fieldValue` in the same turn, preserving the selection where possible. Text typed into a read-only field is reverted immediately instead of diverging until some later write snaps it back.
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
