# verdict

A sealed `Result` type and a structured `Failure` hierarchy for Dart, so
fallible calls return a typed verdict instead of throwing across layer
boundaries.

No code generation, no Flutter dependency, one small dependency
(`equatable`). Works in Flutter apps, server code, CLIs and shared domain
packages alike.

```dart
Future<Result<User>> getUser(String id) =>
    guard(() async => _api.fetchUser(id), mapper);

switch (await getUser('ada')) {
  case Ok(:final value):
    print('welcome, ${value.name}');
  case Err(:final failure):
    log(failure.message);
}
```

## Why

Exceptions do not appear in a function's type, so nothing stops a caller from
forgetting the error path — the compiler certainly will not. `Result<T>` puts
the failure back in the signature, and because both `Result` and `Failure` are
**sealed**, a `switch` over either is exhaustive: add a failure variant and the
analyzer points at every site that must now handle it.

## Install

```yaml
dependencies:
  verdict: ^0.1.0
```

## Result

`Result<T>` is either `Ok<T>` carrying a value or `Err<T>` carrying a
`Failure`.

```dart
const result = Ok<int>(2);

result.isOk;                       // true
result.valueOrNull;                // 2
result.failureOrNull;              // null
result.getOrElse(0);               // 2

result.map((n) => n * 2);          // Ok(4)
result.flatMap((n) => Ok('$n'));   // Ok('2')

result.fold(                       // collapse both branches to one value
  onOk: (n) => 'got $n',
  onErr: (f) => f.message,
);
```

Pattern matching is the idiomatic way to consume one:

```dart
switch (result) {
  case Ok(:final value):   // …
  case Err(:final failure): // …
}
```

For operations whose success carries no payload, use `Result<Unit>` and return
`const Ok(unit)`:

```dart
Future<Result<Unit>> logout() => guard(() async {
  await _session.clear();
  return unit;
}, mapper);
```

## Failure

Five variants, chosen so the UI can pick a different response for each:

| Variant           | Meaning                                    | Typical response          |
| ----------------- | ------------------------------------------ | ------------------------- |
| `ApiFailure`      | Server answered and reported a failure     | Show the server's message |
| `NetworkFailure`  | Server unreachable, timed out, DNS, etc.   | Offer a retry             |
| `AuthFailure`     | No session, or one no longer usable        | Route to sign-in          |
| `CancelledFailure`| User backed out of a flow                  | Return to idle, silently  |
| `UnknownFailure`  | Anything else (parse errors, bugs)         | Generic error copy        |

Each carries `title`, `message`, and optional `referenceId` and `code`.

> **`title` is a diagnostic origin, not display copy.** It holds the call site
> that produced the failure (see `failureOrigin`) so logs and bug reports can
> say *where*. Only `ApiFailure.message` is generally fit to show a user
> as-is; for the other variants, pick your own copy from the failure's type:
>
> ```dart
> String describe(Failure failure) => switch (failure) {
>   ApiFailure(:final message) => message,
>   NetworkFailure()  => 'Check your connection and try again.',
>   AuthFailure()     => 'Please sign in again.',
>   CancelledFailure()=> 'Cancelled.',
>   UnknownFailure()  => 'Something went wrong.',
> };
> ```

## Mapping errors

`verdict` deliberately ships **no** mappers for specific SDKs — that is what
keeps it dependency-free and usable anywhere. Instead you implement
`ChainedFailureMapper` per error source and compose them, so each SDK's
imports stay in one small file.

```dart
class DioFailureMapper implements ChainedFailureMapper {
  const DioFailureMapper();

  @override
  Failure? tryMap(Object error, [StackTrace? stackTrace]) {
    if (error is! DioException) return null; // decline; try the next mapper
    final origin = failureOrigin(stackTrace: stackTrace);
    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.connectionError => NetworkFailure(
        title: origin,
        message: error.message ?? 'Network error',
      ),
      _ => ApiFailure(
        title: origin,
        message: error.message ?? 'Server error',
        code: error.response?.statusCode,
      ),
    };
  }
}

const mapper = CompositeFailureMapper(
  [DioFailureMapper(), GoogleSignInFailureMapper()],
  fallback: DefaultFailureMapper(),
);
```

`CompositeFailureMapper` tries each mapper in order and uses the first that
does not return `null`; `DefaultFailureMapper` is a catch-all that surfaces an
`Exception`'s message as an `UnknownFailure`.

### guard

`guard` is the one place a repository needs a `try`/`catch`:

```dart
Future<Result<User>> getUser(String id) =>
    guard(() async => (await _api.fetchUser(id)).toDomain(), mapper);
```

`guardSync` is the synchronous counterpart.

### failureOrigin

Returns a best-effort name of the call site, for use as `Failure.title`:

```dart
NetworkFailure(title: failureOrigin(stackTrace: stackTrace), message: '…');
```

**Pass the error's own `stackTrace` whenever you have one.** It names where
the error was *thrown*; without it the function falls back to
`StackTrace.current`, which inside a mapper is where the error was *caught* —
by that point the throwing frame has already unwound.

Use `skipFiles` for your own helper files whose frames would otherwise shadow
the real origin. Closures are reported as `caller.<anonymous closure>`, so
call it from a named method when you want a precise label. It parses a stack
trace, so keep it on error paths only.

## With BLoC

[`verdict_bloc`](https://pub.dev/packages/verdict_bloc) builds on this package
with a base state that keeps the last-known good data through transient error
and success states, plus a ready-made paginated list bloc.

## License

MIT — see [LICENSE](LICENSE).
