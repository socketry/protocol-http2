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

require_relative 'window_update_frame'

module Protocol
	module HTTP2
		module FlowControl
			def available_size
				@remote_window.available
			end
			
			# This could be negative if the window has been overused due to a change in initial window size.
			def available_frame_size(maximum_frame_size = self.maximum_frame_size)
				available_size = self.available_size
				
				# puts "available_size=#{available_size} maximum_frame_size=#{maximum_frame_size}"
				
				if available_size < maximum_frame_size
					return available_size
				else
					return maximum_frame_size
				end
			end
			
			# Keep track of the amount of data sent, and fail if is too much.
			def consume_remote_window(frame)
				amount = frame.length
				
				# Frames with zero length with the END_STREAM flag set (that is, an empty DATA frame) MAY be sent if there is no available space in either flow-control window.
				if amount.zero? and frame.end_stream?
					# It's okay, we can send. No need to consume, it's empty anyway.
				elsif amount >= 0 and amount <= @remote_window.available
					@remote_window.consume(amount)
				else
					raise FlowControlError, "Trying to send #{frame.length} bytes, exceeded window size: #{@remote_window.available} (#{@remote_window})"
				end
			end
			
			def consume_local_window(frame)
				amount = frame.length
				
				@local_window.consume(amount)
				
				if @local_window.limited?
					self.send_window_update(@local_window.used)
				end
			end
			
			# Notify the remote end that we are prepared to receive more data:
			def send_window_update(window_increment)
				frame = WindowUpdateFrame.new(self.id)
				frame.pack window_increment
				
				write_frame(frame)
				
				@local_window.expand(window_increment)
			end
			
			def receive_window_update(frame)
				amount = frame.unpack
				
				# puts "expanding remote_window=#{@remote_window} by #{amount}"
				
				if amount != 0
					@remote_window.expand(amount)
				else
					raise ProtocolError, "Invalid window size increment: #{amount}!"
				end
				
				# puts "expanded remote_window=#{@remote_window} by #{amount}"
			end
			
			# The window has been expanded by the given amount.
			# @param size [Integer] the maximum amount of data to send.
			# @return [Boolean] whether the window update was used or not.
			def window_updated(size = self.available_size)
				return false
			end
			
			# Traverse active streams in order of priority and allow them to consume the available flow-control window.
			# @param amount [Integer] the amount of data to write. Defaults to the current window capacity.
			def consume_window(size = self.available_size)
				# Don't consume more than the available window size:
				size = [self.available_size, size].min
				
				# puts "consume_window(#{size}) local_window=#{@local_window} remote_window=#{@remote_window}"
				
				# Return if there is no window to consume:
				return unless size > 0
				
				# Allow the current flow-controlled instance to use up the window:
				unless self.window_updated(size)
					children = self.children.sort_by(&:weight)
					
					# This must always be at least >= `children.count`, since stream weight can't be 0.
					total = children.sum(&:weight)
					
					children.each do |child|
						# Compute the proportional allocation:
						allocated = (child.weight * size) / total
						child.consume_window(allocated)
					end
				end
			end
		end
	end
end
