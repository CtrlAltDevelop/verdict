import 'package:verdict/verdict.dart';

/// A stand-in for whatever HTTP client you actually use.
class HttpTimeoutException implements Exception {
  const HttpTimeoutException(this.seconds);

  final int seconds;
}

/// A stand-in for a server that answered, but said no.
class HttpStatusException implements Exception {
  const HttpStatusException({required this.status, required this.body});

  final int status;
  final String body;
}

/// One mapper per error source keeps SDK-specific imports out of the rest of
/// the app. Each declines what it does not recognise by returning `null`.
class HttpFailureMapper implements ChainedFailureMapper {
  const HttpFailureMapper();

  @override
  Failure? tryMap(Object error, [StackTrace? stackTrace]) {
    // Pass the error's own trace so the origin names where it was thrown,
    // not where it was caught.
    final origin = failureOrigin(stackTrace: stackTrace);
    return switch (error) {
      HttpTimeoutException(:final seconds) => NetworkFailure(
          title: origin,
          message: 'The server did not answer within ${seconds}s.',
        ),
      HttpStatusException(:final status, :final body) when status == 401 =>
        AuthFailure(title: origin, message: body),
      HttpStatusException(:final status, :final body) => ApiFailure(
          title: origin,
          message: body,
          code: status,
        ),
      _ => null,
    };
  }
}

const mapper = CompositeFailureMapper(
  [HttpFailureMapper()],
  fallback: DefaultFailureMapper(),
);

class User {
  const User(this.name);

  final String name;
}

/// A repository catches once, at the boundary, and returns a [Result].
class UserRepository {
  Future<Result<User>> getUser(String id) =>
      guard(() async => _fetch(id), mapper);

  Future<Result<Unit>> logout() => guard(() async {
        // …clear the session…
        return unit;
      }, mapper);

  /// A second fallible call, to show a chain of them.
  Future<Result<String>> getGreeting(String id) =>
      guard(() async => 'welcome, ${(await _fetch(id)).name}', mapper);

  Future<User> _fetch(String id) async {
    if (id == 'slow') throw const HttpTimeoutException(30);
    if (id == 'gone') {
      throw const HttpStatusException(status: 404, body: 'No such user');
    }
    if (id == 'stale') {
      throw const HttpStatusException(status: 401, body: 'Session expired');
    }
    return User('Ada');
  }
}

Future<void> main() async {
  final repository = UserRepository();

  for (final id in ['ada', 'slow', 'gone', 'stale']) {
    final result = await repository.getUser(id);

    // The switch is exhaustive — no default branch, no forgotten error path.
    switch (result) {
      case Ok(:final value):
        print('$id -> welcome, ${value.name}');
      case Err(:final failure):
        print('$id -> ${_describe(failure)}');
    }
  }

  // `fold` collapses both branches when you just want one value out.
  final label = (await repository.getUser('ada')).fold(
    onOk: (user) => user.name,
    onErr: (failure) => failure.message,
  );
  print('label: $label');

  // Operations with nothing to return use Result<Unit>.
  print('logout ok: ${(await repository.logout()).isOk}');

  // Chaining happens on the future itself, so the pipeline reads forwards
  // and the first failure short-circuits everything after it.
  final greeting = await repository
      .getUser('gone')
      .flatMapAsync((user) => repository.getGreeting(user.name))
      .map((line) => line.toUpperCase())
      .onErr((failure) => print('chain failed: ${_describe(failure)}'))
      .getOrElse('(no greeting)');
  print('greeting: $greeting');

  // Several results collapse into one, short-circuiting on the first failure.
  final ids = ['ada', 'grace'];
  final users = Result.collect(
    await Future.wait(ids.map(repository.getUser)),
  ).map((users) => users.map((user) => user.name).join(', '));
  print('collected: ${users.getOrElseWith((f) => f.message)}');
}

/// Presentation picks copy from the failure *type*, never from
/// [Failure.title] — that field is a diagnostic origin, not display text.
String _describe(Failure failure) => switch (failure) {
      ApiFailure(:final message, :final code) => 'server said $code: $message',
      NetworkFailure() => 'Check your connection and try again.',
      AuthFailure() => 'Please sign in again.',
      CancelledFailure() => 'Cancelled.',
      UnknownFailure() => 'Something went wrong.',
    };
