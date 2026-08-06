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
* **Breaking:** The `asyncValidator` and `asyncValidationDebounce` parameters are replaced by a single `asyncValidation: AsyncValidation(validator:, debounce:, onError:)`.
* **Breaking:** `AdvancedFormController` exposes `onValuesChanged` and `onStatusChanged` as `Listenable`s (previously `Stream`s named `onValuesChangedStream` / `onStatusChangedStream`). `onStatusChanged` carries no payload, where `onStatusChangedStream` emitted the changed `FieldStatus`.
* `AdvancedTextFieldController` now owns a `TextEditingController` (`field.textController`) kept in two-way sync with the field value. Widgets bind to it directly; programmatic changes (`setValue`, `reset`) propagate to the text controller, and user input propagates back. Removes the dual-write bug class around resetting fields, set-to-initial flows, etc.
* `AdvancedTextFieldController` now owns a `FocusNode` (`field.focusNode`) and exposes a `focus()` shortcut. Enables scroll-to-first-invalid, sequential focus navigation, and programmatic focus from validators without subclassing.
* `AdvancedFieldController` gained an optional `String? name` parameter for debugging, logging, and serialization.
* `Disposable` mixin removed (lifecycle is handled by `ChangeNotifier.dispose`).
* **Deprecated:** `AdvancedFieldController.stream` replaces the `stream` that `FieldCubit` inherited from `Cubit`, so stream-based code keeps compiling through the migration. It ships deprecated and will be removed in 0.3.0 — use `addListener`, `subscribeToFields`, or the builder widgets instead.
* **Breaking:** Removed `clear()` from the text, single-select, and multi-select controllers — it only called `reset()`. Call `reset()` instead.
* **Breaking:** Dropped the `equatable` dependency. `AdvancedFieldState` and `AdvancedFormState` now implement `==` / `hashCode` by hand, comparing members with `==` rather than `EquatableMixin`'s deep collection equality. Identical for scalar and record values; for `List` / `Set` / `Map` values or error types, two equal-content-but-distinct instances now compare unequal, so a set-to-equal-value notifies where it previously deduplicated.
* Added `AdvancedFormScope`, a small `StatefulWidget` for creating, exposing, and disposing an `AdvancedFormController` — no dependency on the `provider` package required. `create` runs lazily on first `AdvancedFormScope.watch` / `.read`, and the controller is disposed automatically on unmount. See [README.md](./README.md) and [MIGRATION.md](./MIGRATION.md#8-dropping-flutter_bloc-and-friends). Already using `provider`? `ChangeNotifierProvider` still works exactly the same way — use whichever you prefer.

## 0.1.2

* Bumped `bloc` to `^9.0.0`.

## 0.1.1

* Bumped `rxdart` to `^0.28.0`.

## 0.1.0

* Write README.md

## 0.0.1

* Initial version of the library.
