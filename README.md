<div align="center">

# Respondo gRPC 🛰️

**Consistent response envelopes for gRPC services — real status codes, structured errors, one line per reply.**

[![CI Suite](https://github.com/spatelpatidar/respondo-grpc/actions/workflows/ci.yml/badge.svg)](https://github.com/spatelpatidar/respondo-grpc/actions/workflows/ci.yml)
[![Gem Version](https://badge.fury.io/rb/respondo-grpc.svg)](https://rubygems.org/gems/respondo-grpc)
[![License: Apache 2.0](https://img.shields.io/badge/License-Apache2.0-green.svg)](LICENSE)
[![Ruby](https://img.shields.io/badge/Ruby-2.7%2B-red)](https://www.ruby-lang.org/)

</div>

---

`respondo-grpc` is the gRPC sibling of [`respondo`](https://github.com/spatelpatidar/respondo) (JSON) and [`respondo-graphql`](https://github.com/spatelpatidar/respondo-graphql). It is a **standalone gem** with its own namespace (`RespondoGrpc`), config and protobuf message. Install any of the three, or all of them.

Same idea, same helper names and codes: one expressive helper per situation (`render_grpc_ok`, `render_grpc_not_found`, `render_grpc_unprocessable`, …). What changes is the transport:

| | respondo (JSON) | respondo-graphql | respondo-grpc |
|---|---|---|---|
| Envelope | `success, message, data, errors, meta` | `data, errors, extensions` | `respondo.v1.Response` message |
| Failure signal | HTTP status | `errors[]` (+ HTTP status) | **gRPC status code** + envelope |
| Typed payloads | no | no | yes (`google.protobuf.Any`) |

## Install

```ruby
# Gemfile
gem "respondo-grpc"
```

```bash
bundle install
```

## Use the envelope in your `.proto`

The gem ships `proto/respondo/v1/response.proto`. Import it and return it from any rpc:

```proto
syntax = "proto3";
package example.users.v1;

import "respondo/v1/response.proto";

service UserService {
  rpc GetUser(GetUserRequest) returns (respondo.v1.Response);
}
```

Compile your protos with the gem's `proto/` directory on the include path:

```bash
GEM_PROTO="$(bundle exec ruby -e 'puts File.join(Gem.loaded_specs["respondo-grpc"].full_gem_path, "proto")')"
grpc_tools_ruby_protoc -I proto -I "$GEM_PROTO" --ruby_out=gen --grpc_out=gen proto/users/v1/users.proto
```

The compiled `Respondo::V1::Response` class comes with the gem; you do not compile it yourself.

## Usage

```ruby
class UserService < Example::Users::V1::UserService::Service
  include RespondoGrpc::ServiceHelpers

  def get_user(request, call)
    user = User.find_by(id: request.id)
    return render_grpc_not_found(message: "User not found", call: call) unless user

    render_grpc_ok(data: user, message: "User fetched", call: call)
  end

  def create_user(request, call)
    user = User.new(name: request.name, email: request.email)
    if user.save
      render_grpc_created(data: user, message: "Account created", call: call)
    else
      render_grpc_unprocessable(message: "Validation failed", errors: user.errors, call: call)
    end
  end
end
```

* **Success helpers return** the `Respondo::V1::Response`. Make the call the last expression of the rpc.
* **Error helpers raise** `GRPC::BadStatus` with the mapped gRPC status (`NOT_FOUND`, `INVALID_ARGUMENT`, …). The message is the status detail, and the whole envelope rides in the `respondo-response-bin` trailing metadata. `return render_grpc_not_found(...)` reads naturally and works in both modes (see `always_ok`).
* `call:` is optional. Pass the rpc's second argument to let `include_request_id` copy the client's `x-request-id` into `meta`.

**What the client receives** for `render_grpc_ok(data: { id: 1 }, message: "User fetched")` (shown as JSON):

```json
{
  "success": true,
  "message": "User fetched",
  "data": { "id": 1 },
  "meta": { "timestamp": "2026-10-26T10:30:00Z", "code": 200, "status": "ok" }
}
```

and for `render_grpc_unprocessable(message: "Validation failed", errors: { email: ["is invalid"] })`, a call that finishes with `INVALID_ARGUMENT` (3) and this envelope in its trailers:

```json
{
  "message": "Validation failed",
  "errors": [{ "field": "email", "messages": ["is invalid"] }],
  "meta": { "timestamp": "2026-10-26T10:30:00Z", "code": 422, "status": "unprocessable_content", "grpcCode": 3 }
}
```

### What goes where

| You pass | Where it ends up |
|---|---|
| `data:` hash / array / scalar / ActiveRecord | `Response.data` (`google.protobuf.Value`) |
| `data:` a **protobuf message** | `Response.payload` (`google.protobuf.Any`), so the client can unpack a real class |
| `message:` | `Response.message`, and the gRPC status detail on failure |
| `errors: { field: [...] }` / `ActiveModel::Errors` | `Response.errors[]` (`field`, `messages`) |
| `pagination: { current_page:, per_page:, total_pages:, total_count:, next_page:, prev_page: }` | `Response.meta.pagination` (other keys are ignored) |
| `meta: { ... }` and `config.default_meta` | `Response.meta.extra` (`google.protobuf.Struct`) |

`google.protobuf.Value` has a single number type, so numbers inside `data` come back as floats (`1.0`). Use a typed payload when exact integers matter.

## Reading replies on the client

```ruby
stub = Example::Users::V1::UserService::Stub.new("localhost:50051", :this_channel_is_insecure)

begin
  response = stub.get_user(Example::Users::V1::GetUserRequest.new(id: 42),
                           metadata: { "x-request-id" => "abc-123" })

  user = response.payload.unpack(Example::Users::V1::User)    # typed payload
  RespondoGrpc::ClientHelpers.to_h(response)[:data]           # JSON-like data, as plain Ruby
rescue GRPC::BadStatus => e
  failure = RespondoGrpc::ClientHelpers.error_hash(e)
  failure[:message]            # => "User not found"
  failure[:errors]             # => { email: ["is invalid"] }
  failure[:meta][:grpc_code]   # => 5
end
```

`error_hash` falls back to the status details when the server sent no envelope, so there is always a message to show.

## Helpers

Every helper takes `message:`, `meta:` and `call:`. Success helpers also take `data:` and `pagination:`; error helpers take `errors:`.

| Kind | Helpers |
|---|---|
| Success (2xx) | `render_grpc_ok`, `_created`, `_accepted`, `_non_authoritative`, `_partial_content`, `_multi_status`, `_already_reported`, `_im_used`; without `data:`: `_no_content`, `_reset_content` |
| Client errors (4xx) | `render_grpc_bad_request`, `_unauthorized`, `_forbidden`, `_not_found`, `_conflict`, `_gone`, `_unprocessable`, `_too_many_requests`, … (all 29) |
| Server errors (5xx) | `render_grpc_server_error`, `_not_implemented`, `_bad_gateway`, `_service_unavailable`, `_gateway_timeout`, … (all 11) |

The names and numeric codes match `respondo-graphql`, so `meta.code` means the same thing in every envelope. 1xx and 3xx helpers are not provided: they are HTTP transport concepts with no meaning in gRPC.

Prefer shorter names? `include RespondoGrpc::ShortHelpers` gives you `render_ok`, `render_not_found`, … as aliases. They are never mixed in automatically, because those are the names the JSON gem uses in controllers.

### HTTP code → gRPC status

| HTTP-style code | gRPC status | | HTTP-style code | gRPC status |
|---|---|---|---|---|
| 400, 406, 411, 414, 415, 422 | `INVALID_ARGUMENT` (3) | | 409 | `ALREADY_EXISTS` (6) |
| 401, 407, 511 | `UNAUTHENTICATED` (16) | | 402, 412, 417, 421, 423–426, 428 | `FAILED_PRECONDITION` (9) |
| 403, 451 | `PERMISSION_DENIED` (7) | | 413, 429, 431, 507 | `RESOURCE_EXHAUSTED` (8) |
| 404, 410 | `NOT_FOUND` (5) | | 416 | `OUT_OF_RANGE` (11) |
| 408, 504 | `DEADLINE_EXCEEDED` (4) | | 405, 501, 505, 510 | `UNIMPLEMENTED` (12) |
| 500, 506, 508 | `INTERNAL` (13) | | 502, 503 | `UNAVAILABLE` (14) |
| 418 | `UNKNOWN` (2) | | | |

Disagree with one? `config.status_map = { 409 => :aborted }`.

## Configuration

```ruby
RespondoGrpc.configure do |config|
  config.default_success_message = "Success"
  config.default_error_message   = "An error occurred"
  config.include_request_id      = false          # copy x-request-id into meta.request_id
  config.request_id_key          = "x-request-id" # metadata key to read it from
  config.always_ok               = false          # see below
  config.status_map              = {}             # e.g. { 409 => :aborted }
  config.default_meta            = { api_version: "v1" }
  config.serializer              = ->(obj) { MySerializer.new(obj).as_json }
end
```

**`always_ok`** — by default failures finish the call with a real gRPC status code, which is what interceptors, retries, load balancers and monitoring understand. Set `config.always_ok = true` to answer failures as a normal reply (status `OK`) with `success: false` and `meta.grpc_code` in the message, if your clients only look at the message body.

## Development

```bash
bundle install
bundle exec rspec          # specs
bundle exec rake proto     # recompile the .proto files (needs grpc-tools)
bundle exec rake publish   # spec → build → push
```

## License

Apache-2.0
