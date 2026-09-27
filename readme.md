# Protocol::HTTP2

Provides a low-level implementation of the HTTP/2 protocol.

[![Development Status](https://github.com/socketry/protocol-http2/workflows/Test/badge.svg)](https://github.com/socketry/protocol-http2/actions?workflow=Test)

## Usage

Please see the [project documentation](https://socketry.github.io/protocol-http2/) for more details.

  - [Getting Started](https://socketry.github.io/protocol-http2/guides/getting-started/index) - This guide explains how to use the `protocol-http2` gem to implement a basic HTTP/2 client.

## Releases

Please see the [project releases](https://socketry.github.io/protocol-http2/releases/index) for all releases.

### v0.29.1

  - Sign releases with the Socketry release certificate.

### v0.29.0

  - Decode and discard `HEADERS` received for a locally-initiated stream which was already reset, e.g. a response in flight when the request was cancelled, rather than failing the connection with `ProtocolError`. This keeps the HPACK decoder state synchronized with the remote peer (RFC 9113 §5.1).
  - `CONTINUATION` frames generated when packing a large header block now carry the stream ID of the frame they continue.

### v0.28.0

  - Treat `RST_STREAM(NO_ERROR)` as an orderly stream closure rather than constructing a `StreamError`.

### v0.27.0

  - On a graceful `GOAWAY` (error code `0`), keep the connection open until the streams the remote peer accepted have completed, instead of closing it immediately and failing those requests with `EOFError`.
  - `Connection#create_stream` refuses to open a locally-initiated stream once a `GOAWAY` has been received, as required by RFC 9113 §6.8.

### v0.26.2

  - Ignore the reserved high bit when decoding GOAWAY last stream IDs.

### v0.26.1

  - Improve `StreamError` messages for HTTP/2 stream reset error codes.

### v0.26.0

  - On RST\_STREAM with REFUSED\_STREAM, close the stream with `Protocol::HTTP::RefusedError` instead of `StreamError`.

### v0.25.0

  - On GOAWAY, proactively close unprocessed streams (ID above `last_stream_id`) with `Protocol::HTTP::RequestRefusedError`, enabling safe retry of non-idempotent requests.

### v0.24.0

  - When closing a connection with active streams, if an error is not provided, it will default to `EOFError` so that streams propagate the closure correctly.

### v0.23.0

  - Introduce a limit to the number of CONTINUATION frames that can be read to prevent resource exhaustion. The default limit is 8 continuation frames, which means a total of 9 frames (1 initial + 8 continuation). This limit can be adjusted by passing a different value to the `limit` parameter in the `Continued.read` method. Setting the limit to 0 will only read the initial frame without any continuation frames. In order to change the default, you can redefine the `LIMIT` constant in the `Protocol::HTTP2::Continued` module, OR you can pass a different frame class to the framer.

## See Also

  - [Async::HTTP](https://github.com/socketry/async-http) - A high-level HTTP client and server implementation.

## Contributing

We welcome contributions to this project.

1.  Fork the repository.
2.  Create your feature branch (`git checkout -b my-new-feature`).
3.  Commit your changes (`git commit -am 'Add some feature.'`).
4.  Push to the branch (`git push origin my-new-feature`).
5.  Create a new pull request.

### Running Tests

To run the test suite:

``` bash
$ bundle exec sus
```

### Making Releases

To prepare a release branch and open a pull request from an up-to-date `main`:

``` bash
$ bundle exec bake gem:github:release:patch # or minor or major
```

See [bake-gem-github](https://github.com/socketry/bake-gem-github) for setup, remote releases, and recovery.

### Developer Certificate of Origin

In order to protect users of this project, we require all contributors to comply with the [Developer Certificate of Origin](https://developercertificate.org/). This ensures that all contributions are properly licensed and attributed.

### Community Guidelines

This project is best served by a collaborative and respectful environment. Treat each other professionally, respect differing viewpoints, and engage constructively. Harassment, discrimination, or harmful behavior is not tolerated. Communicate clearly, listen actively, and support one another. If any issues arise, please inform the project maintainers.
