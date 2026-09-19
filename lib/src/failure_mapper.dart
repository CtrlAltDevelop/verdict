import 'failure.dart';
import 'result.dart';

/// Turns an arbitrary thrown object into a typed [Failure].
///
/// Implement one per error source you care about — an HTTP client, a native
/// sign-in SDK, a database driver — and keep the source-specific imports
/// inside that implementation. Repositories then catch once and delegate,
/// so the rest of the app only ever sees [Failure]s:
///
/// ```dart
/// Future<Result<User>> getUser() => guard(() async {
///   final dto = await _api.fetchUser();
///   return dto.toDomain();
/// });
/// ```
abstract interface class FailureMapper {
  /// Maps [error] — optionally with its [stackTrace] — to a [Failure].
  Failure map(Object error, [StackTrace? stackTrace]);
}

/// A [FailureMapper] that delegates to [mappers] in order.
///
/// The first mapper whose [ChainedFailureMapper] entry claims the error wins;
/// if none does, [fallback] produces the failure. Use it to compose one
/// mapper per SDK without a single function that imports all of them.
class CompositeFailureMapper implements FailureMapper {
  /// Creates a mapper that tries each of [mappers] in order.
  const CompositeFailureMapper(this.mappers, {required this.fallback});

  /// The mappers to try, in priority order.
  final List<ChainedFailureMapper> mappers;

  /// Produces the failure when no mapper in [mappers] claims the error.
  final FailureMapper fallback;

  @override
  Failure map(Object error, [StackTrace? stackTrace]) {
    for (final mapper in mappers) {
      final failure = mapper.tryMap(error, stackTrace);
      if (failure != null) return failure;
    }
    return fallback.map(error, stackTrace);
  }
}

/// A mapper that handles only the errors it recognises.
///
/// Returning `null` from [tryMap] passes the error to the next mapper in a
/// [CompositeFailureMapper].
abstract interface class ChainedFailureMapper {
  /// Maps [error] to a [Failure], or returns `null` to decline it.
  Failure? tryMap(Object error, [StackTrace? stackTrace]);
}

/// Maps anything to an [UnknownFailure], surfacing an [Exception]'s message
/// where there is one.
///
/// Useful as the [CompositeFailureMapper.fallback].
class DefaultFailureMapper implements FailureMapper {
  /// Creates the catch-all mapper.
  const DefaultFailureMapper();

  @override
  Failure map(Object error, [StackTrace? stackTrace]) {
    final origin = failureOrigin(stackTrace: stackTrace);
    final message = error is Exception
        ? error.toString().replaceFirst('Exception: ', '')
        : error.toString();
    return UnknownFailure(
      title: origin,
      message: message,
      cause: error,
      stackTrace: stackTrace,
    );
  }
}

/// Runs [body] and converts anything it throws into an [Err] via [mapper].
///
/// This is the one place a repository needs a `try`/`catch`:
///
/// ```dart
/// Future<Result<User>> getUser() =>
///     guard(() async => (await _api.fetchUser()).toDomain(), mapper);
/// ```
///
/// [mapper] defaults to [DefaultFailureMapper], which turns everything into
/// an [UnknownFailure]. That is fine for a script or a first draft, but pass
/// your own mapper anywhere the caller is expected to tell a timeout apart
/// from an expired session.
Future<Result<T>> guard<T>(
  Future<T> Function() body, [
  FailureMapper mapper = const DefaultFailureMapper(),
]) async {
  try {
    return Ok<T>(await body());
  } catch (error, stackTrace) {
    return Err<T>(mapper.map(error, stackTrace));
  }
}

/// The synchronous counterpart to [guard].
Result<T> guardSync<T>(
  T Function() body, [
  FailureMapper mapper = const DefaultFailureMapper(),
]) {
  try {
    return Ok<T>(body());
  } catch (error, stackTrace) {
    return Err<T>(mapper.map(error, stackTrace));
  }
}

/// Best-effort name of the call site that produced a failure, for use as
/// [Failure.title].
///
/// Pass the [stackTrace] that came with the error whenever you have one — it
/// points at where the error was *thrown*. Without it this falls back to
/// [StackTrace.current], which inside a mapper is where the error was
/// *caught*: by then the throwing frame has already unwound.
///
/// Returns the first frame that is not part of `verdict` itself and not from
/// one of [skipFiles] — pass the file names of your own mapper helpers so
/// their frames do not shadow the real origin. Returns `'Unknown Location'`
/// when no frame can be read, as happens on some obfuscated release builds.
///
/// Frames without a name — closures, local functions — are reported by Dart
/// as `someFunction.<anonymous closure>`, so prefer calling this from a named
/// method if you want a precise label.
///
/// This parses a stack trace on every call, so it is meant for error paths
/// only — never call it on a hot path.
String failureOrigin({
  StackTrace? stackTrace,
  Set<String> skipFiles = const {},
}) {
  // Matched by package URI, not by file name: `result.dart` and
  // `failure.dart` are names a host app is very likely to use too, and
  // skipping those frames would hide the very call site we are looking for.
  const ownPackage = 'package:verdict/';

  for (final line in (stackTrace ?? StackTrace.current).toString().split(
    '\n',
  )) {
    if (line.trim().isEmpty) continue;
    if (line.contains(ownPackage)) continue;
    if (skipFiles.any(line.contains)) continue;

    final match =
        RegExp(r'#\d+\s+([^\s]+)\s+\(').firstMatch(line) ??
        RegExp(r'#\d+\s+([^\s]+)').firstMatch(line);
    final method = match?.group(1);
    if (method != null) return method;
  }
  return 'Unknown Location';
}
