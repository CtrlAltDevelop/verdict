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
  verdict: ^1.1.0
```

Requires Dart 3.13.0 or newer — Flutter 3.47.0 or newer, if you are on
Flutter. There is no `flutter` constraint in `pubspec.yaml`, so the package
still resolves in server and CLI projects with no Flutter SDK installed. For
Dart 3.6–3.12, pin `verdict: ^0.1.0`.

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

On the error side, `mapFailure` re-labels a failure, `recover` turns one back
into a value, and `recoverWith` retries into another `Result`:

```dart
final err = Err<int>(failure);

err.mapFailure((f) => f.copyWith(title: 'loadCount'));  // Err(…)
err.recover((f) => 0);                                  // Ok(0)
err.recoverWith((f) => cache.read());                   // Ok(…) or Err(…)
err.getOrElseWith((f) => f.code ?? -1);                 // fallback from f
```

`onOk` / `onErr` run a side effect and hand the result straight back, and
`valueOrThrow` throws a `FailureException` for the rare edge — a test, a
`main` — where a failure genuinely cannot be handled.

Several results collapse into one with `Result.collect`, which short-circuits
on the first failure, and a nested `Result<Result<T>>` collapses with
`flatten()`:

```dart
Result.collect([Ok(1), Ok(2)]);        // Ok([1, 2])
Result.collect([Ok(1), Err(failure)]); // Err(failure)
```

### Async chaining

Every combinator has an async counterpart (`mapAsync`, `flatMapAsync`), and
the same names exist on `Future<Result<T>>` — so a pipeline reads forwards
instead of nesting `await`s:

```dart
final name = await repository
    .getUser(id)                                          // Future<Result<User>>
    .flatMapAsync((user) => repository.getProfile(user.id))
    .map((profile) => profile.displayName)
    .onErr(logger.warn)
    .getOrElse('anonymous');
```

The first failure short-circuits the rest of the chain, untouched.

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

Each carries `title`, `message`, and optional `referenceId` and `code`, plus
optional `cause` and `stackTrace` diagnostics holding the original error.
Those two are **excluded from equality**, so a failure compares the same
whether or not the error that produced it was kept — tests can match on
failures without reconstructing exceptions. Every variant has a `copyWith`.

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
class HttpFailureMapper implements ChainedFailureMapper {
  const HttpFailureMapper();

  @override
  Failure? tryMap(Object error, [StackTrace? stackTrace]) {
    // Decline anything this mapper does not own; the next one gets a turn.
    if (error is! HttpException) return null;

    final origin = failureOrigin(stackTrace: stackTrace);
    return switch (error) {
      HttpException(isTimeout: true) => NetworkFailure(
        title: origin,
        message: 'The server did not answer in time.',
      ),
      HttpException(status: 401) => AuthFailure(
        title: origin,
        message: 'Session expired.',
      ),
      HttpException(:final status, :final body) => ApiFailure(
        title: origin,
        message: body,
        code: status,
      ),
    };
  }
}

const mapper = CompositeFailureMapper(
  [HttpFailureMapper(), SignInFailureMapper()],
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

`guardSync` is the synchronous counterpart. The mapper is optional and
defaults to `DefaultFailureMapper` — fine for a script, but pass your own
anywhere the caller must tell a timeout apart from an expired session.

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

[`verdict_bloc`](https://pub.dev/packages/verdict_bloc) applies the same ideas
to Flutter: a base state that keeps the last-known good data through transient
error and success states, plus a ready-made paginated list bloc.

It is a **standalone** package, not a companion — it carries its own copy of
these types rather than depending on this one, so a Flutter app needs only
that package. The trade-off is that the two `Failure` types are unrelated: a
`Failure` from one will not satisfy an API expecting the other, and a file
importing both needs a prefix. Use this package for pure-Dart layers and
`verdict_bloc` for Flutter ones, rather than mixing them in a single layer.

## License

MIT — see [LICENSE](LICENSE).
