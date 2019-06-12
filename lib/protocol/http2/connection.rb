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

require_relative 'framer'
require_relative 'flow_control'

require 'protocol/hpack'

module Protocol
	module HTTP2
		class Connection
			include FlowControl
			
			def initialize(framer, local_stream_id)
				@state = :new
				@streams = {}
				
				@framer = framer
				@local_stream_id = local_stream_id
				@remote_stream_id = 0
				
				@local_settings = PendingSettings.new
				@remote_settings = Settings.new
				
				@decoder = HPACK::Context.new
				@encoder = HPACK::Context.new
				
				@local_window = Window.new(@local_settings.initial_window_size)
				@remote_window = Window.new(@remote_settings.initial_window_size)
			end
			
			def id
				0
			end
			
			# The size of a frame payload is limited by the maximum size that a receiver advertises in the SETTINGS_MAX_FRAME_SIZE setting.
			def maximum_frame_size
				@remote_settings.maximum_frame_size
			end
			
			def maximum_concurrent_streams
				[@local_settings.maximum_concurrent_streams, @remote_settings.maximum_concurrent_streams].min
			end
			
			attr :framer
			
			# Connection state (:new, :open, :closed).
			attr_accessor :state
			
			# Current settings value for local and peer
			attr_accessor :local_settings
			attr_accessor :remote_settings
			
			# Our window for receiving data. When we receive data, it reduces this window.
			# If the window gets too small, we must send a window update.
			attr :local_window
			
			# Our window for sending data. When we send data, it reduces this window.
			attr :remote_window
			
			def closed?
				@state == :closed
			end
			
			def connection_error!(error, message)
				return if @framer.closed?
				
				send_goaway(error, message)
				
				self.close
			end
			
			def close
				@framer.close
			end
			
			def encode_headers(headers, buffer = String.new.b)
				HPACK::Compressor.new(buffer, @encoder).encode(headers)
				
				return buffer
			end
			
			def decode_headers(data)
				HPACK::Decompressor.new(data, @decoder).decode
			end
			
			# Streams are identified with an unsigned 31-bit integer.  Streams initiated by a client MUST use odd-numbered stream identifiers; those initiated by the server MUST use even-numbered stream identifiers.  A stream identifier of zero (0x0) is used for connection control messages; the stream identifier of zero cannot be used to establish a new stream.
			def next_stream_id
				id = @local_stream_id
				
				@local_stream_id += 2
				
				return id
			end
			
			attr :streams
			
			def read_frame
				frame = @framer.read_frame(@local_settings.maximum_frame_size)
				# puts "#{self.class} #{@state} read_frame: class=#{frame.class} flags=#{frame.flags} length=#{frame.length}"
				# puts "Windows: local_window=#{@local_window.inspect}; remote_window=#{@remote_window.inspect}"
				
				yield frame if block_given?
				
				frame.apply(self)
				
				return frame
			rescue GoawayError
				# This is not a connection error. We are done.
				self.close
				
				raise
			rescue ProtocolError => error
				pp error
				connection_error!(error.code || PROTOCOL_ERROR, error.message)
				
				raise
			rescue HPACK::CompressionError => error
				connection_error!(COMPRESSION_ERROR, error.message)
				
				raise
			rescue
				connection_error!(PROTOCOL_ERROR, $!.message)
				
				raise
			end
			
			def send_settings(changes)
				@local_settings.append(changes)
				
				frame = SettingsFrame.new
				frame.pack(changes)
				
				write_frame(frame)
			end
			
			def send_goaway(error_code = 0, message = "")
				frame = GoawayFrame.new
				frame.pack @remote_stream_id, error_code, message
				
				write_frame(frame)
				
				@state = :closed
			end
			
			def receive_goaway(frame)
				@state = :closed
				
				last_stream_id, error_code, message = frame.unpack
				
				if error_code != 0
					raise GoawayError.new(message, error_code)
				end
			end
			
			def write_frame(frame)
				# puts "#{self.class} #{@state} write_frame: class=#{frame.class} flags=#{frame.flags} length=#{frame.length}"
				@framer.write_frame(frame)
			end
			
			def send_ping(data)
				if @state != :closed
					frame = PingFrame.new
					frame.pack data
					
					write_frame(frame)
				else
					raise ProtocolError, "Cannot send ping in state #{@state}"
				end
			end
			
			def update_local_settings(changes)
				capacity = @local_settings.initial_window_size
				
				@streams.each_value do |stream|
					stream.local_window.capacity = capacity
				end
			end
			
			def update_remote_settings(changes)
				capacity = @remote_settings.initial_window_size
				
				@streams.each_value do |stream|
					stream.remote_window.capacity = capacity
				end
			end
			
			# In addition to changing the flow-control window for streams that are not yet active, a SETTINGS frame can alter the initial flow-control window size for streams with active flow-control windows (that is, streams in the "open" or "half-closed (remote)" state).  When the value of SETTINGS_INITIAL_WINDOW_SIZE changes, a receiver MUST adjust the size of all stream flow-control windows that it maintains by the difference between the new value and the old value.
			#
			# @return [Boolean] whether the frame was an acknowledgement
			def process_settings(frame)
				if frame.acknowledgement?
					# The remote end has confirmed the settings have been received:
					changes = @local_settings.acknowledge
					
					update_local_settings(changes)
					
					return true
				else
					# The remote end is updating the settings, we reply with acknowledgement:
					reply = frame.acknowledge
					
					write_frame(reply)
					
					changes = frame.unpack
					@remote_settings.update(changes)
					
					update_remote_settings(changes)
					
					return false
				end
			end
			
			def open!
				@state = :open
				
				return self
			end
			
			def receive_settings(frame)
				if @state == :new
					# We transition to :open when we receive acknowledgement of first settings frame:
					open! if process_settings(frame)
				elsif @state != :closed
					process_settings(frame)
				else
					raise ProtocolError, "Cannot receive settings in state #{@state}"
				end
			end
			
			def receive_ping(frame)
				if @state != :closed
					if frame.stream_id != 0
						raise ProtocolError, "Ping received for non-zero stream!"
					end
					
					unless frame.acknowledgement?
						reply = frame.acknowledge
						
						write_frame(reply)
					end
				else
					raise ProtocolError, "Cannot receive ping in state #{@state}"
				end
			end
			
			def receive_data(frame)
				consume_local_window(frame)
				
				if stream = @streams[frame.stream_id]
					stream.receive_data(frame)
				else
					raise ProtocolError, "Cannot receive data for idle stream #{frame.stream_id}"
				end
			end
			
			def valid_remote_stream_id?
				false
			end
			
			# Accept a stream from the other side of the connnection.
			def accept_stream(stream_id)
				unless valid_remote_stream_id?(stream_id)
					raise ProtocolError, "Invalid remote stream id: #{stream_id}"
				end
				
				if stream_id <= @remote_stream_id
					raise ProtocolError, "Invalid stream id: #{stream_id} <= #{@remote_stream_id}!"
				end
				
				@remote_stream_id = stream_id
				create_stream(stream_id)
			end
			
			# Create a stream on this side of the connection.
			def create_stream(stream_id = next_stream_id)
				@streams[stream_id] = Stream.new(self, stream_id)
			end
			
			def receive_headers(frame)
				if frame.stream_id == 0
					raise ProtocolError, "Cannot receive headers for stream 0!"
				end
				
				if stream = @streams[frame.stream_id]
					stream.receive_headers(frame)
				else
					if @streams.count < self.maximum_concurrent_streams
						stream = accept_stream(frame.stream_id)
						stream.receive_headers(frame)
					else
						raise ProtocolError, "Exceeded maximum concurrent streams"
					end
				end
			end
			
			def receive_priority(frame)
				if stream = @streams[frame.stream_id]
					stream.receive_priority(frame)
				else
					stream = accept_stream(frame.stream_id)
					stream.receive_priority(frame)
				end
			end
			
			def receive_reset_stream(frame)
				if stream = @streams[frame.stream_id]
					stream.receive_reset_stream(frame)
				else
					raise StreamClosed, "Cannot reset stream #{frame.stream_id}"
				end
			end
			
			def receive_window_update(frame)
				if frame.connection?
					super
				elsif stream = @streams[frame.stream_id]
					begin
						stream.receive_window_update(frame)
					rescue ProtocolError => error
						stream.send_reset_stream(error.code)
					end
				else
					# Receiving any frame other than HEADERS or PRIORITY on a stream in this state MUST be treated as a connection error of type PROTOCOL_ERROR.
					raise ProtocolError, "Cannot update window of idle stream #{frame.stream_id}"
				end
			end
			
			def window_updated
				# This is very inefficient, but workable.
				@streams.each_value do |stream|
					stream.window_updated unless stream.closed?
				end
			end
			
			def receive_continuation(frame)
				raise ProtocolError, "Received unexpected continuation: #{frame.class}"
			end
			
			def receive_frame(frame)
				# ignore.
			end
		end
	end
end
