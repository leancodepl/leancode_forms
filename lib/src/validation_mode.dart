import 'package:meta/meta.dart';

/// When a field validates itself on its own, without anyone calling
/// `validate()`.
///
/// Set it on the form — `AdvancedFormController(validationMode: ...)` or
/// `setValidationMode` — and it reaches every field and subform, including the
/// ones attached later. A single child may keep a mode of its own; see
/// `AdvancedFieldController.setValidationMode`.
///
/// Whatever the mode, two rules hold above it:
///
/// 1. `validate()` never consults the mode and never changes it. Submitting
///    always runs everything.
/// 2. A field the user has never edited validates nothing on its own — not on
///    its own blur, and not when a field it depends on changes. Submit is what
///    checks those.
enum ValidationMode {
  /// Nothing validates until `validate()` is called. The default, so a form
  /// nobody configured makes no network calls and shows no errors before it is
  /// submitted.
  disabled,

  /// Every edit validates the field being edited. The async validator waits out
  /// its `AsyncValidation.debounce`; leaving the field runs it at once.
  onUserInteraction,

  /// Leaving an edited field validates it.
  ///
  /// Requires the widget to bind the field's `focusNode`, or the field's owner
  /// to call `handleUnfocus()` by hand — a picker or a dropdown that manages
  /// focus itself. Nothing else can tell that the user left the field.
  onUnfocus,
}

/// What happened to a field that might make it validate itself.
@internal
enum ValidationTrigger {
  /// The user changed the field's value.
  edit,

  /// The field lost focus.
  unfocus,

  /// A field this one depends on changed, so only the sync validator is owed —
  /// this field's own value did not change and its async verdict still stands.
  dependencyChanged,
}

/// Whether [trigger] validates a field in [mode]. [edited] is the interaction
/// guarantee: a field the user has never edited validates nothing on its own.
///
/// Reads nothing else — in particular not the field's status, which a debounced
/// round overwrites with `pending`, so a status check would disarm itself on the
/// first keystroke of a repair.
@internal
bool validatesOn(
  ValidationMode mode,
  ValidationTrigger trigger, {
  required bool edited,
}) =>
    edited &&
    switch (mode) {
      ValidationMode.disabled => false,
      // The edit already validated, so unfocus has nothing left to run. A round
      // still waiting out its debounce is flushed separately, in any mode.
      ValidationMode.onUserInteraction => trigger != ValidationTrigger.unfocus,
      // The value is still being typed, so an edit waits for the blur.
      ValidationMode.onUnfocus => trigger != ValidationTrigger.edit,
    };
