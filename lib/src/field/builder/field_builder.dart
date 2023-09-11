import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:leancode_forms/src/field/cubit/field_cubit.dart';

/// Listens to the given [field] and rerenders the child using [builder].
class FieldBuilder<T, E extends Object> extends StatelessWidget {
  /// Creates a new [FieldBuilder].
  const FieldBuilder({
    super.key,
    required this.field,
    required this.builder,
  });

  /// The [FieldCubit] to listen to.
  final FieldCubit<T, E> field;

  /// The builder to use to build the child.
  final BlocWidgetBuilder<FieldState<T, E>> builder;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FieldCubit<T, E>, FieldState<T, E>>(
      bloc: field,
      builder: builder,
    );
  }
}

/// Translates an error to a string.
typedef ErrorTranslator<E extends Object> = String Function(E);
