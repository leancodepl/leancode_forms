import 'package:meta/meta.dart';

/// When a field validates itself, with nobody calling `validate()`.
///
/// Set it on the `AdvancedFormController` and it reaches every field and
/// subform in the tree. A field or a subform can claim a mode of its own, and
/// then keeps it whatever its form is set to later.
///
/// `validate()` never reads the mode and never changes it: submitting always
/// runs everything.
///
/// In every mode, a field the user has never edited validates nothing on its
/// own — not on its own change, not on a dependency's change, and not on
/// unfocus. Only `validate()` checks those.
enum ValidationMode {
  /// Nothing validates until `validate()` is called.
  ///
  /// The default. A form nobody configured makes no async calls and shows no
  /// errors until it is submitted.
  disabled,

  /// Every edit validates the field being edited.
  ///
  /// The only mode in which the async debounce is ever waiting, since it is the
  /// only one that starts a round from an edit.
  onUserInteraction,

  /// Leaving an edited field validates it.
  ///
  /// Requires the widget to bind the field's `focusNode`, or to call
  /// `handleUnfocus()` itself — a picker or a dropdown that manages focus its
  /// own way.
  onUnfocus,
}

/// The things that can make a field validate itself. `validate()` is not one of
/// them.
@internal
enum ValidationEvent {
  /// The user edited this field.
  valueChanged,

  /// The field lost focus.
  unfocus,

  /// A field this one depends on changed, so only the sync validator is owed.
  dependencyChanged,
}

/// The one place that decides whether validation runs.
///
/// Reads no field status: a debounced round sets the status to `pending` and
/// the write path clears both errors, so a status check would stop the field
/// validating as soon as the user started fixing the value.
@internal
bool validatesOn(
  ValidationEvent event, {
  required ValidationMode mode,
  required bool hasInteracted,
}) {
  // Before the mode, so an untouched field stays quiet whatever the mode says.
  if (!hasInteracted) {
    return false;
  }

  return switch (mode) {
    ValidationMode.disabled => false,
    // The edit already validated, so unfocus has nothing left to run.
    ValidationMode.onUserInteraction => event != ValidationEvent.unfocus,
    // The value is still being typed, so an edit waits for the blur.
    ValidationMode.onUnfocus => event != ValidationEvent.valueChanged,
  };
}

/// What a form is running under, and what it sends its children.
@internal
typedef ValidationSettings = ({ValidationMode mode, bool enabled});

/// The default a child runs under before any form has told it anything.
@internal
const defaultValidationSettings = (
  mode: ValidationMode.disabled,
  enabled: true,
);

/// The three rules by which settings reach a child.
@internal
extension ValidationSettingsInheritance on ValidationSettings {
  /// What a leaf field runs under. A subtree with validation switched off is
  /// [ValidationMode.disabled], so a field has one input to obey instead of
  /// two.
  ValidationMode get fieldMode => enabled ? mode : ValidationMode.disabled;

  /// What a subform runs under. The mode comes from the parent; the switch is
  /// the two of them agreeing, so a section opted out stays opted out.
  ValidationSettings inheritedBy({required bool ownEnabled}) =>
      (mode: mode, enabled: enabled && ownEnabled);

  /// What a child that claimed its own mode runs under. A claim covers the mode
  /// axis only: `enabled` still comes from the parent, so a switched-off
  /// section stays quiet whatever mode its children claimed.
  ValidationSettings overriddenBy(ValidationMode ownMode) =>
      (mode: ownMode, enabled: enabled);
}
