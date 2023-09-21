A package for managing form state based on BLoC.

## Features

# FieldCubit
A single form field which can be validated.
Stores the current value, error text, and whether autovalidate is on.

# FormGroupCubit
A parent of multiple FieldCubits. Manages group validation and tracks changes as well as cleans up needed resources.