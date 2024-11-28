# Releases

## Unreleased

### Remove Priority Frame and Dependency Tracking

HTTP/2 has deprecated the priority frame and stream dependency tracking. This feature has been effectively removed from the protocol. As a consequence, the internal implementation is greatly simplified. The `Protocol::HTTP2::Stream` class no longer tracks dependencies or priorities, and this includes `Stream#send_headers` which no longer takes `priority` as the first argument.
