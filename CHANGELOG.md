## 0.2.0

> Upgrading from 0.1.x? See [MIGRATION.md](./MIGRATION.md) for a step-by-step guide.

* **Breaking:** We've rebuilt the library on `ValueNotifier` / `ChangeNotifier`. That means `flutter_bloc` and `rxdart` no longer are a dependency.
* **Breaking:** Renamed core classes:
  * `FieldCubit` → `FieldController`
  * `TextFieldCubit` → `TextFieldController`
  * `BooleanFieldCubit` → `BooleanFieldController`
  * `SingleSelectFieldCubit` → `SingleSelectFieldController`
  * `MultiSelectFieldCubit` → `MultiSelectFieldController`
  * `FormGroupCubit` → `FormController`
* `FieldBuilder` is kept. It is now a thin wrapper around `ValueListenableBuilder` instead of `BlocBuilder`. The `field:` parameter is now typed `FieldController<T, E>` (previously `FieldCubit<T, E>`); the builder signature is otherwise unchanged. You can also use `ValueListenableBuilder` directly.
* **Breaking:** Lifecycle method renamed from `close()` to `dispose()` on both controllers.
* **Breaking:** `FormController` exposes `onValuesChanged` and `onStatusChanged` as `Listenable`s (previously `Stream`s named `onValuesChangedStream` / `onStatusChangedStream`).
* `TextFieldController` now owns a `TextEditingController` (`field.textController`) kept in two-way sync with the field value. Widgets bind to it directly; programmatic changes (`setValue`, `reset`, `clear`) propagate to the text controller, and user input propagates back. Removes the dual-write bug class around resetting fields, set-to-initial flows, etc.
* `FieldController` gained an optional `String? name` parameter for debugging, logging, and serialization.
* `Disposable` mixin removed (lifecycle is handled by `ChangeNotifier.dispose`).
* Internal `distinctWithFirst` stream extension and `CancelableFuture` are no longer exported.
* Dropped the `equatable` dependency. `FieldState` and `FormState` now manual `==` / `hashCode`. No behavioral change — value-equality semantics are identical.

## 0.1.2

* Bumped `bloc` to `^9.0.0`.

## 0.1.1

* Bumped `rxdart` to `^0.28.0`.

## 0.1.0

* Write README.md

## 0.0.1

* Initial version of the library.
