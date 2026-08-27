import 'package:test/test.dart';
import 'package:verdict/verdict.dart';

class _TimeoutError implements Exception {}

class _TimeoutMapper implements ChainedFailureMapper {
  const _TimeoutMapper();

  @override
  Failure? tryMap(Object error, [StackTrace? stackTrace]) =>
      error is _TimeoutError
          ? const NetworkFailure(title: 'timeout', message: 'timed out')
          : null;
}

class _NeverMapper implements ChainedFailureMapper {
  const _NeverMapper();

  @override
  Failure? tryMap(Object error, [StackTrace? stackTrace]) => null;
}

class _FixedMapper implements FailureMapper {
  const _FixedMapper(this.failure);

  final Failure failure;

  @override
  Failure map(Object error, [StackTrace? stackTrace]) => failure;
}

/// Top-level so the stack frame carries a real name — a local function or a
/// closure is reported as `main.<anonymous closure>`.
String namedCaller() => failureOrigin();

/// Throws from a named frame, so the origin recorded on the failure can be
/// checked against a real function name.
int throwingOperation() => throw Exception('boom');

void main() {
  group('DefaultFailureMapper', () {
    test('strips the Exception prefix from a message', () {
      final failure = const DefaultFailureMapper().map(Exception('boom'));

      expect(failure, isA<UnknownFailure>());
      expect(failure.message, 'boom');
    });

    test('maps a non-Exception throwable via toString', () {
      final failure = const DefaultFailureMapper().map('raw');

      expect(failure, isA<UnknownFailure>());
      expect(failure.message, 'raw');
    });
  });

  group('CompositeFailureMapper', () {
    const composite = CompositeFailureMapper(
      [_TimeoutMapper()],
      fallback: DefaultFailureMapper(),
    );

    test('uses the mapper that claims the error', () {
      final failure = composite.map(_TimeoutError());

      expect(failure, isA<NetworkFailure>());
      expect(failure.message, 'timed out');
    });

    test('falls back when no mapper claims the error', () {
      final failure = composite.map(Exception('other'));

      expect(failure, isA<UnknownFailure>());
      expect(failure.message, 'other');
    });

    test('tries mappers in order and skips those that decline', () {
      const ordered = CompositeFailureMapper(
        [_NeverMapper(), _TimeoutMapper()],
        fallback: DefaultFailureMapper(),
      );

      expect(ordered.map(_TimeoutError()), isA<NetworkFailure>());
    });
  });

  group('guard', () {
    const mapper = _FixedMapper(ApiFailure(title: 't', message: 'mapped'));

    test('wraps a returned value in Ok', () async {
      expect(await guard(() async => 42, mapper), const Ok<int>(42));
    });

    test('converts a thrown error into Err via the mapper', () async {
      final result = await guard<int>(
        () async => throw Exception('boom'),
        mapper,
      );

      expect(result.isErr, isTrue);
      expect(result.failureOrNull?.message, 'mapped');
    });
  });

  group('guardSync', () {
    const mapper = _FixedMapper(ApiFailure(title: 't', message: 'mapped'));

    test('wraps a returned value in Ok', () {
      expect(guardSync(() => 42, mapper), const Ok<int>(42));
    });

    test('converts a thrown error into Err via the mapper', () {
      final result = guardSync<int>(() => throw Exception('boom'), mapper);

      expect(result.isErr, isTrue);
      expect(result.failureOrNull?.message, 'mapped');
    });
  });

  group('failureOrigin', () {
    test('names the calling function', () {
      expect(namedCaller(), contains('namedCaller'));
    });

    test('reports anonymous frames as such rather than failing', () {
      final origin = [0].map((_) => failureOrigin()).first;

      expect(origin, contains('anonymous'));
    });

    test('skips frames from files named in skipFiles', () {
      final origin = failureOrigin(skipFiles: {'failure_mapper_test.dart'});

      expect(origin, isNot(contains('main')));
    });

    test('always returns a non-empty label', () {
      expect(failureOrigin(), isNotEmpty);
    });

    test('does not skip caller frames just for being named result.dart', () {
      // The package's own frames are matched by package URI, so a host app
      // may name its files result.dart or failure.dart without its frames
      // being swallowed.
      expect(namedCaller(), isNot('Unknown Location'));
      expect(namedCaller(), contains('namedCaller'));
    });

    test('a failure built through guard names the throwing call site', () {
      final result = guardSync<int>(
        throwingOperation,
        const DefaultFailureMapper(),
      );

      expect(result.failureOrNull?.title, contains('throwingOperation'));
    });
  });

  group('guard without an explicit mapper', () {
    test('falls back to DefaultFailureMapper on the async path', () async {
      final result = await guard<int>(() async => throw Exception('boom'));

      expect(result.failureOrNull, isA<UnknownFailure>());
      expect(result.failureOrNull?.message, 'boom');
      expect(result.failureOrNull?.cause, isA<Exception>());
      expect(result.failureOrNull?.stackTrace, isNotNull);
    });

    test('falls back to DefaultFailureMapper on the sync path', () {
      final result = guardSync<int>(() => throw Exception('boom'));

      expect(result.failureOrNull, isA<UnknownFailure>());
      expect(result.failureOrNull?.message, 'boom');
    });

    test('still returns an Ok when nothing throws', () async {
      expect(await guard<int>(() async => 1), const Ok<int>(1));
      expect(guardSync<int>(() => 1), const Ok<int>(1));
    });
  });
}
