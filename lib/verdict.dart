/// A sealed [Result] type and a structured [Failure] hierarchy, so fallible
/// calls return a typed verdict instead of throwing across layer boundaries.
///
/// ```dart
/// Future<Result<User>> getUser() =>
///     guard(() async => _api.fetchUser(), mapper);
///
/// switch (await getUser()) {
///   case Ok(:final value):
///     print(value.name);
///   case Err(:final failure):
///     log(failure.message);
/// }
/// ```
library;

export 'src/failure.dart';
export 'src/failure_mapper.dart';
export 'src/result.dart';
