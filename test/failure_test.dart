import 'package:test/test.dart';
import 'package:verdict/verdict.dart';

void main() {
  group('equality', () {
    test('same variant with same fields is equal', () {
      expect(
        const ApiFailure(
          title: 'a',
          message: 'b',
          code: 1,
          referenceId: 'r',
        ),
        const ApiFailure(
          title: 'a',
          message: 'b',
          code: 1,
          referenceId: 'r',
        ),
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
}
