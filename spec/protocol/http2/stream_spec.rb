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
		
		expect(server.streams[stream.id].weight).to be == 32
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
		
		expect(a.children).to be == {b.id => b}
		expect(server[a.id].children).to be == {b.id => server[b.id]}
		
		#    a
		#   / \
		#  b   c
		begin
			priority = c.priority
			priority.stream_dependency = a.id
			c.priority = priority
			
			server.read_frame
		end
		
		expect(a.children).to be == {b.id => b, c.id => c}
		expect(server[a.id].children).to be == {b.id => server[b.id], c.id => server[c.id]}
		
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
		
		expect(a.children).to be == {d.id => d}
		expect(d.children).to be == {b.id => b, c.id => c}
		expect(server[a.id].children).to be == {d.id => server[d.id]}
		expect(server[d.id].children).to be == {b.id => server[b.id], c.id => server[c.id]}
	end
	
	context "idle stream" do
		let(:stream) {client.create_stream}
		
		it "cannot send data" do
			expect do
				stream.send_data("Hello World!")
			end.to raise_error(Protocol::HTTP2::ProtocolError, /Cannot send data in state: idle/)
		end
		
		it "cannot send reset stream" do
			expect do
				stream.send_reset_stream
			end.to raise_error(Protocol::HTTP2::ProtocolError, /Cannot send reset stream/)
		end
		
		it "cannot receive data" do
			stream.open!
			stream.send_data("Hello World!")
			
			expect do
				server.read_frame
			end.to raise_error(Protocol::HTTP2::ProtocolError, /Cannot receive data for idle stream/)
		end
		
		it "cannot receive stream reset" do
			stream.open!
			stream.send_reset_stream
			
			expect do
				server.read_frame
			end.to raise_error(Protocol::HTTP2::ProtocolError, /Cannot reset stream/)
		end
	end
	
	context "closed stream" do
		let(:stream) {client.create_stream.close!}
		
		it "cannot send reset stream" do
			expect do
				stream.send_reset_stream
			end.to raise_error(Protocol::HTTP2::ProtocolError, /Cannot send reset stream/)
		end
		
		it "ignores headers" do
			expect(stream).to receive(:ignore_headers)
			
			stream.receive_headers(double)
		end
		
		it "ignores data" do
			expect(stream).to receive(:ignore_data)
			
			stream.receive_data(double)
		end
		
		it "ignores reset stream" do
			expect(stream).to receive(:ignore_reset_stream)
			
			stream.receive_reset_stream(double)
		end
		
		it "doesn't ignore priority" do
			expect(stream).to receive(:process_priority)
			
			stream.receive_priority(double(unpack: nil))
		end
	end
end
