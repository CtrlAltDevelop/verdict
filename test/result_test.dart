import 'package:test/test.dart';
import 'package:verdict/verdict.dart';

const _failure = ApiFailure(title: 'test', message: 'boom', code: 400);

void main() {
  group('Ok', () {
    test('reports itself as ok and exposes its value', () {
      const result = Ok<int>(1);

      expect(result.isOk, isTrue);
      expect(result.isErr, isFalse);
      expect(result.valueOrNull, 1);
      expect(result.failureOrNull, isNull);
    });

    test('getOrElse returns the value, not the fallback', () {
      expect(const Ok<int>(1).getOrElse(9), 1);
    });

    test('compares by value', () {
      expect(const Ok<int>(1), const Ok<int>(1));
      expect(const Ok<int>(1), isNot(const Ok<int>(2)));
      expect(const Ok<int>(1).hashCode, const Ok<int>(1).hashCode);
    });

    test('an Ok holding null is still ok', () {
      const result = Ok<int?>(null);

      expect(result.isOk, isTrue);
      expect(result.valueOrNull, isNull);
      expect(result.failureOrNull, isNull);
    });
  });

  group('Err', () {
    test('reports itself as err and exposes its failure', () {
      const result = Err<int>(_failure);

      expect(result.isErr, isTrue);
      expect(result.isOk, isFalse);
      expect(result.valueOrNull, isNull);
      expect(result.failureOrNull, _failure);
    });

    test('getOrElse returns the fallback', () {
      expect(const Err<int>(_failure).getOrElse(9), 9);
    });

    test('compares by failure', () {
      expect(const Err<int>(_failure), const Err<int>(_failure));
      expect(
        const Err<int>(_failure),
        isNot(const Err<int>(UnknownFailure(title: 'x', message: 'y'))),
      );
    });
  });

  group('fold', () {
    test('takes the ok branch for an Ok', () {
      final folded = const Ok<int>(2).fold(
        onOk: (value) => 'ok:$value',
        onErr: (failure) => 'err:${failure.message}',
      );

      expect(folded, 'ok:2');
    });

    test('takes the err branch for an Err', () {
      final folded = const Err<int>(_failure).fold(
        onOk: (value) => 'ok:$value',
        onErr: (failure) => 'err:${failure.message}',
      );

      expect(folded, 'err:boom');
    });
  });

  group('map', () {
    test('transforms an Ok', () {
      expect(const Ok<int>(2).map((value) => value * 2), const Ok<int>(4));
    });

    test('passes an Err through without calling the transform', () {
      var called = false;
      final result = const Err<int>(_failure).map((value) {
        called = true;
        return value * 2;
      });

      expect(called, isFalse);
      expect(result, const Err<int>(_failure));
    });
  });

  group('flatMap', () {
    test('chains an Ok into the next result', () {
      expect(
        const Ok<int>(2).flatMap((value) => Ok<String>('$value')),
        const Ok<String>('2'),
      );
    });

    test('short-circuits on an Err', () {
      expect(
        const Err<int>(_failure).flatMap((value) => Ok<String>('$value')),
        const Err<String>(_failure),
      );
    });

    test('propagates a failure produced by the transform', () {
      expect(
        const Ok<int>(2).flatMap((_) => const Err<String>(_failure)),
        const Err<String>(_failure),
      );
    });
  });

  group('Unit', () {
    test('all instances are equal', () {
      expect(unit, const Unit());
      expect(unit.hashCode, const Unit().hashCode);
    });

    test('models a success with no payload', () {
      const result = Ok<Unit>(unit);

      expect(result.isOk, isTrue);
      expect(result.valueOrNull, unit);
    });
  });

  group('switch exhaustiveness', () {
    test('a sealed switch covers both branches without a default', () {
      String describe(Result<int> result) => switch (result) {
            Ok(:final value) => 'ok $value',
            Err(:final failure) => 'err ${failure.code}',
          };

      expect(describe(const Ok<int>(1)), 'ok 1');
      expect(describe(const Err<int>(_failure)), 'err 400');
    });
  });
}
