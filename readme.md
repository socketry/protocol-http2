# Protocol::HTTP2

Provides a low-level implementation of the HTTP/2 protocol.

[![Development Status](https://github.com/socketry/protocol-http2/workflows/Test/badge.svg)](https://github.com/socketry/protocol-http2/actions?workflow=Test)

## Installation

Add this line to your application's Gemfile:

``` ruby
gem 'protocol-http2'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install protocol-http2

## Usage

Here is a basic HTTP/2 client:

``` ruby
require 'async'
require 'async/io/stream'
require 'async/http/endpoint'
require 'protocol/http2/client'

Async do
	endpoint = Async::HTTP::Endpoint.parse("https://www.google.com/search?q=kittens")
	
	peer = endpoint.connect
	
	puts "Connected to #{peer.inspect}"
	
	# IO Buffering...
	stream = Async::IO::Stream.new(peer)
	
	framer = Protocol::HTTP2::Framer.new(stream)
	client = Protocol::HTTP2::Client.new(framer)
	
	puts "Sending connection preface..."
	client.send_connection_preface
	
	puts "Creating stream..."
	stream = client.create_stream
	
	headers = [
		[":scheme", endpoint.scheme],
		[":method", "GET"],
		[":authority", "www.google.com"],
		[":path", endpoint.path],
		["accept", "*/*"],
	]
	
	puts "Sending request on stream id=#{stream.id} state=#{stream.state}..."
	stream.send_headers(headers, Protocol::HTTP2::END_STREAM)
	
	puts "Waiting for response..."
	$count = 0
	
	def stream.process_headers(frame)
		headers = super
		puts "Got response headers: #{headers} (#{frame.end_stream?})"
	end
	
	def stream.receive_data(frame)
		data = super
		
		$count += data.scan(/kittens/).count
		
		puts "Got response data: #{data.bytesize}"
	end
	
	until stream.closed?
		frame = client.read_frame
	end
	
	puts "Got #{$count} kittens!"
	
	puts "Closing client..."
	client.close
end
```

## Contributing

We welcome contributions to this project.

1.  Fork it.
2.  Create your feature branch (`git checkout -b my-new-feature`).
3.  Commit your changes (`git commit -am 'Add some feature'`).
4.  Push to the branch (`git push origin my-new-feature`).
5.  Create new Pull Request.

### Developer Certificate of Origin

In order to protect users of this project, we require all contributors to comply with the [Developer Certificate of Origin](https://developercertificate.org/). This ensures that all contributions are properly licensed and attributed.

### Community Guidelines

This project is best served by a collaborative and respectful environment. Treat each other professionally, respect differing viewpoints, and engage constructively. Harassment, discrimination, or harmful behavior is not tolerated. Communicate clearly, listen actively, and support one another. If any issues arise, please inform the project maintainers.
