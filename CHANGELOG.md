## 1.2.0

- No change to the published code. CI moved to the shared reusable workflow in
  CtrlAltDevelop/ci-workflows: formatting, `analyze --fatal-infos`, the tests,
  the example, a changelog entry per version, and a pana score with no points
  lost — the same gate across every package here.
- **The SDK floor moves to Dart 3.12.0 / Flutter 3.44.0**, from Dart 3.0.0 /
  Flutter 3.10.0. This is the floor every package here is gated on rather than
  something the code needs — sealed classes and pattern matching are all it
  uses.
- Dependency bounds are explicit ranges rather than carets — a floor that
  resolves on the supported SDK, the next major as the ceiling — so a consumer
  already on an older version in the same major is not forced to move.
- The README carries the pub, pub points, CI and licence badges the other
  packages here carry.

## 1.1.0

Additive only — nothing in 1.0.0 changed shape, so the upgrade is a version
bump.

- Lowered the minimum Dart SDK to `>=3.0.0 <4.0.0`. 1.0.0 required `^3.13.0`,
  but nothing in the package uses a language feature newer than Dart 3.0's
  sealed classes and pattern matching, so the bound was far stricter than the
  code needed. Widening it is not breaking: every 1.0.0 consumer still
  resolves.
- Floated the dependency bounds — `equatable: '>=2.0.0 <3.0.0'` — so
  upgrading `verdict` no longer forces the rest of a resolution forward.

- `Result` gained `mapFailure`, `recover`, `recoverWith`, `getOrElseWith`,
  `valueOrThrow`, the `onOk` / `onErr` side-effect taps, the `mapAsync` /
  `flatMapAsync` async counterparts, and the `Result.ok` / `Result.err`
  constructors.
- `Result.collect` turns an `Iterable<Result<T>>` into a `Result<List<T>>`,
  short-circuiting on the first failure.
- `flatten()` collapses a nested `Result<Result<T>>`.
- A `FutureResult` extension mirrors the whole surface on
  `Future<Result<T>>`, so an async pipeline chains forwards instead of
  nesting `await`s.
- `FailureException` carries a `Failure` across a throwing boundary; it is
  what `valueOrThrow` throws.
- `Failure` gained optional `cause` and `stackTrace` diagnostics, and every
  variant gained `copyWith`. Both new fields are **excluded from equality**,
  so failures compare the same whether or not the original error was kept.
- `DefaultFailureMapper` now records the error and its trace as `cause` and
  `stackTrace`.
- The `mapper` argument of `guard` / `guardSync` is now optional and defaults
  to `DefaultFailureMapper`.

## 1.0.0

First stable release. The API is unchanged from 0.1.0 and is now covered by
semantic versioning: no breaking change to `Result`, `Failure`, the mappers,
`guard` or `failureOrigin` will land outside a 2.0.0.

- **Breaking:** raised the minimum Dart SDK to `^3.13.0`, the version Flutter
  3.47.0 ships. Stay on 0.1.0 if you need Dart 3.6–3.12.

## 0.1.0

Initial release.

- `Result<T>` — a sealed type that is either `Ok<T>` or `Err<T>`, with
  `map`, `flatMap`, `fold`, `getOrElse`, `valueOrNull` and `failureOrNull`.
- `Unit` / `unit` for operations whose success carries no payload.
- `Failure` — a sealed hierarchy of `ApiFailure`, `NetworkFailure`,
  `AuthFailure`, `CancelledFailure` and `UnknownFailure`, each carrying
  `title`, `message` and optional `referenceId` and `code`.
- `FailureMapper` / `ChainedFailureMapper` / `CompositeFailureMapper` /
  `DefaultFailureMapper` for turning SDK-specific errors into `Failure`s
  without the package itself depending on any SDK.
- `guard` and `guardSync` to convert a throwing body into a `Result`.
- `failureOrigin` to label a failure with the call site that produced it.
