/// Extensions for [Stream] of type [T].
extension StreamExtensions<T> on Stream<T> {
  /// distinct() will always emit the first event since there is no previous one to compare with.
  /// This method seeds the stream with an initial value
  /// and starts emitting distinct values as soon as there is a value different from the initial one.
  Stream<T> distinctWithFirst(T firstValue) {
    var isFirstEmit = true;

    return distinct().where((value) {
      if (isFirstEmit) {
        isFirstEmit = false;
        if (firstValue == value) {
          return false;
        }
      }

      return true;
    });
  }
}
