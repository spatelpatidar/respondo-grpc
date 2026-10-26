# Changelog

## [1.0.0] — Initial release

### Added
- `respondo.v1.Response` protobuf envelope (`proto/respondo/v1/response.proto`):
  `success`, `message`, `data` (`google.protobuf.Value`), `payload` (`google.protobuf.Any`),
  `errors` (`FieldError`), `meta` (`request_id`, `timestamp`, `code`, `status`, `grpc_code`,
  `error_code`, `pagination`, `extra`).
- `RespondoGrpc::ServiceHelpers`: `render_grpc_*` helpers for every 2xx / 4xx / 5xx situation
  (same names and codes as the respondo-graphql helpers, with `call:` for the request id).
  Success helpers return the envelope; error helpers raise `GRPC::BadStatus` with the mapped
  gRPC status and the envelope in the `respondo-response-bin` trailing metadata.
- `RespondoGrpc::ShortHelpers`: opt-in short names (`render_ok`, `render_not_found`, …).
- `RespondoGrpc::StatusMap`: HTTP-style code → gRPC status table, overridable with
  `config.status_map`.
- `RespondoGrpc::ClientHelpers`: `to_h`, `error_response` and `error_hash` for reading replies
  and failures on the client.
- Protobuf messages passed as `data:` travel as typed payloads (`Any`); hashes, arrays and
  ActiveRecord records travel as JSON-like `data`.
- Configuration: `default_success_message`, `default_error_message`, `include_request_id`,
  `request_id_key`, `serializer`, `default_meta`, `always_ok`, `status_map`.