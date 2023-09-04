import 'package:flutter_test/flutter_test.dart';
import 'package:leancode_forms/src/utils/extensions/stream_extensions';

void main() {
  test(
      'distinctWithFirst starts emitting distinct values as soon as the value in the stream is different from the initialValue',
      () async {
    final stream = Stream.fromIterable([1, 1, 1, 1, 1, 4, 5, 1, 6, 7, 7]);
    const initialValue = 1;
    final distinctStream = stream.distinctWithFirst(initialValue);

    expect(
      distinctStream,
      emitsInOrder([4, 5, 1, 6, 7]),
    );
  });

  test(
      'distinctWithFirst does not emit any value when all are equal to the initial',
      () async {
    final input = Stream.fromIterable([1, 1, 1, 1, 1, 1]);
    const initialValue = 1;

    final distinctStream = input.distinctWithFirst(initialValue);

    expect(
      distinctStream,
      emitsInOrder([]),
    );
  });
}
