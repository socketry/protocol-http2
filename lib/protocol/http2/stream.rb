# Copyright, 2018, by Samuel G. D. Williams. <http://www.codeotaku.com>
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

require_relative 'connection'
require_relative 'flow_control'

module Protocol
	module HTTP2
		# A single HTTP 2.0 connection can multiplex multiple streams in parallel:
		# multiple requests and responses can be in flight simultaneously and stream
		# data can be interleaved and prioritized.
		#
		# This class encapsulates all of the state, transition, flow-control, and
		# error management as defined by the HTTP 2.0 specification. All you have
		# to do is subscribe to appropriate events (marked with ":" prefix in
		# diagram below) and provide your application logic to handle request
		# and response processing.
		#
		#                          +--------+
		#                  send PP |        | recv PP
		#                 ,--------|  idle  |--------.
		#                /         |        |         \
		#               v          +--------+          v
		#        +----------+          |           +----------+
		#        |          |          | send H /  |          |
		# ,------| reserved |          | recv H    | reserved |------.
		# |      | (local)  |          |           | (remote) |      |
		# |      +----------+          v           +----------+      |
		# |          |             +--------+             |          |
		# |          |     recv ES |        | send ES     |          |
		# |   send H |     ,-------|  open  |-------.     | recv H   |
		# |          |    /        |        |        \    |          |
		# |          v   v         +--------+         v   v          |
		# |      +----------+          |           +----------+      |
		# |      |   half   |          |           |   half   |      |
		# |      |  closed  |          | send R /  |  closed  |      |
		# |      | (remote) |          | recv R    | (local)  |      |
		# |      +----------+          |           +----------+      |
		# |           |                |                 |           |
		# |           | send ES /      |       recv ES / |           |
		# |           | send R /       v        send R / |           |
		# |           | recv R     +--------+   recv R   |           |
		# | send R /  `----------->|        |<-----------'  send R / |
		# | recv R                 | closed |               recv R   |
		# `----------------------->|        |<----------------------'
		#                          +--------+
		# 
		#    send:   endpoint sends this frame
		#    recv:   endpoint receives this frame
		# 
		#    H:  HEADERS frame (with implied CONTINUATIONs)
		#    PP: PUSH_PROMISE frame (with implied CONTINUATIONs)
		#    ES: END_STREAM flag
		#    R:  RST_STREAM frame
		#
		# State transition methods use a trailing "!".
		class Stream
			include FlowControl
			
			def self.create(connection, id = connection.next_stream_id)
				local_window = Window.new(connection.local_settings.initial_window_size)
				remote_window = Window.new(connection.remote_settings.initial_window_size)
				
				stream = self.new(connection, id, local_window, remote_window)
				
				# Create new stream:
				connection.streams[id] = stream
				stream.parent.add_child(stream)
				
				return stream
			end
			
			def self.replace(stream)
				connection = stream.connection
				stream.parent.remove_child(stream)
				
				stream = self.new(
					connection, stream.id, stream.local_window, stream.remote_window,
					stream.state, stream.dependent_id, stream.weight, stream.children
				)
				
				# Replace existing stream:
				connection.streams[stream.id] = stream
				stream.parent.add_child(stream)
				
				return stream
			end
			
			def self.accept(connection, id)
				if stream = connection.streams[id]
					self.replace(stream)
				else
					self.create(connection, id)
				end
			end
			
			def initialize(connection, id, local_window, remote_window, state = :idle, dependent_id = 0, weight = 16, children = nil)
				@connection = connection
				@id = id
				
				@local_window = local_window
				@remote_window = remote_window
				
				@state = state
				
				# Stream priority:
				@dependent_id = dependent_id
				@weight = weight
				
				# A cache of streams that have child.dependent_id = self.id
				@children = children
			end
			
			# Cache of dependent children.
			attr_accessor :children
			
			# The connection this stream belongs to.
			attr :connection
			
			# Stream ID (odd for client initiated streams, even otherwise).
			attr :id

			# Stream state, e.g. `idle`, `closed`.
			attr_accessor :state
			
			# The stream id that this stream depends on, according to the priority.
			attr_accessor :dependent_id
			
			# The weight of the stream relative to other siblings.
			attr_accessor :weight
			
			attr :local_window
			attr :remote_window
			
			def add_child(stream)
				@children ||= {}
				@children[stream.id] = stream
			end
			
			def remove_child(stream)
				@children.delete(stream.id)
			end
			
			def exclusive_child(stream)
				stream.children = @children
				
				@children.each do |child|
					child.dependent_id = stream.id
				end
				
				@children = {stream.id => stream}
				
				stream.dependent_id = @id
			end
			
			def parent(id = @dependent_id)
				@connection[id] || @connection.accept_stream(id)
			end
			
			def parent= stream
				self.parent&.remove_child(self)
				
				@dependent_id = stream.id
				
				stream.add_child(self)
			end
			
			def priority= priority
				dependent_id = priority.stream_dependency
				
				if dependent_id == @id
					raise ProtocolError, "Stream priority for stream id #{@id} cannot depend on itself!"
				end
				
				if priority.exclusive
					self.parent&.remove_child(self)
					
					self.parent(dependent_id).exclusive_child(self)
				elsif dependent_id != @dependent_id
					self.parent&.remove_child(self)
					
					@dependent_id = dependent_id
					
					self.parent.add_child(self)
				end
			end
			
			# The stream is being closed because the connection is being closed.
			def close(error = nil)
			end
			
			def maximum_frame_size
				@connection.available_frame_size
			end
			
			def write_frame(frame)
				@connection.write_frame(frame)
			end
			
			def active?
				@state != :closed && @state != :idle
			end
			
			def closed?
				@state == :closed
			end
			
			def send_headers?
				@state == :idle or @state == :reserved_local or @state == :open or @state == :half_closed_remote
			end
			
			private def write_headers(priority, headers, flags = 0)
				data = @connection.encode_headers(headers)
				
				frame = HeadersFrame.new(@id, flags)
				frame.pack(priority, data, maximum_size: @connection.maximum_frame_size)
				
				write_frame(frame)
				
				return frame
			end
			
			# The HEADERS frame is used to open a stream, and additionally carries a header block fragment. HEADERS frames can be sent on a stream in the "idle", "reserved (local)", "open", or "half-closed (remote)" state.
			def send_headers(*args)
				if @state == :idle
					frame = write_headers(*args)
					
					if frame.end_stream?
						@state = :half_closed_local
					else
						@state = :open
					end
				elsif @state == :reserved_local
					frame = write_headers(*args)
					
					@state = :half_closed_remote
				elsif @state == :open
					frame = write_headers(*args)
					
					if frame.end_stream?
						@state = :half_closed_local
					end
				elsif @state == :half_closed_remote
					frame = write_headers(*args)
					
					if frame.end_stream?
						close!
					end
				else
					raise ProtocolError, "Cannot send headers in state: #{@state}"
				end
			end
			
			def consume_remote_window(frame)
				super
				
				@connection.consume_remote_window(frame)
			end
			
			private def write_data(data, flags = 0, **options)
				frame = DataFrame.new(@id, flags)
				frame.pack(data, **options)
				
				# This might fail if the data payload was too big:
				consume_remote_window(frame)
				write_frame(frame)
				
				return frame
			end
			
			def send_data(*args)
				if @state == :open
					frame = write_data(*args)
					
					if frame.end_stream?
						@state = :half_closed_local
					end
				elsif @state == :half_closed_remote
					frame = write_data(*args)
					
					if frame.end_stream?
						close!
					end
				else
					raise ProtocolError, "Cannot send data in state: #{@state}"
				end
			end
			
			# Transition the stream into the closed state.
			# @param error_code [Integer] the error code if the stream was closed due to a stream reset.
			def close!(error_code = nil)
				@state = :closed
				
				if error_code
					error = StreamError.new("Stream closed!", error_code)
				end
				
				self.close(error)
			end
			
			def send_reset_stream(error_code = 0)
				if @state != :idle and @state != :closed
					frame = ResetStreamFrame.new(@id)
					frame.pack(error_code)
					
					write_frame(frame)
					
					close!
				else
					raise ProtocolError, "Cannot reset stream in state: #{@state}"
				end
			end
			
			private def process_headers(frame)
				# Receiving request headers:
				priority, data = frame.unpack
				
				if priority
					self.priority = priority
				end
				
				@connection.decode_headers(data)
			end
			
			def receive_headers(frame)
				if @state == :idle
					if frame.end_stream?
						@state = :half_closed_remote
					else
						@state = :open
					end
					
					return process_headers(frame)
				elsif @state == :reserved_remote
					@state = :half_closed_local
					
					return process_headers(frame)
				elsif @state == :open
					if frame.end_stream?
						@state = :half_closed_remote
					end
					
					return process_headers(frame)
				elsif @state == :half_closed_local
					if frame.end_stream?
						close!
					end
					
					return process_headers(frame)
				else
					raise ProtocolError, "Cannot receive headers in state: #{@state}"
				end
			end
			
			# @return [String] the data that was received.
			def process_data(frame)
				frame.unpack
			end
			
			# DATA frames are subject to flow control and can only be sent when a stream is in the "open" or "half-closed (remote)" state.  The entire DATA frame payload is included in flow control, including the Pad Length and Padding fields if present.  If a DATA frame is received whose stream is not in "open" or "half-closed (local)" state, the recipient MUST respond with a stream error of type STREAM_CLOSED.
			def receive_data(frame)
				if @state == :open
					consume_local_window(frame)
					
					if frame.end_stream?
						@state = :half_closed_remote
					end
					
					process_data(frame)
				elsif @state == :half_closed_local
					consume_local_window(frame)
					
					process_data(frame)
					
					if frame.end_stream?
						close!
					end
				else
					raise ProtocolError, "Cannot receive data in state: #{@state}"
				end
			end
			
			def receive_priority(frame)
				self.priority = frame.unpack
			end
			
			def receive_reset_stream(frame)
				if @state != :idle and @state != :closed
					error_code = frame.unpack
					
					close!(error_code)
					
					return error_code
				else
					raise ProtocolError, "Cannot reset stream in state: #{@state}"
				end
			end
			
			# A normal request is client request -> server response -> client.
			# A push promise is server request -> client -> server response -> client.
			# The server generates the same set of headers as if the client was sending a request, and sends these to the client. The client can reject the request by resetting the (new) stream. Otherwise, the server will start sending a response as if the client had send the request.
			private def write_push_promise(stream_id, headers, flags = 0, **options)
				data = @connection.encode_headers(headers)
				
				frame = PushPromiseFrame.new(@id, flags)
				frame.pack(stream_id, data, maximum_size: @connection.maximum_frame_size)
				
				write_frame(frame)
				
				return frame
			end
			
			def reserved_local!
				if @state == :idle
					@state = :reserved_local
				else
					raise ProtocolError, "Cannot reserve stream in state: #{@state}"
				end
			end
			
			def reserved_remote!
				if @state == :idle
					@state = :reserved_remote
				else
					raise ProtocolError, "Cannot reserve stream in state: #{@state}"
				end
			end
			
			# Override this function to implement your own push promise logic.
			def create_push_promise_stream(headers)
				@connection.create_push_promise_stream
			end
			
			# Server push is semantically equivalent to a server responding to a request; however, in this case, that request is also sent by the server, as a PUSH_PROMISE frame.
			# @param headers [Hash] contains a complete set of request header fields that the server attributes to the request.
			def send_push_promise(headers)
				if @state == :open or @state == :half_closed_remote
					promised_stream = self.create_push_promise_stream(headers)
					promised_stream.reserved_local!
					
					write_push_promise(promised_stream.id, headers)
					
					return promised_stream
				else
					raise ProtocolError, "Cannot send push promise in state: #{@state}"
				end
			end
			
			# Override this function to implement your own push promise logic.
			def accept_push_promise_stream(stream_id, headers)
				@connection.accept_push_promise_stream(stream_id)
			end
			
			def receive_push_promise(frame)
				promised_stream_id, data = frame.unpack
				headers = @connection.decode_headers(data)
				
				stream = self.accept_push_promise_stream(promised_stream_id, headers)
				stream.parent = self
				stream.reserved_remote!
				
				return stream, headers
			end
			
			def inspect
				"\#<#{self.class} id=#{@id} state=#{@state}>"
			end
		end
	end
end
