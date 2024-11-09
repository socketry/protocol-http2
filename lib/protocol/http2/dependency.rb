# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2020-2023, by Samuel Williams.

module Protocol
	module HTTP2
		DEFAULT_WEIGHT = 16
		
		class Dependency
			def self.create(connection, id, priority = nil)
				weight = DEFAULT_WEIGHT
				exclusive = false
				
				if priority
					if parent = connection.dependencies[priority.stream_dependency]
						exclusive = priority.exclusive
					end
					
					weight = priority.weight
				end
				
				if parent.nil?
					parent = connection.dependency
				end
				
				dependency = self.new(connection, id, weight)
				
				connection.dependencies[id] = dependency
				
				if exclusive
					parent.exclusive_child(dependency)
				else
					parent.add_child(dependency)
				end
				
				return dependency
			end
			
			def initialize(connection, id, weight = DEFAULT_WEIGHT)
				@connection = connection
				@id = id
				
				@parent = nil
				@children = nil
				
				@weight = weight
				
				# Cache of any associated stream:
				@stream = nil
				
				# Cache of children for window allocation:
				@total_weight = 0
				@ordered_children = nil
			end
			
			def <=> other
				@weight <=> other.weight
			end
			
			def == other
				@id == other.id
			end
			
			# The connection this stream belongs to.
			attr :connection
			
			# Stream ID (odd for client initiated streams, even otherwise).
			attr :id
			
			# The parent dependency.
			attr_accessor :parent
			
			# The dependent children.
			attr_accessor :children
			
			# The weight of the stream relative to other siblings.
			attr_accessor :weight
			
			def stream
				@stream ||= @connection.streams[@id]
			end
			
			def clear_cache!
				@ordered_children = nil
			end
			
			def delete!
				@connection.dependencies.delete(@id)
				
				@parent.remove_child(self)
				
				@children&.each do |id, child|
					parent.add_child(child)
				end
				
				@connection = nil
				@parent = nil
				@children = nil
			end
			
			def add_child(dependency)
				@children ||= {}
				@children[dependency.id] = dependency
				
				dependency.parent = self
				
				if @ordered_children
					# Binary search for insertion point:
					index = @ordered_children.bsearch_index do |child|
						child.weight >= dependency.weight
					end
					
					if index
						@ordered_children.insert(index, dependency)
					else
						@ordered_children.push(dependency)
					end
					
					@total_weight += dependency.weight
				end
			end
			
			def remove_child(dependency)
				@children&.delete(dependency.id)
				
				if @ordered_children
					# Don't do a linear search here, it can be slow. Instead, the child's parent will be set to `nil`, and we check this in {#consume_window} using `delete_if`.
					# @ordered_children.delete(dependency)
					@total_weight -= dependency.weight
				end
			end
			
			# An exclusive flag allows for the insertion of a new level of dependencies.  The exclusive flag causes the stream to become the sole dependency of its parent stream, causing other dependencies to become dependent on the exclusive stream.
			# @param parent [Dependency] the dependency which will be inserted, taking control of all current children.
			def exclusive_child(parent)
				parent.children = @children
				
				@children&.each_value do |child|
					child.parent = parent
				end
				
				parent.clear_cache!
				
				@children = {parent.id => parent}
				self.clear_cache!
				
				parent.parent = self
			end
			
			def process_priority(priority)
				dependent_id = priority.stream_dependency
				
				if dependent_id == @id
					raise ProtocolError, "Stream priority for stream id #{@id} cannot depend on itself!"
				end
				
				@weight = priority.weight
				
				# We essentially ignore `dependent_id` if the dependency does not exist:
				if parent = @connection.dependencies[dependent_id]
					if priority.exclusive
						@parent.remove_child(self)
						
						parent.exclusive_child(self)
					elsif !@parent.equal?(parent)
						@parent.remove_child(self)
						
						parent.add_child(self)
					end
				end
			end
			
			# Change the priority of the stream both locally and remotely.
			def priority= priority
				send_priority(priority)
				process_priority(priority)
			end
			
			# The current local priority of the stream.
			def priority(exclusive = false)
				Priority.new(exclusive, @parent.id, @weight)
			end
			
			def send_priority(priority)
				@connection.send_priority(@id, priority)
			end
			
			def receive_priority(frame)
				self.process_priority(frame.unpack)
			end
			
			def total_weight
				self.ordered_children
				
				return @total_weight
			end
			
			def ordered_children
				unless @ordered_children
					if @children and !@children.empty?
						@ordered_children = @children.values.sort
						@total_weight = @ordered_children.sum(&:weight)
					end
				end
				
				return @ordered_children
			end
			
			# Traverse active streams in order of priority and allow them to consume the available flow-control window.
			# @param amount [Integer] the amount of data to write. Defaults to the current window capacity.
			def consume_window(size)
				# If there is an associated stream, give it priority:
				if stream = self.stream
					return if stream.window_updated(size)
				end
				
				# Otherwise, allow the dependent children to use up the available window:
				self.ordered_children&.delete_if do |child|
					if child.parent
						# Compute the proportional allocation:
						allocated = (child.weight * size) / @total_weight
						
						child.consume_window(allocated) if allocated > 0
						
						false
					else
						true
					end
				end
			end
			
			def inspect
				"\#<#{self.class} id=#{@id} parent id=#{@parent&.id} weight=#{@weight} #{@children&.size || 0} children>"
			end
			
			def print_hierarchy(output = $stderr, indent: 0)
				output.puts "#{"\t" * indent}#{self.inspect}"
				@children&.each_value do |child|
					child.print_hierarchy(output, indent: indent+1)
				end
			end
		end
	end
end
