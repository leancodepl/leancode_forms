import 'package:meta/meta.dart';

/// When a field validates itself, with nobody calling `validate()`.
///
/// Set it on the `AdvancedFormController`; it reaches every field and subform
/// in the tree. `validate()` ignores it and never changes it, so the mode a
/// form is given is the mode it keeps.
///
/// In every mode, a field the user has never edited validates nothing on its
/// own. Only `validate()` checks those.
enum ValidationMode {
  /// Nothing validates until `validate()` is called. The default: a form nobody
  /// configured makes no network calls and shows no errors until it is
  /// submitted.
  ///
  /// Setting a value still clears the errors it had, because they described the
  /// old value.
  disabled,

  /// Every edit validates the field being edited. The async validator waits out
  /// its debounce, so a burst of keystrokes costs one request.
  onUserInteraction,

  /// Leaving an edited field validates it. Tabbing through a field without
  /// editing it costs nothing, and neither does leaving a field whose value has
  /// not changed since its last check.
  ///
  /// Requires a widget to bind the field's `focusNode`, or to call
  /// `handleUnfocus()` itself — a picker or a dropdown usually does the latter.
  /// Nothing validates in this mode when neither happens.
  onUnfocus,
}

/// The things that can make a field validate itself. `validate()` is not one of
/// them: it validates whatever the mode says.
@internal
enum ValidationEvent {
  /// The user edited the field.
  valueChanged,

  /// The field lost focus.
  unfocus,

  /// A field this one depends on changed, so only the sync validator is owed —
  /// this field's own value did not change and its async verdict still stands.
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
/// Reads no field status, which is what makes it safe on this pipeline: a
/// debounced round overwrites the status with `pending` and the write path
/// clears both error slots, so a status check would stop the field validating
/// as soon as the user started fixing the value.
@internal
bool validatesOn(
  ValidationEvent event, {
  required ValidationMode mode,
  required bool hasInteracted,
}) =>
    // Checked before the mode, so an untouched field stays quiet whatever the
    // mode says — including when a sibling changes.
    hasInteracted &&
    switch (mode) {
      ValidationMode.disabled => false,
      // The edit already validated, so unfocus has nothing left to run.
      ValidationMode.onUserInteraction => event != ValidationEvent.unfocus,
      // The value is still being typed, so an edit waits for the unfocus.
      ValidationMode.onUnfocus => event != ValidationEvent.valueChanged,
    };
