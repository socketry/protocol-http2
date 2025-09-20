# Releases

## Unreleased

  - Introduce a limit to the number of CONTINUATION frames that can be read to prevent resource exhaustion. The default limit is 8 continuation frames, which means a total of 9 frames (1 initial + 8 continuation). This limit can be adjusted by passing a different value to the `limit` parameter in the `Continued.read` method. Setting the limit to 0 will only read the initial frame without any continuation frames. In order to change the default, you can redefine the `LIMIT` constant in the `Protocol::HTTP2::Continued` module, OR you can pass a different frame class to the framer.

## v0.22.0

### Added Priority Update Frame and Stream Priority

HTTP/2 has deprecated the priority frame and stream dependency tracking. This feature has been effectively removed from the protocol. As a consequence, the internal implementation is greatly simplified. The `Protocol::HTTP2::Stream` class no longer tracks dependencies, and this includes `Stream#send_headers` which no longer takes `priority` as the first argument.

Optional per-request priority can be set using the `priority` header instead, and this value can be manipulated using the priority update frame.
