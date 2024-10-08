# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2024, by Samuel Williams.

require_relative "frame"

module Protocol
	module HTTP2
		module Continued
			def initialize(*)
				super
				
				@continuation = nil
			end
			
			def continued?
				!!@continuation
			end
			
			def end_headers?
				flag_set?(END_HEADERS)
			end
			
			def read(stream, maximum_frame_size)
				super
				
				unless end_headers?
					continuation = ContinuationFrame.new
					continuation.read_header(stream)
					
					# We validate the frame type here:
					unless continuation.valid_type?
						raise ProtocolError, "Invalid frame type: #{@type}!"
					end
					
					if continuation.stream_id != @stream_id
						raise ProtocolError, "Invalid stream id: #{continuation.stream_id} for continuation of stream id: #{@stream_id}!"
					end
					
					continuation.read(stream, maximum_frame_size)
					
					@continuation = continuation
				end
			end
			
			def write(stream)
				super
				
				if continuation = self.continuation
					continuation.write(stream)
				end
			end
			
			attr_accessor :continuation
			
			def pack(data, **options)
				maximum_size = options[:maximum_size]
				
				if maximum_size and data.bytesize > maximum_size
					clear_flags(END_HEADERS)
					
					super(data.byteslice(0, maximum_size), **options)
					
					remainder = data.byteslice(maximum_size, data.bytesize-maximum_size)
					
					@continuation = ContinuationFrame.new
					@continuation.pack(remainder, maximum_size: maximum_size)
				else
					set_flags(END_HEADERS)
					
					super data, **options
					
					@continuation = nil
				end
			end
			
			def unpack
				if @continuation.nil?
					super
				else
					super + @continuation.unpack
				end
			end
		end
		
		# The CONTINUATION frame is used to continue a sequence of header block fragments. Any number of CONTINUATION frames can be sent, as long as the preceding frame is on the same stream and is a HEADERS, PUSH_PROMISE, or CONTINUATION frame without the END_HEADERS flag set.
		#
		# +---------------------------------------------------------------+
		# |                   Header Block Fragment (*)                 ...
		# +---------------------------------------------------------------+
		#
		class ContinuationFrame < Frame
			include Continued
			
			TYPE = 0x9
			
			# This is only invoked if the continuation is received out of the normal flow.
			def apply(connection)
				connection.receive_continuation(self)
			end
			
			def inspect
				"\#<#{self.class} stream_id=#{@stream_id} flags=#{@flags} length=#{@length || 0}b>"
			end
		end
	end
end
