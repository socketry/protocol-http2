# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2020-2024, by Samuel Williams.

require "protocol/http2/connection_context"

describe Protocol::HTTP2::Stream do
	include_context Protocol::HTTP2::ConnectionContext
	
	def before
		client.open!
		server.open!
		
		super
	end
	
	it "can set the priority of a stream" do
		stream = client.create_stream
		
		priority = stream.priority
		expect(priority.weight).to be == 16
		
		priority.weight = 32
		
		stream.priority = priority
		
		expect(server.read_frame).to be_a Protocol::HTTP2::PriorityFrame
		
		expect(server.dependencies[stream.id].weight).to be == 32
		expect(stream.weight).to be == 32
	end
	
	it "can't make a stream depend on itself" do
		stream = client.create_stream
		
		priority = stream.priority
		priority.stream_dependency = stream.id
		
		expect do
			stream.priority = priority
		end.to raise_exception(Protocol::HTTP2::ProtocolError)
	end
	
	it "can make an exclusive stream" do
		a, b, c, d = 4.times.collect {client.create_stream}
		
		#    a
		#   /
		#  b
		a.priority = a.priority
		server.read_frame
		
		priority = b.priority
		priority.stream_dependency = a.id
		b.priority = priority
		
		server.read_frame
		
		expect(a.dependency.children).to be == {b.id => b.dependency}
		
		expect(a.dependency.total_weight).to be == 16
		expect(server.dependencies).to have_keys(a.id)
		expect(server.dependencies[a.id].children).to be == {b.id => server.dependencies[b.id]}
		
		#    a
		#   / \
		#  b   c
		priority = c.priority
		priority.stream_dependency = a.id
		c.priority = priority
		
		server.read_frame
		
		expect(a.dependency.children).to be == {b.id => b.dependency, c.id => c.dependency}
		expect(server.dependencies[a.id].children).to be == {b.id => server.dependencies[b.id], c.id => server.dependencies[c.id]}
		
		#    a
		#    |
		#    d
		#   / \
		#  b   c
		priority = d.priority
		priority.stream_dependency = a.id
		priority.exclusive = true
		d.priority = priority
		
		server.read_frame
		
		expect(a.dependency.children).to be == {d.id => d.dependency}
		expect(d.dependency.children).to be == {b.id => b.dependency, c.id => c.dependency}
		expect(server.dependencies[a.id].children).to be == {d.id => server.dependencies[d.id]}
		expect(server.dependencies[d.id].children).to be == {b.id => server.dependencies[b.id], c.id => server.dependencies[c.id]}
	end
	
	it "correctly allocates window" do
		parent = client.create_stream
		children = 2.times.collect {client.create_stream}
		
		children.each do |child|
			priority = child.priority
			priority.stream_dependency = parent.id
			child.priority = priority
		end
		
		2.times {server.read_frame}
		
		# Now we have this prioritization on the server:
		#    a
		#   / \
		#  b   c
		
		expect(server.dependencies[children[0].id]).to receive(:consume_window).with(0xFFFF / 2).once
		expect(server.dependencies[children[1].id]).to receive(:consume_window).with(0xFFFF / 2).once
		
		server.consume_window
	end
	
	it "correctly allocates window" do
		streams = 4.times.collect{client.create_stream}
		
		top = streams.first
		
		top.send_headers(nil, [])
		top.send_reset_stream
		
		2.times {server.read_frame}
		
		# The dependency has been recycled:
		expect(server.dependencies).not.to have_keys(top.id)
		
		bottom = streams.last
		
		priority = bottom.priority
		priority.stream_dependency = top.id
		
		bottom.send_headers(priority, [])
		
		1.times {server.read_frame}
		
		expect(server.dependencies).to have_keys(bottom.id)
		
		dependency = server.dependencies[bottom.id]
		expect(dependency.parent).to be == server.dependency
	end
	
	it "moves child dependencies into grandparent when parent is removed" do
		a, b, c, d = 4.times.collect{client.create_stream}
		a.send_headers(nil, [])
		b.send_headers(nil, [])
		c.send_headers(nil, [])
		d.send_headers(nil, [])
		4.times{server.read_frame}
		
		#    a
		#   / \
		#  b   c
		#      |
		#      d
		a.priority = a.priority
		server.read_frame
		
		priority = b.priority
		priority.stream_dependency = a.id
		b.priority = priority
		server.read_frame
		
		priority = c.priority
		priority.stream_dependency = a.id
		c.priority = priority
		server.read_frame
		
		priority = d.priority
		priority.stream_dependency = c.id
		d.priority = priority
		server.read_frame
		
		expect(server.dependencies[a.id].children).to be == {b.id => server.dependencies[b.id], c.id => server.dependencies[c.id]}
		expect(server.dependencies[c.id].children).to be == {d.id => server.dependencies[d.id]}
		
		#    a
		#   / \
		#  b   d
		c.send_reset_stream
		server.read_frame
		
		expect(server.dependencies[a.id].children).to be == {b.id => server.dependencies[b.id], d.id => server.dependencies[d.id]}
		expect(server.dependencies[c.id]).to be == nil
	end
	
	it "can print a dependency tree" do
		buffer = StringIO.new
		a, b, c = 3.times.collect {client.create_stream}
		
		#    a
		#   / \
		#  b   c
		a.priority = a.priority
		server.read_frame
		
		priority = b.priority
		priority.stream_dependency = a.id
		b.priority = priority
		server.read_frame
		
		priority = c.priority
		priority.stream_dependency = a.id
		c.priority = priority
		server.read_frame
		
		a.dependency.print_hierarchy(buffer)
		
		expect(buffer.string).to be == <<~END
			#<Protocol::HTTP2::Dependency id=1 parent id=0 weight=16 2 children>
				#<Protocol::HTTP2::Dependency id=3 parent id=1 weight=16 0 children>
				#<Protocol::HTTP2::Dependency id=5 parent id=1 weight=16 0 children>
		END
	end
	
	it "can insert several children" do
		a, b, c, d = 4.times.collect {client.create_stream}
		
		b.dependency.weight = 10
		c.dependency.weight = 20
		d.dependency.weight = 30
		
		#     a
		#   / | \
		#  b  c  d
		
		a.priority = a.priority
		server.read_frame
		
		priority = d.priority
		priority.stream_dependency = a.id
		d.priority = priority
		server.read_frame
		
		# Force the ordered_children to be generated, so that we start triggering insertion logic:
		ordered_children = server.dependencies[a.id].ordered_children
		
		priority = b.priority
		priority.stream_dependency = a.id
		b.priority = priority
		server.read_frame
		
		priority = c.priority
		priority.stream_dependency = a.id
		c.priority = priority
		server.read_frame
		
		expect(ordered_children).to be == [b.dependency, c.dependency, d.dependency]
	end
	
	it "handles case where index is nil during insertion" do
		a, b, c, d = 4.times.collect { client.create_stream }
		
		# Assign weights such that no existing child meets the condition:
		b.dependency.weight = 5
		c.dependency.weight = 10
		d.dependency.weight = 15
		
		# Priority tree setup:
		#    a
		#   /|\
		#  b c d
		
		a.priority = a.priority
		server.read_frame
		
		priority = b.priority
		priority.stream_dependency = a.id
		b.priority = priority
		server.read_frame
		
		# Force the ordered_children to be generated, so that we start triggering insertion logic:
		ordered_children = server.dependencies[a.id].ordered_children
		
		priority = c.priority
		priority.stream_dependency = a.id
		c.priority = priority
		server.read_frame
		
		priority = d.priority
		priority.stream_dependency = a.id
		d.priority = priority
		server.read_frame
		
		# Insert a new dependency with a weight that is higher than all current children:
		new_child = client.create_stream
		new_child.dependency.weight = 20  # Greater than the weights of b, c, and d
		
		# Verify that `index` would have been `nil` when finding the insertion point:
		index = ordered_children.bsearch_index { |child| child.weight >= new_child.dependency.weight }
		expect(index).to be_nil
		
		priority = new_child.priority
		priority.stream_dependency = a.id
		new_child.priority = priority
		server.read_frame
		
		# Check that the new child is inserted at the correct place:
		expect(ordered_children).to be(:include?, new_child.dependency)
		expect(ordered_children.last).to be == new_child.dependency
	end
	
	it "can update the weight of a child on removal" do
		a, b, c, d = 4.times.collect { client.create_stream }
		
		# Assign weights such that no existing child meets the condition:
		b.dependency.weight = 5
		c.dependency.weight = 10
		d.dependency.weight = 15
	
		# Priority tree setup:
		#    a
		#   /|\
		#  b c d
		
		a.priority = a.priority
		server.read_frame
		
		priority = b.priority
		priority.stream_dependency = a.id
		b.priority = priority
		server.read_frame
		
		# Force the ordered_children to be generated, so that we start triggering insertion logic:
		ordered_children = server.dependencies[a.id].ordered_children
		
		priority = c.priority
		priority.stream_dependency = a.id
		c.priority = priority
		server.read_frame
		
		priority = d.priority
		priority.stream_dependency = a.id
		d.priority = priority
		server.read_frame
		
		expect(ordered_children).to be == [b.dependency, c.dependency, d.dependency]
		
		# Check the total weight makes sense:
		expect(server.dependencies[a.id].total_weight).to be == 30
		
		# Remove the child with the highest weight:
		server.delete(d.id)
		
		# Check that the weight of the remaining children has been updated:
		expect(server.dependencies[a.id].total_weight).to be == 15
		
		# Force the deletion logic to clean up `ordered_children`:
		server.dependencies[a.id].consume_window(15)
		
		# Check that the child has been removed:
		expect(ordered_children).to be == [b.dependency, c.dependency]
	end
end
