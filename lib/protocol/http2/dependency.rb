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

require_relative 'flow_control'

module Protocol
	module HTTP2
		DEFAULT_WEIGHT = 16
		
		class Dependency
			def initialize(connection, id, dependent_id = 0, weight = DEFAULT_WEIGHT, children = nil)
				@connection = connection
				@id = id
				
				# Stream priority:
				@dependent_id = dependent_id
				@weight = weight
				
				# A cache of dependencies that have child.dependent_id = self.id
				@children = children
			end
			
			def irrelevant?
				(@weight == DEFAULT_WEIGHT) && (@children.nil? || @children.empty?)
			end
			
			def delete!
				@connection.dependencies.delete(@id)
				self.parent&.remove_child(self)
			end
			
			# Cache of dependent children.
			attr_accessor :children
			
			# The connection this stream belongs to.
			attr :connection
			
			# Stream ID (odd for client initiated streams, even otherwise).
			attr :id
			
			# The stream id that this stream depends on, according to the priority.
			attr_accessor :dependent_id
			
			# The weight of the stream relative to other siblings.
			attr_accessor :weight
			
			def stream
				@connection.streams[@id]
			end
			
			def streams
				if @children
					# TODO this O(N) operation affects performance.
					# It would be better to maintain a sorted list of children streams.
					@children.map{|id, dependency| dependency.stream}.compact
				end
			end
			
			def add_child(dependency)
				@children ||= {}
				@children[dependency.id] = dependency
			end
			
			def remove_child(dependency)
				@children&.delete(dependency.id)
			end
			
			def exclusive_child(parent)
				parent.children = @children
				
				@children.each_value do |child|
					child.dependent_id = parent.id
				end
				
				@children = {parent.id => parent}
				
				parent.dependent_id = @id
			end
			
			def parent(id = @dependent_id)
				@connection.dependency_for(id)
			end
			
			def parent= dependency
				self.parent&.remove_child(self)
				
				@dependent_id = dependency.id
				
				dependency.add_child(self)
			end
			
			def process_priority priority
				dependent_id = priority.stream_dependency
				
				if dependent_id == @id
					raise ProtocolError, "Stream priority for stream id #{@id} cannot depend on itself!"
				end
				
				@weight = priority.weight
				
				if priority.exclusive
					self.parent&.remove_child(self)
					
					self.parent(dependent_id).exclusive_child(self)
				elsif dependent_id != @dependent_id
					self.parent&.remove_child(self)
					
					@dependent_id = dependent_id
					
					self.parent.add_child(self)
				end
			end
			
			# Change the priority of the stream both locally and remotely.
			def priority= priority
				send_priority(priority)
				process_priority(priority)
			end
			
			# The current local priority of the stream.
			def priority(exclusive = false)
				Priority.new(exclusive, @dependent_id, @weight)
			end
			
			def send_priority(priority)
				@connection.send_priority(@id, priority)
			end
			
			def receive_priority(frame)
				self.process_priority(frame.unpack)
			end
		end
	end
end
