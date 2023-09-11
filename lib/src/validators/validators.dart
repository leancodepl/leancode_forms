import 'package:leancode_forms/leancode_forms.dart';
import 'package:leancode_forms/src/field/cubit/field_cubit.dart';

/// Creates a new validator.
///
/// Useful when you need to pass parameters of dynamic type to the validator.
Validator<T, E> dynamicValidator<T, E extends Object>(
  Validator<T, E>? Function() validatorBuilder,
) =>
    (value) => validatorBuilder()?.call(value);

/// If [enabledGetter] returns true [validator] is ran. Otherwise this accepts all input.
Validator<T, E> conditionalValidator<T, E extends Object>(
  Validator<T, E> validator,
  bool Function() enabledGetter,
) =>
    (value) => enabledGetter() ? validator(value) : null;

/// Of the form `>upperBound` or `num` where `num` is between 0 and [upperBound] inclusive
Validator<String?, E> boundedNonNegativeInteger<E extends Object>(
  int upperBound,
  E message,
) {
  final regex = RegExp('^(>$upperBound|(0|[1-9][0-9]*))\$');
  return (value) {
    final match = regex.firstMatch(value ?? '');
    if (match == null) {
      return message;
    }

    final number = match.group(2);
    if (number != null && number.isNotEmpty && int.parse(number) > upperBound) {
      return message;
    }

    return null;
  };
}

/// Checks if the value is a integer with a value above 0.
Validator<String?, E> positiveInteger<E extends Object>(
  E message,
) {
  return (value) {
    if (value != null) {
      final number = int.tryParse(value);

      if ((number ?? 0) <= 0) {
        return message;
      }
    } else {
      return message;
    }

    return null;
  };
}

/// Checks if the value is a integer with a value above or equal to 0.
Validator<String?, E> nonNegativeInteger<E extends Object>(
  E message,
) {
  return (value) {
    if (value != null) {
      final number = int.tryParse(value);

      if ((number ?? -1) < 0) {
        return message;
      }
    } else {
      return message;
    }

    return null;
  };
}

/// Checks if the value is a decimal with a value above 0.
Validator<String?, E> positiveDecimal<E extends Object>(
  E message,
) {
  return (value) {
    if (value != null) {
      final number = double.tryParse(value);

      if ((number ?? 0) <= 0) {
        return message;
      }
    } else {
      return message;
    }

    return null;
  };
}

/// Checks if the value is a decimal with a value above or equal to 0.
Validator<String?, E> nonNegativeDecimal<E extends Object>(
  E message,
) {
  return (value) {
    if (value != null) {
      final number = double.tryParse(value);

      if ((number ?? -1) < 0) {
        return message;
      }
    } else {
      return message;
    }

    return null;
  };
}

/// Only one of the given validators has to accept input.
/// If none accept, first error is returned or [sharedMessage] if provided.
Validator<T, E> or<T, E extends Object>(
  Iterable<Validator<T, E>> validators, [
  E? sharedMessage,
]) =>
    (value) {
      E? message;

      for (final validator in validators) {
        final result = validator(value);
        if (result == null) {
          return null;
        }
        message ??= sharedMessage ?? result;
      }

      return message;
    };

/// Each of the given validators has to accept input.
/// If some accept, first error is returned or [sharedMessage] if provided.
Validator<T, E> and<T, E extends Object>(
  Iterable<Validator<T, E>> validators, [
  E? sharedMessage,
]) =>
    (value) {
      for (final validator in validators) {
        final result = validator(value);
        if (result != null) {
          return sharedMessage ?? result;
        }
      }

      return null;
    };

/// Requires to be exactly the given string.
Validator<String?, E> exactly<E extends Object>(String string, E message) =>
    (value) {
      if (value != string) {
        return message;
      }

      return null;
    };

/// Rejects null and empty strings (including whitespace only strings).
Validator<String?, E> filled<E extends Object>(E message) => (value) {
      if (value?.trim().isEmpty ?? true) {
        return message;
      }

      return null;
    };

/// Rejects strings longer than [maxLength].
Validator<String?, E> notLongerThan<E extends Object>(
  int maxLength,
  E message,
) =>
    (value) {
      if ((value?.length ?? 0) > maxLength) {
        return message;
      }

      return null;
    };

/// Rejects strings shorter than [minLength].
Validator<String?, E> atLeastLength<E extends Object>(
  int minLength,
  E message,
) =>
    (value) {
      if (value == null || value.length < minLength) {
        return message;
      }
      return null;
    };

/// Rejects null
Validator<T?, E> notNull<T, E extends Object>(E message) => (value) {
      if (value == null) {
        return message;
      }

      return null;
    };

/// Rejects null and empty lists
Validator<List<T>?, E> notEmpty<T, E extends Object>(E message) => (value) {
      if (value?.isEmpty ?? true) {
        return message;
      }

      return null;
    };

/// Matches empty strings
Validator<String?, E> nothing<E extends Object>(E message) => (value) {
      if (value?.isNotEmpty ?? false) {
        return message;
      }

      return null;
    };

/// Extension methods for [Validator] allowing to combine them.
extension ValidatorCombinators<T, E extends Object> on Validator<T, E> {
  /// Returns a new validator combining this and [other] with a logical AND.
  Validator<T, E> operator &(Validator<T, E> other) {
    return (value) {
      return this(value) ?? other(value);
    };
  }

  /// Returns a new validator combining this and [other] with a logical OR.
  Validator<T, E> operator |(Validator<T, E> other) {
    return (value) {
      final result = this(value);
      if (result == null) {
        return null;
      } else if (other(value) == null) {
        return null;
      }

      return result;
    };
  }
}
