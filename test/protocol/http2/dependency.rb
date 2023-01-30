# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2020-2023, by Samuel Williams.

require_relative 'connection_context'

RSpec.describe Protocol::HTTP2::Stream do
	include_context Protocol::HTTP2::Connection
	
	before do
		client.open!
		server.open!
	end
	
	it "can set the priority of a stream" do
		stream = client.create_stream
		
		priority = stream.priority
		expect(priority.weight).to be 16
		
		priority.weight = 32
		
		stream.priority = priority
		
		expect(server.read_frame).to be_a Protocol::HTTP2::PriorityFrame
		
		expect(server.dependencies[stream.id].weight).to be == 32
	end
	
	it "can make an exclusive stream" do
		a, b, c, d = 4.times.collect {client.create_stream}
		
		#    a
		#   /
		#  b
		begin
			a.priority = a.priority
			server.read_frame
			
			priority = b.priority
			priority.stream_dependency = a.id
			b.priority = priority
			
			server.read_frame
		end
		
		expect(a.dependency.children).to be == {b.id => b.dependency}
		
		expect(server.dependencies).to include(a.id)
		expect(server.dependencies[a.id].children).to be == {b.id => server.dependencies[b.id]}
		
		#    a
		#   / \
		#  b   c
		begin
			priority = c.priority
			priority.stream_dependency = a.id
			c.priority = priority
			
			server.read_frame
		end
		
		expect(a.dependency.children).to be == {b.id => b.dependency, c.id => c.dependency}
		expect(server.dependencies[a.id].children).to be == {b.id => server.dependencies[b.id], c.id => server.dependencies[c.id]}
		
		#    a
		#    |
		#    d
		#   / \
		#  b   c
		begin
			priority = d.priority
			priority.stream_dependency = a.id
			priority.exclusive = true
			d.priority = priority
			
			server.read_frame
		end
		
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
		expect(server.dependencies).to_not include(top.id)
		
		bottom = streams.last
		
		priority = bottom.priority
		priority.stream_dependency = top.id
		
		bottom.send_headers(priority, [])
		
		1.times {server.read_frame}
		
		expect(server.dependencies).to include(bottom.id)
		
		dependency = server.dependencies[bottom.id]
		expect(dependency.parent).to be == server.dependency
	end
end
