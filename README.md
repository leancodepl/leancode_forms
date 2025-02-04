A package for creating and managing form based on BLoC.

## Getting Started

## Installation

```sh
flutter pub add leancode_forms
```

## Usage

## Creating a Simple Form

To create a simple form, first, you need to define a `FormGroupCubit` that will manage its fields. The easiest way to do this is by extending the `FormGroupCubit` class.
```dart
class SimpleFormCubit extends FormGroupCubit {
  SimpleFormCubit();
}
```

Next, inside the form cubit, you should define the form fields. You can either use one of the [predefined field cubits](#predefined-field-cubits) or [create custom `FieldCubit`](#creating-custom-fieldcubit). In simple form, we will use `TextFieldCubit` which is a `FieldCubit` implementation for text inputs.  

```dart
class SimpleFormCubit extends FormGroupCubit {
  SimpleFormCubit();

  final firstName = TextFieldCubit();

  final lastName = TextFieldCubit();
}
```

**Important:** To make FormGroupCubit manage the defined fields, you need to register them by calling the `registerFields()` method. This also ensures that the field cubits will be disposed together with the form cubit.

```dart
class SimpleFormCubit extends FormGroupCubit {
  SimpleFormCubit() {
    registerFields([
      firstName,
      lastName,
    ]);
  }

  final firstName = TextFieldCubit();

  final lastName = TextFieldCubit();
}
```

You can provide the cubit created in this way in the same manner as any other cubit.

```dart
class SimpleForm extends StatelessWidget {
  const SimpleForm({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<SimpleFormCubit>(
      create: (context) => SimpleFormCubit(),
      child: /*FORM WIDGETS*/,
    );
  }
}
```

### Creating a Widgets for Defined Fields
The simplest way to create a form field widget is to wrap a single widget (i.e. `FormTextField`) with `FieldBuilder`.
`FieldBuilder` is a widget that takes two arguments:
- **`field`** - instance of a `FieldCubit` that `FieldBuilder` should listen to,
- **`builder`** - a callback function that defines how to build the child widget based on the `FieldState`. 

```dart
final firstNameFieldCubit = context.read<SimpleFormCubit>().firstName; 
FieldBuilder(
  field: firstNameFieldCubit,
  builder: (context, state) {
    return TextFormField(
      onChanged: firstNameFieldCubit.getValueSetter(),
    );
  },
);
```

### Validating Simple Form Fields
You can provide a validator function to each `FieldCubit`.
`Validator` is defined as a function which takes a value of a field and returns an error of any type you want.
```dart
typedef Validator<T, E extends Object> = E? Function(T);
```
There is a set of [ready-to-use validators](#ready-to-use-validators) but you can simply create your own validator. Let's add a validators to our simple form:
```dart
class SimpleFormCubit extends FormGroupCubit {
  SimpleFormCubit() {
    registerFields([
      firstName,
      lastName,
    ]);
  }

  final firstName = TextFieldCubit(
    validator: (value) {
      if (value.isEmpty) {
        return 'First name cannot be empty';
      }
    }
  );

  final lastName = TextFieldCubit(
    validator: (value) {
      if (value.isEmpty) {
        return 'Last name cannot be empty';
      }
    }
  );
}
```
To run the validation, you have to call `validate()` method on the field.
Validation can also be triggered automatically when value of the field changes. In order to achieve such behavior you need to set `autovalidate` to `true`.

To validate whole simple form you can call `validate()` method on the form cubit. It will iterate through all the fields and return false if any of the form fields is not valid. 

```dart
class SimpleFormCubit extends FormGroupCubit {
  SimpleFormCubit() {
    registerFields([
      firstName,
      lastName,
    ]);
  }

  /*FORM FIELDS*/

  void validateForm() {
    if (validate()) {
      print('Form is valid');
    } else {
      print('Form is invalid!');
    }
  }
}
```

## Ready-To-Use Validators
There is a set of validators which you can use:
 - `boundedNonNegativeInteger` - validates if a string represents a non-negative integer that is less than or equal to a specified upper bound,
 - `positiveInteger` - validates if a string represents a positive integer (greater than 0),
 - `nonNegativeInteger` - validates if a string represents a non-negative integer (greater than or equal to 0),
 - `positiveDecimal` - validates if a string represents a positive decimal number (greater than 0),
 - `nonNegativeDecimal` - validates if a string represents a non-negative decimal number (greater than or equal to 0),
 - `exactly` - validates if a string is exactly equal to a specified string,
 - `filled` - rejects null and empty strings (including whitespace-only strings),
 - `notLongerThan` - rejects strings longer than a specified maximum length,
 - `atLeastLength` - rejects strings shorter than a specified minimum length,
 - `notNull` - rejects null values,
 - `notEmpty` - rejects null and empty lists,
 - `nothing` - matches empty strings and returns an error message if the string is not empty,
 - `or` - allows you to combine multiple validators using logical OR. If at least one of the validators accepts the input, it returns null (no error),
 - `and` - allows you to combine multiple validators using logical AND. If all of the validators accept the input, it returns null (no error).

Additionally, there are extension methods (`&` and `|`) for combining validators with logical AND and OR operations, respectively.

## Async Validators
If you want to validate the field using asynchronous function, you can do it by passing `asyncValidator` to a `FieldCubit`. Async validator is an equivalent of basic validator but returns a `Future` that resolves to an error. Async validator does not run when you call `validate()`.

### Validators Order
If you pass both `validator` and `asyncValidator` to `FieldCubit`, async will be invoked only if basic validator will not return any error.

### Debouncing Async Validator
If you set `autovalidate` to `true`, async validator will be triggered every time value of the field changes. To prevent excessive calls to the async validator while a user is typing or interacting with the form field, the `asyncValidationDebounce` is used.

### Field State During Async Validation
When async validation is triggered, the field's state is updated to indicate that it is in the "pending" status using the `FieldStatus.pending` value. While async validation is in progress, the `FieldCubit` sets the field's status to "validating" using the `FieldStatus.validating` value. Once async validation completes (whether successful or with an error), the field state is updated accordingly.
If you call `validate()` function on a field which state is "validating" or "pending" at the moment it will return `false`.

If you want to see an example of a form with async validation take a look at `SimpleFormScreen` in example.

## Validation based on value of another field

Sometimes you want to validate one field based on the value of another field (e.g., the 'password' field and the 'confirm password' field). To facilitate the implementation of such a case, you can use the `subscribeToFields` method of `FieldCubit`.

```dart
class PasswordFormCubit extends FormGroupCubit {
  PasswordFormCubit() {
    registerFields([
      password,
      repeatPassword,
    ]);
  }

  final password = TextFieldCubit(
    validator: atLeastLength(8, 'Password is too short'),
  );

  late final repeatPassword = TextFieldCubit(
    validator: exactly(password.state.value, 'Passwords do not match'),
  )..subscribeToFields([password]);
}
```

Every time the value of the `password` field changes, it will trigger the validator of the `repeatPassword` field.

If you want to see a fully functional form utilizing `subscribeToFields`, take a look at the `PasswordFormScreen` in the example folder.

## `FieldCubit`

### Predefined field cubits 

The package contains a collection of field cubits useful for implementing commonly occurring form fields.

- `TextFieldCubit` - specialization of `FieldCubit` for a `String` value,
- `BooleanFieldCubit` - specialization of `FieldCubit` for a `bool` value,
- `SingleSelectFieldCubit` - specialization of `FieldCubit` for a single choice of value from list of options,
- `MultiSelectFieldCubit` - specialization of `FieldCubit` for a multiple choice of values from list of options.

`TextFieldCubit`, `SingleSelectFieldCubit` and `MultiSelectFieldCubit` contain the `clear()` method that resets the value of the field to the initial value by calling `reset()`. You can also call `reset()` as it is defined in the `FieldCubit` class.

### Creating custom `FieldCubit`

If none of the existing `FieldCubit` implementations meet your requirements, you can create your own. Simply create a class that extends `FieldCubit`. Inside such cubit, you can add any method or a field.

```dart
class IntegerFieldCubit<E extends Object> extends FieldCubit<int, E> {
  IntegerFieldCubit({
    super.initialValue = 0,
    super.validator,
    super.asyncValidator,
    super.asyncValidationDebounce,
  });

  bool get isNegative => state.value.isNegative;

  void negate() => setValue(-state.value);
}
```

## Creating form field widget

When you create a UI for your form, you can define widget like it is shown in [Simple Form Example](#creating-a-widgets-for-defined-fields). However, this approach can lead to a lot of boilerplate code, especially when one form widget is used multiple times. In such cases, it's best to create a custom widget by extending `FieldBuilder`.

```dart
class FormTextField<E extends Object> extends FieldBuilder<String, E> {
  FormTextField({
    super.key,
    required TextFieldCubit<E> super.field,
    required ErrorTranslator<E> errorTranslator,
    ValueChanged<String>? onFieldSubmitted,
    String? labelText,
    String? hintText,
  }) : super(
          builder: (context, state) => TextFormField(
            onChanged: field.getValueSetter(),
            onFieldSubmitted: onFieldSubmitted,
            decoration: InputDecoration(
              labelText: labelText,
              hintText: hintText,
              errorText:
                  state.error != null ? errorTranslator(state.error!) : null,
            ),
          ),
        );
}
```

## Subforms

It happens that a created form contains a subform that is dynamically added to the page, affecting the validation result of the entire form. `leancode_forms` allows you to manage fields of such a form. `FormGroupCubit` includes `addSubform` method that enable you to add another `FormGroupCubit` as a subform to the base form. Added subform fields will be taken into account when methods which affects all fields will be invoked (such as `validate`, `markReadOnly` `setValidationEnabled`). This can also prove useful when you're creating a form with a large number of fields, resulting in a FormGroupCubit having a high number of LOC (Lines of Code). Dividing it into smaller subforms can improve code readability.

```dart
class BaseFormCubit extends FormGroupCubit {
  BaseFormCubit() {
    registerFields([
      field,
    ]);
  }

  final field = TextFieldCubit();

  final subform = SubformCubit();

  // Adds subform to the base form
  void extendForm() {
    addSubform(subform);
  }
}

class SubformCubit extends FormGroupCubit {
  SubformCubit() {
    registerFields([subformField]);
  }

  final subformField = TextFieldCubit();
}
```
