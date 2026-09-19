import 'failure.dart';

/// The outcome of an operation that can fail: either an [Ok] carrying a
/// value, or an [Err] carrying a [Failure].
///
/// Returning a [Result] keeps failures in the type signature instead of in
/// the control flow, so a caller cannot forget that an operation can fail.
/// The type is sealed, so a `switch` over it is exhaustive:
///
/// ```dart
/// final result = await repository.getUser();
/// switch (result) {
///   case Ok(:final value):
///     print(value.name);
///   case Err(:final failure):
///     log(failure.message);
/// }
/// ```
sealed class Result<T> {
  /// Creates a result. Use [Ok] or [Err].
  const Result();

  /// A successful result carrying [value]. An alias for [Ok].
  const factory Result.ok(T value) = Ok<T>;

  /// A failed result carrying [failure]. An alias for [Err].
  const factory Result.err(Failure failure) = Err<T>;

  /// Collects [results] into a single result holding every value, in order.
  ///
  /// Short-circuits on the first [Err] and returns it, so the values are
  /// either all present or none are:
  ///
  /// ```dart
  /// Result.collect([Ok(1), Ok(2)]);        // Ok([1, 2])
  /// Result.collect([Ok(1), Err(failure)]); // Err(failure)
  /// ```
  static Result<List<T>> collect<T>(Iterable<Result<T>> results) {
    final values = <T>[];
    for (final result in results) {
      switch (result) {
        case Ok(:final value):
          values.add(value);
        case Err(:final failure):
          return Err<List<T>>(failure);
      }
    }
    return Ok<List<T>>(values);
  }

  /// Whether this is an [Ok].
  bool get isOk => this is Ok<T>;

  /// Whether this is an [Err].
  bool get isErr => this is Err<T>;

  /// The value when this is an [Ok], or `null` when it is an [Err].
  ///
  /// Note that a successful `Result<T?>` may itself hold `null`, so a `null`
  /// here does not on its own prove failure — check [isErr] when the
  /// distinction matters.
  T? get valueOrNull => switch (this) {
    Ok(:final value) => value,
    Err() => null,
  };

  /// The failure when this is an [Err], or `null` when it is an [Ok].
  Failure? get failureOrNull => switch (this) {
    Ok() => null,
    Err(:final failure) => failure,
  };

  /// The value when this is an [Ok], otherwise throws a [FailureException].
  ///
  /// Only for the edges where a failure genuinely cannot be handled — a test
  /// assertion, or a `main` that should crash loudly. Everywhere else,
  /// prefer [fold], [getOrElse] or a `switch`: throwing here puts the error
  /// back into the control flow this package exists to keep it out of.
  T get valueOrThrow => switch (this) {
    Ok(:final value) => value,
    Err(:final failure) => throw FailureException(failure),
  };

  /// The value when this is an [Ok], otherwise [fallback].
  T getOrElse(T fallback) => switch (this) {
    Ok(:final value) => value,
    Err() => fallback,
  };

  /// The value when this is an [Ok], otherwise the result of [fallback].
  ///
  /// The lazy counterpart to [getOrElse]: use it when the fallback is
  /// expensive, or when it depends on what went wrong.
  T getOrElseWith(T Function(Failure failure) fallback) => switch (this) {
    Ok(:final value) => value,
    Err(:final failure) => fallback(failure),
  };

  /// Collapses both branches into a single value of type [R].
  ///
  /// ```dart
  /// final label = result.fold(
  ///   onOk: (user) => user.name,
  ///   onErr: (failure) => failure.message,
  /// );
  /// ```
  R fold<R>({
    required R Function(T value) onOk,
    required R Function(Failure failure) onErr,
  }) => switch (this) {
    Ok(:final value) => onOk(value),
    Err(:final failure) => onErr(failure),
  };

  /// Applies [transform] to the value of an [Ok], passing an [Err] through
  /// untouched.
  Result<R> map<R>(R Function(T value) transform) => switch (this) {
    Ok(:final value) => Ok<R>(transform(value)),
    Err(:final failure) => Err<R>(failure),
  };

  /// The asynchronous counterpart to [map].
  Future<Result<R>> mapAsync<R>(Future<R> Function(T value) transform) async =>
      switch (this) {
        Ok(:final value) => Ok<R>(await transform(value)),
        Err(:final failure) => Err<R>(failure),
      };

  /// Chains another fallible operation onto an [Ok], passing an [Err]
  /// through untouched.
  Result<R> flatMap<R>(Result<R> Function(T value) transform) => switch (this) {
    Ok(:final value) => transform(value),
    Err(:final failure) => Err<R>(failure),
  };

  /// The asynchronous counterpart to [flatMap].
  ///
  /// ```dart
  /// final profile = await (await repository.getUser(id))
  ///     .flatMapAsync((user) => repository.getProfile(user.id));
  /// ```
  Future<Result<R>> flatMapAsync<R>(
    Future<Result<R>> Function(T value) transform,
  ) async => switch (this) {
    Ok(:final value) => await transform(value),
    Err(:final failure) => Err<R>(failure),
  };

  /// Applies [transform] to the failure of an [Err], passing an [Ok] through
  /// untouched.
  ///
  /// Useful at a layer boundary, to re-label a failure with the origin or
  /// wording that makes sense one level up.
  Result<T> mapFailure(Failure Function(Failure failure) transform) =>
      switch (this) {
        Ok() => this,
        Err(:final failure) => Err<T>(transform(failure)),
      };

  /// Turns an [Err] back into an [Ok] using [transform], leaving an [Ok]
  /// untouched.
  ///
  /// ```dart
  /// final settings = (await load()).recover((_) => Settings.defaults());
  /// ```
  Result<T> recover(T Function(Failure failure) transform) => switch (this) {
    Ok() => this,
    Err(:final failure) => Ok<T>(transform(failure)),
  };

  /// Like [recover], but [transform] may itself fail — a retry, or a fall
  /// back to a cache that might be empty.
  Result<T> recoverWith(Result<T> Function(Failure failure) transform) =>
      switch (this) {
        Ok() => this,
        Err(:final failure) => transform(failure),
      };

  /// Runs [action] when this is an [Ok] and returns this result unchanged.
  ///
  /// For side effects — logging, analytics, a cache write — in the middle of
  /// a chain.
  Result<T> onOk(void Function(T value) action) {
    if (this case Ok(:final value)) action(value);
    return this;
  }

  /// Runs [action] when this is an [Err] and returns this result unchanged.
  Result<T> onErr(void Function(Failure failure) action) {
    if (this case Err(:final failure)) action(failure);
    return this;
  }
}

/// A successful [Result] carrying its [value].
final class Ok<T> extends Result<T> {
  /// Creates a successful result carrying [value].
  const Ok(this.value);

  /// The value the operation produced.
  final T value;

  @override
  String toString() => 'Ok($value)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Ok<T> && other.value == value;

  @override
  int get hashCode => Object.hash(Ok<T>, value);
}

/// A failed [Result] carrying its [failure].
final class Err<T> extends Result<T> {
  /// Creates a failed result carrying [failure].
  const Err(this.failure);

  /// What went wrong.
  final Failure failure;

  @override
  String toString() => 'Err($failure)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Err<T> && other.failure == failure;

  @override
  int get hashCode => Object.hash(Err<T>, failure);
}

/// Thrown by [Result.valueOrThrow] when the result is an [Err].
///
/// Carries the [failure] itself, so a `catch` at the top of the app can still
/// report it properly instead of losing it to a string.
class FailureException implements Exception {
  /// Wraps [failure] so it can cross a throwing boundary.
  const FailureException(this.failure);

  /// The failure this exception was built from.
  final Failure failure;

  @override
  String toString() => 'FailureException($failure)';
}

/// Flattens a nested result, as produced by mapping with a fallible
/// transform where [Result.flatMap] was wanted.
extension NestedResult<T> on Result<Result<T>> {
  /// Collapses `Result<Result<T>>` into `Result<T>`.
  Result<T> flatten() => switch (this) {
    Ok(:final value) => value,
    Err(:final failure) => Err<T>(failure),
  };
}

/// Chaining for results that have not been awaited yet, so a pipeline reads
/// forwards instead of nesting `await`s:
///
/// ```dart
/// final name = await repository
///     .getUser(id)
///     .flatMapAsync((user) => repository.getProfile(user.id))
///     .map((profile) => profile.displayName)
///     .getOrElse('anonymous');
/// ```
extension FutureResult<T> on Future<Result<T>> {
  /// Awaits this result, then applies [Result.map].
  Future<Result<R>> map<R>(R Function(T value) transform) async =>
      (await this).map(transform);

  /// Awaits this result, then applies [Result.mapAsync].
  Future<Result<R>> mapAsync<R>(Future<R> Function(T value) transform) async =>
      (await this).mapAsync(transform);

  /// Awaits this result, then applies [Result.flatMap].
  Future<Result<R>> flatMap<R>(Result<R> Function(T value) transform) async =>
      (await this).flatMap(transform);

  /// Awaits this result, then applies [Result.flatMapAsync].
  Future<Result<R>> flatMapAsync<R>(
    Future<Result<R>> Function(T value) transform,
  ) async => (await this).flatMapAsync(transform);

  /// Awaits this result, then applies [Result.mapFailure].
  Future<Result<T>> mapFailure(Failure Function(Failure failure) transform) =>
      then((result) => result.mapFailure(transform));

  /// Awaits this result, then applies [Result.recover].
  Future<Result<T>> recover(T Function(Failure failure) transform) =>
      then((result) => result.recover(transform));

  /// Awaits this result, then applies [Result.recoverWith].
  Future<Result<T>> recoverWith(
    Result<T> Function(Failure failure) transform,
  ) => then((result) => result.recoverWith(transform));

  /// Awaits this result, then applies [Result.onOk].
  Future<Result<T>> onOk(void Function(T value) action) =>
      then((result) => result.onOk(action));

  /// Awaits this result, then applies [Result.onErr].
  Future<Result<T>> onErr(void Function(Failure failure) action) =>
      then((result) => result.onErr(action));

  /// Awaits this result, then applies [Result.fold].
  Future<R> fold<R>({
    required R Function(T value) onOk,
    required R Function(Failure failure) onErr,
  }) => then((result) => result.fold(onOk: onOk, onErr: onErr));

  /// Awaits this result, then applies [Result.getOrElse].
  Future<T> getOrElse(T fallback) =>
      then((result) => result.getOrElse(fallback));

  /// Awaits this result, then applies [Result.getOrElseWith].
  Future<T> getOrElseWith(T Function(Failure failure) fallback) =>
      then((result) => result.getOrElseWith(fallback));

  /// Awaits this result, then reads [Result.valueOrNull].
  Future<T?> get valueOrNull => then((result) => result.valueOrNull);

  /// Awaits this result, then reads [Result.failureOrNull].
  Future<Failure?> get failureOrNull => then((result) => result.failureOrNull);
}

/// Stand-in for the absence of a value, since Dart has no `Unit` of its own.
///
/// Use `Result<Unit>` for operations whose success carries no payload — a
/// logout or a delete — and return [unit] on the success path.
final class Unit {
  /// Creates the unit value. Prefer the [unit] constant.
  const Unit();

  @override
  String toString() => '()';

  @override
  bool operator ==(Object other) => other is Unit;

  @override
  int get hashCode => (Unit).hashCode;
}

/// The single [Unit] value.
const Unit unit = Unit();
