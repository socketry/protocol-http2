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
			priority = b.priority
			priority.stream_dependency = a.id
			b.priority = priority
			
			server.read_frame
		end
		
		expect(a.children).to be == [b]
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
		
		expect(a.children).to be == [b, c]
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
		
		expect(a.children).to be == [d]
		expect(d.children).to be == [b, c]
		expect(server.dependencies[a.id].children).to be == {d.id => server.dependencies[d.id]}
		expect(server.dependencies[d.id].children).to be == {b.id => server.dependencies[b.id], c.id => server.dependencies[c.id]}
	end
end
