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

  /// The value when this is an [Ok], otherwise [fallback].
  T getOrElse(T fallback) => switch (this) {
        Ok(:final value) => value,
        Err() => fallback,
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
  }) =>
      switch (this) {
        Ok(:final value) => onOk(value),
        Err(:final failure) => onErr(failure),
      };

  /// Applies [transform] to the value of an [Ok], passing an [Err] through
  /// untouched.
  Result<R> map<R>(R Function(T value) transform) => switch (this) {
        Ok(:final value) => Ok<R>(transform(value)),
        Err(:final failure) => Err<R>(failure),
      };

  /// Chains another fallible operation onto an [Ok], passing an [Err]
  /// through untouched.
  Result<R> flatMap<R>(Result<R> Function(T value) transform) => switch (this) {
        Ok(:final value) => transform(value),
        Err(:final failure) => Err<R>(failure),
      };
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
