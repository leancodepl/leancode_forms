import 'package:meta/meta.dart';

/// When a field validates itself, with nobody calling `validate()`.
///
/// Set it on the `AdvancedFormController` and it reaches every field and
/// subform. `validate()` neither consults nor changes it, and in every mode a
/// field the user has never edited validates nothing on its own.
enum ValidationMode {
  /// Nothing validates until `validate()` is called. The default.
  disabled,

  /// Every edit validates the field, the async check after its debounce.
  onUserInteraction,

  /// Leaving an edited field validates it; an unchanged value reuses its last
  /// answer. Requires a widget to bind the field's `focusNode`, or a call to
  /// `handleUnfocus()` — nothing validates in this mode otherwise.
  onUnfocus,
}

@internal
enum ValidationEvent {
  valueChanged,
  unfocus,

  /// A field this one depends on changed, so only the sync validator is owed.
  dependencyChanged,
}

/// The one place that decides whether a field validates itself.
///
/// | mode | valueChanged | unfocus | dependencyChanged |
/// |---|---|---|---|
/// | `disabled` | — | — | — |
/// | `onUserInteraction` | validate | — | sync only |
/// | `onUnfocus` | — | validate | sync only |
///
/// Reads no field status on purpose: a debounced round overwrites the status
/// with `pending` and the write path clears both errors, so a status check
/// would disarm itself as the user started fixing the value.
@internal
bool validatesOn(
  ValidationEvent event, {
  required ValidationMode mode,
  required bool hasInteracted,
}) =>
    // Checked before the mode, so an untouched field stays quiet in all three.
    hasInteracted &&
    switch (mode) {
      ValidationMode.disabled => false,
      // The edit already validated, so unfocus has nothing left to run.
      ValidationMode.onUserInteraction => event != ValidationEvent.unfocus,
      // The value is still being typed, so an edit waits for the unfocus.
      ValidationMode.onUnfocus => event != ValidationEvent.valueChanged,
    };
