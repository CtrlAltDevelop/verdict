import 'package:equatable/equatable.dart';

/// Anything that can go wrong on the way to a value.
///
/// Operations return `Result<T>` carrying a [Failure] on the error path, so
/// callers never have to catch raw exceptions or guess at an error's shape.
///
/// The hierarchy is sealed: a `switch` over a [Failure] is exhaustive, and
/// adding a case here is a breaking change that the compiler will point at
/// every call site for you.
sealed class Failure extends Equatable {
  /// Creates a failure carrying a [title], a user-facing [message] and the
  /// optional [referenceId] / [code] a server supplied alongside them.
  ///
  /// [cause] and [stackTrace] are diagnostics: the original error this
  /// failure was mapped from, and where it was thrown.
  const Failure({
    required this.title,
    required this.message,
    this.referenceId,
    this.code,
    this.cause,
    this.stackTrace,
  });

  /// Where the failure was produced.
  ///
  /// Typically the enclosing method name, as produced by [failureOrigin] — it
  /// is a diagnostic label for logs and bug reports, **not** display copy.
  /// Never render it to users; pick presentation text from the failure's
  /// runtime type instead.
  final String title;

  /// User-facing message describing what went wrong.
  ///
  /// For [ApiFailure] this is normally the server's own message and is safe
  /// to show; for the other variants it may be raw exception text, so prefer
  /// your own copy keyed off the failure type.
  final String message;

  /// Server-side correlation id, when one was supplied.
  ///
  /// Worth surfacing in support-facing UI so a user can quote it.
  final String? referenceId;

  /// HTTP status or application error code, when one was supplied.
  final int? code;

  /// The original error this failure was mapped from, when one is known.
  ///
  /// Meant for logging and crash reporting — never for display, and never
  /// for control flow: reaching back into an SDK-specific error type here
  /// undoes the decoupling a [FailureMapper] bought you.
  ///
  /// Deliberately **excluded from equality**, along with [stackTrace], so two
  /// failures describing the same thing stay equal even when they came from
  /// different exception instances. Tests can therefore compare failures
  /// directly without reconstructing the error that produced them.
  final Object? cause;

  /// Where [cause] was thrown, when it was captured.
  ///
  /// Excluded from equality — see [cause].
  final StackTrace? stackTrace;

  @override
  List<Object?> get props => [title, message, referenceId, code];

  @override
  String toString() => '$runtimeType(title: $title, message: $message, '
      'code: $code, referenceId: $referenceId)';
}

/// The server was reached and answered, but reported the operation failed.
///
/// [message], [code] and [referenceId] come from the server's own response,
/// which makes this the one variant whose [message] is generally fit to show
/// to a user as-is.
final class ApiFailure extends Failure {
  /// Creates a failure describing a server-reported error.
  const ApiFailure({
    required super.title,
    required super.message,
    super.code,
    super.referenceId,
    super.cause,
    super.stackTrace,
  });

  /// A copy of this failure with the given fields replaced.
  ApiFailure copyWith({
    String? title,
    String? message,
    int? code,
    String? referenceId,
    Object? cause,
    StackTrace? stackTrace,
  }) =>
      ApiFailure(
        title: title ?? this.title,
        message: message ?? this.message,
        code: code ?? this.code,
        referenceId: referenceId ?? this.referenceId,
        cause: cause ?? this.cause,
        stackTrace: stackTrace ?? this.stackTrace,
      );
}

/// The server could not be reached, or did not answer in time.
///
/// Covers loss of connectivity, timeouts, DNS problems and transport-level
/// errors — anything where retrying later is a plausible recovery.
final class NetworkFailure extends Failure {
  /// Creates a failure describing a transport-level error.
  const NetworkFailure({
    required super.title,
    required super.message,
    super.code,
    super.cause,
    super.stackTrace,
  });

  /// A copy of this failure with the given fields replaced.
  NetworkFailure copyWith({
    String? title,
    String? message,
    int? code,
    Object? cause,
    StackTrace? stackTrace,
  }) =>
      NetworkFailure(
        title: title ?? this.title,
        message: message ?? this.message,
        code: code ?? this.code,
        cause: cause ?? this.cause,
        stackTrace: stackTrace ?? this.stackTrace,
      );
}

/// Something failed in a way that does not fit the other variants.
///
/// Deserialization errors and unexpected exceptions land here. Kept distinct
/// from [NetworkFailure] so the UI can offer different copy and recovery.
final class UnknownFailure extends Failure {
  /// Creates a failure describing an unclassified error.
  const UnknownFailure({
    required super.title,
    required super.message,
    super.cause,
    super.stackTrace,
  });

  /// A copy of this failure with the given fields replaced.
  UnknownFailure copyWith({
    String? title,
    String? message,
    Object? cause,
    StackTrace? stackTrace,
  }) =>
      UnknownFailure(
        title: title ?? this.title,
        message: message ?? this.message,
        cause: cause ?? this.cause,
        stackTrace: stackTrace ?? this.stackTrace,
      );
}

/// The caller is not authenticated, or the session is no longer usable.
///
/// Expected after logout or token expiry. Usually routed to a sign-in screen
/// rather than reported as an error.
final class AuthFailure extends Failure {
  /// Creates a failure describing an absent or unusable session.
  const AuthFailure({
    required super.title,
    required super.message,
    super.cause,
    super.stackTrace,
  });

  /// A copy of this failure with the given fields replaced.
  AuthFailure copyWith({
    String? title,
    String? message,
    Object? cause,
    StackTrace? stackTrace,
  }) =>
      AuthFailure(
        title: title ?? this.title,
        message: message ?? this.message,
        cause: cause ?? this.cause,
        stackTrace: stackTrace ?? this.stackTrace,
      );
}

/// The user backed out of a flow before it completed.
///
/// Not really an error: dismissing a sign-in sheet or a file picker is a
/// routine outcome, and UIs should normally return to their idle state
/// silently instead of reporting anything.
final class CancelledFailure extends Failure {
  /// Creates a failure describing a user-cancelled flow.
  const CancelledFailure({
    super.title = 'Cancelled',
    super.message = 'Cancelled by user',
    super.cause,
    super.stackTrace,
  });

  /// A copy of this failure with the given fields replaced.
  CancelledFailure copyWith({
    String? title,
    String? message,
    Object? cause,
    StackTrace? stackTrace,
  }) =>
      CancelledFailure(
        title: title ?? this.title,
        message: message ?? this.message,
        cause: cause ?? this.cause,
        stackTrace: stackTrace ?? this.stackTrace,
      );
}
