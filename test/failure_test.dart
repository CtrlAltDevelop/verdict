import 'package:test/test.dart';
import 'package:verdict/verdict.dart';

void main() {
  group('equality', () {
    test('same variant with same fields is equal', () {
      expect(
        const ApiFailure(title: 'a', message: 'b', code: 1, referenceId: 'r'),
        const ApiFailure(title: 'a', message: 'b', code: 1, referenceId: 'r'),
      );
    });

    test('differing fields are not equal', () {
      expect(
        const ApiFailure(title: 'a', message: 'b'),
        isNot(const ApiFailure(title: 'a', message: 'c')),
      );
    });

    test('different variants with identical fields are not equal', () {
      expect(
        const ApiFailure(title: 'a', message: 'b'),
        isNot(const NetworkFailure(title: 'a', message: 'b')),
      );
    });
  });

  group('CancelledFailure', () {
    test('carries usable defaults', () {
      const failure = CancelledFailure();

      expect(failure.title, 'Cancelled');
      expect(failure.message, 'Cancelled by user');
      expect(failure.code, isNull);
    });

    test('accepts an overridden origin', () {
      expect(const CancelledFailure(title: 'signIn').title, 'signIn');
    });
  });

  test('optional server fields default to null', () {
    const failure = NetworkFailure(title: 'a', message: 'b');

    expect(failure.code, isNull);
    expect(failure.referenceId, isNull);
  });

  test('toString includes the diagnostic fields', () {
    const failure = ApiFailure(
      title: 'getUser',
      message: 'nope',
      code: 400,
      referenceId: 'ref-1',
    );

    expect(
      failure.toString(),
      'ApiFailure(title: getUser, message: nope, code: 400, '
      'referenceId: ref-1)',
    );
  });

  test('the hierarchy switches exhaustively without a default', () {
    String describe(Failure failure) => switch (failure) {
      ApiFailure() => 'api',
      NetworkFailure() => 'network',
      UnknownFailure() => 'unknown',
      AuthFailure() => 'auth',
      CancelledFailure() => 'cancelled',
    };

    expect(describe(const ApiFailure(title: 'a', message: 'b')), 'api');
    expect(describe(const NetworkFailure(title: 'a', message: 'b')), 'network');
    expect(describe(const UnknownFailure(title: 'a', message: 'b')), 'unknown');
    expect(describe(const AuthFailure(title: 'a', message: 'b')), 'auth');
    expect(describe(const CancelledFailure()), 'cancelled');
  });

  group('diagnostics', () {
    test('cause and stackTrace are carried but excluded from equality', () {
      final trace = StackTrace.current;
      final withCause = UnknownFailure(
        title: 'test',
        message: 'boom',
        cause: const FormatException('bad json'),
        stackTrace: trace,
      );
      const without = UnknownFailure(title: 'test', message: 'boom');

      expect(withCause.cause, isA<FormatException>());
      expect(withCause.stackTrace, trace);
      expect(withCause, without, reason: 'diagnostics must not split equality');
      expect(withCause.hashCode, without.hashCode);
    });
  });

  group('copyWith', () {
    test('replaces only the fields it is given', () {
      const original = ApiFailure(
        title: 'origin',
        message: 'boom',
        code: 500,
        referenceId: 'ref-1',
      );

      expect(
        original.copyWith(title: 'newOrigin'),
        const ApiFailure(
          title: 'newOrigin',
          message: 'boom',
          code: 500,
          referenceId: 'ref-1',
        ),
      );
      expect(original.copyWith(), original);
    });

    test('keeps each variant its own type', () {
      expect(
        const NetworkFailure(title: 't', message: 'm').copyWith(code: 408),
        const NetworkFailure(title: 't', message: 'm', code: 408),
      );
      expect(
        const AuthFailure(title: 't', message: 'm').copyWith(message: 'gone'),
        const AuthFailure(title: 't', message: 'gone'),
      );
      expect(
        const CancelledFailure().copyWith(title: 'picker'),
        const CancelledFailure(title: 'picker'),
      );
      expect(
        const UnknownFailure(title: 't', message: 'm').copyWith(title: 'u'),
        const UnknownFailure(title: 'u', message: 'm'),
      );
    });
  });
}
