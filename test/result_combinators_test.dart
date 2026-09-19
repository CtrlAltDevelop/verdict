import 'package:test/test.dart';
import 'package:verdict/verdict.dart';

const _failure = ApiFailure(title: 'test', message: 'boom', code: 400);
const _other = NetworkFailure(title: 'test', message: 'offline');

void main() {
  group('factories', () {
    test('Result.ok and Result.err build the matching variants', () {
      expect(const Result<int>.ok(1), const Ok<int>(1));
      expect(const Result<int>.err(_failure), const Err<int>(_failure));
    });
  });

  group('valueOrThrow', () {
    test('returns the value of an Ok', () {
      expect(const Ok<int>(1).valueOrThrow, 1);
    });

    test('throws a FailureException carrying the failure of an Err', () {
      expect(
        () => const Err<int>(_failure).valueOrThrow,
        throwsA(
          isA<FailureException>().having((e) => e.failure, 'failure', _failure),
        ),
      );
    });
  });

  group('getOrElseWith', () {
    test('returns the value and never calls the fallback on an Ok', () {
      var called = false;
      final value = const Ok<int>(1).getOrElseWith((_) {
        called = true;
        return 9;
      });

      expect(value, 1);
      expect(called, isFalse);
    });

    test('derives the fallback from the failure on an Err', () {
      expect(const Err<int>(_failure).getOrElseWith((f) => f.code ?? 0), 400);
    });
  });

  group('mapFailure', () {
    test('replaces the failure of an Err', () {
      expect(
        const Err<int>(_failure).mapFailure((_) => _other),
        const Err<int>(_other),
      );
    });

    test('passes an Ok through untouched', () {
      expect(const Ok<int>(1).mapFailure((_) => _other), const Ok<int>(1));
    });
  });

  group('recover', () {
    test('turns an Err into an Ok', () {
      expect(
        const Err<int>(_failure).recover((f) => f.code ?? 0),
        const Ok(400),
      );
    });

    test('leaves an Ok untouched', () {
      expect(const Ok<int>(1).recover((_) => 9), const Ok<int>(1));
    });
  });

  group('recoverWith', () {
    test('can recover into another Ok', () {
      expect(
        const Err<int>(_failure).recoverWith((_) => const Ok<int>(2)),
        const Ok<int>(2),
      );
    });

    test('can fail again with a different failure', () {
      expect(
        const Err<int>(_failure).recoverWith((_) => const Err<int>(_other)),
        const Err<int>(_other),
      );
    });

    test('leaves an Ok untouched', () {
      expect(
        const Ok<int>(1).recoverWith((_) => const Err<int>(_other)),
        const Ok<int>(1),
      );
    });
  });

  group('onOk / onErr', () {
    test('onOk runs only for an Ok and returns the result unchanged', () {
      final seen = <int>[];

      expect(const Ok<int>(1).onOk(seen.add), const Ok<int>(1));
      expect(const Err<int>(_failure).onOk(seen.add), const Err<int>(_failure));
      expect(seen, [1]);
    });

    test('onErr runs only for an Err and returns the result unchanged', () {
      final seen = <Failure>[];

      expect(
        const Err<int>(_failure).onErr(seen.add),
        const Err<int>(_failure),
      );
      expect(const Ok<int>(1).onErr(seen.add), const Ok<int>(1));
      expect(seen, [_failure]);
    });
  });

  group('async combinators', () {
    test('mapAsync transforms an Ok', () async {
      expect(await const Ok<int>(1).mapAsync((n) async => n + 1), const Ok(2));
    });

    test(
      'mapAsync passes an Err through without calling the transform',
      () async {
        var called = false;
        final result = await const Err<int>(_failure).mapAsync((n) async {
          called = true;
          return n;
        });

        expect(result, const Err<int>(_failure));
        expect(called, isFalse);
      },
    );

    test('flatMapAsync chains a fallible async step', () async {
      expect(
        await const Ok<int>(1).flatMapAsync((n) async => Ok<String>('$n')),
        const Ok<String>('1'),
      );
      expect(
        await const Err<int>(
          _failure,
        ).flatMapAsync((n) async => Ok<String>('$n')),
        const Err<String>(_failure),
      );
    });
  });

  group('Result.collect', () {
    test('gathers every value in order', () {
      // Compared through the value: `Ok` equality is `==` on the payload,
      // and two distinct lists are never `==`.
      expect(
        Result.collect(const [Ok<int>(1), Ok<int>(2), Ok<int>(3)]).valueOrThrow,
        [1, 2, 3],
      );
    });

    test('short-circuits on the first failure', () {
      var evaluated = 0;
      Iterable<Result<int>> results() sync* {
        evaluated++;
        yield const Ok<int>(1);
        evaluated++;
        yield const Err<int>(_failure);
        evaluated++;
        yield const Err<int>(_other);
      }

      expect(Result.collect(results()), const Err<List<int>>(_failure));
      expect(evaluated, 2, reason: 'the third element must not be pulled');
    });

    test('an empty iterable collects to an empty Ok', () {
      expect(Result.collect(const <Result<int>>[]).valueOrThrow, isEmpty);
    });
  });

  group('flatten', () {
    test('collapses a nested Ok', () {
      expect(const Ok<Result<int>>(Ok<int>(1)).flatten(), const Ok<int>(1));
    });

    test('collapses an inner Err', () {
      expect(
        const Ok<Result<int>>(Err<int>(_failure)).flatten(),
        const Err<int>(_failure),
      );
    });

    test('collapses an outer Err', () {
      expect(
        const Err<Result<int>>(_failure).flatten(),
        const Err<int>(_failure),
      );
    });
  });

  group('FutureResult', () {
    Future<Result<int>> ok() async => const Ok<int>(1);
    Future<Result<int>> err() async => const Err<int>(_failure);

    test('chains without intermediate awaits', () async {
      final name = await ok()
          .flatMapAsync((n) async => Ok<int>(n + 1))
          .map((n) => 'n=$n')
          .getOrElse('none');

      expect(name, 'n=2');
    });

    test('a failure short-circuits the whole chain', () async {
      var called = false;
      final name = await err()
          .map((n) {
            called = true;
            return 'n=$n';
          })
          .getOrElseWith((f) => f.message);

      expect(name, 'boom');
      expect(called, isFalse);
    });

    test('exposes fold, taps, recovery and the nullable accessors', () async {
      expect(await ok().fold(onOk: (n) => '$n', onErr: (f) => f.message), '1');
      expect(await err().recover((_) => 7), const Ok<int>(7));
      expect(
        await err().recoverWith((_) => const Ok<int>(8)),
        const Ok<int>(8),
      );
      expect(await err().mapFailure((_) => _other), const Err<int>(_other));
      expect(await ok().valueOrNull, 1);
      expect(await err().failureOrNull, _failure);
      expect(await ok().mapAsync((n) async => n * 2), const Ok<int>(2));

      final seen = <int>[];
      await ok().onOk(seen.add);
      final failures = <Failure>[];
      await err().onErr(failures.add);
      expect(seen, [1]);
      expect(failures, [_failure]);
    });
  });
}
