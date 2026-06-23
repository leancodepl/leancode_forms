import 'dart:async';

import 'package:flutter/material.dart';
import 'package:leancode_forms/leancode_forms.dart';
import 'package:leancode_forms_example/controllers/focusable_text_field_controller.dart';
import 'package:leancode_forms_example/main.dart';
import 'package:leancode_forms_example/screens/form_page.dart';
import 'package:leancode_forms_example/utils/extensions/iterable_extensions.dart';
import 'package:leancode_forms_example/widgets/form_text_field.dart';
import 'package:leancode_forms_example/widgets/screen_description.dart';
import 'package:provider/provider.dart';

class ScrollFormScreen extends StatelessWidget {
  const ScrollFormScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ScrollFormController>(
      create: (_) => ScrollFormController(),
      child: const ScrollForm(),
    );
  }
}

class ScrollForm extends StatefulWidget {
  const ScrollForm({super.key});

  @override
  State<ScrollForm> createState() => _ScrollFormState();
}

class _ScrollFormState extends State<ScrollForm> {
  StreamSubscription<ScrollFormEvent>? _eventSubscription;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _eventSubscription ??= context.read<ScrollFormController>().events.listen(
      (event) {
        if (event is SubmitFailedWithErrors) {
          _scrollToFirstError(context.read<ScrollFormController>());
        }
      },
    );
  }

  void _scrollToFirstError(ScrollFormController controller) {
    final fields = [
      controller.firstField,
      controller.secondField,
      controller.thirdField,
    ];
    fields.firstWhereOrNull((f) => f.value.isInvalid)?.focus();
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller =
        context.select<ScrollFormController, ScrollFormController>((c) => c);
    return FormPage(
      title: 'Scroll Form',
      child: SingleChildScrollView(
        child: Column(
          children: [
            ScreenDescription([
              bold('Focus management. '),
              plain('Each field owns its own '),
              code('FocusNode'),
              plain('. On submit failure the controller emits a '),
              code('SubmitFailedWithErrors'),
              plain(' event over a plain broadcast '),
              code('Stream'),
              plain('; the widget listens and focuses the '),
              bold('first invalid field'),
              plain(', scrolling it into view.'),
            ]),
            FocusableFormTextField(
              field: controller.firstField,
              translateError: validatorTranslator,
              labelText: 'First field',
              hintText: 'Write here...',
              onFieldSubmitted: (_) => controller.secondField.focus(),
            ),
            const SizedBox(height: 260),
            FocusableFormTextField(
              field: controller.secondField,
              translateError: validatorTranslator,
              labelText: 'Second field',
              hintText: 'Write here...',
              onFieldSubmitted: (_) => controller.thirdField.focus(),
            ),
            const SizedBox(height: 260),
            FocusableFormTextField(
              field: controller.thirdField,
              translateError: validatorTranslator,
              labelText: 'Third field',
              hintText: 'Write here...',
            ),
            const SizedBox(height: 260),
            ElevatedButton(
              onPressed: controller.submit,
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }
}

class ScrollFormController extends AdvancedFormController {
  ScrollFormController() {
    registerFields([
      firstField,
      secondField,
      thirdField,
    ]);
  }

  final firstField = FocusableTextFieldController<ValidationError>(
    validator: filled(ValidationError.empty),
  );
  final secondField = FocusableTextFieldController<ValidationError>(
    validator: filled(ValidationError.empty),
  );
  final thirdField = FocusableTextFieldController<ValidationError>(
    validator: filled(ValidationError.empty),
  );

  final _eventsController = StreamController<ScrollFormEvent>.broadcast();
  Stream<ScrollFormEvent> get events => _eventsController.stream;

  void submit() {
    if (validate()) {
      debugPrint('Submit successful');
    } else {
      _eventsController.add(const SubmitFailedWithErrors());
    }
  }

  @override
  void dispose() {
    _eventsController.close();
    super.dispose();
  }
}

sealed class ScrollFormEvent {}

class SubmitFailedWithErrors implements ScrollFormEvent {
  const SubmitFailedWithErrors();
}
