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
