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
	
	context "idle stream" do
		let(:stream) {client.create_stream}
		
		it "can send headers" do
			stream.send_headers(nil, [["foo", "bar"]])
			
			server_stream = server.create_stream(stream.id)
			
			expect(server_stream).to receive(:receive_headers)
			
			server.read_frame
		end
		
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
			end.to raise_error(Protocol::HTTP2::ProtocolError, /Cannot receive data/)
		end
		
		it "cannot receive stream reset" do
			stream.open!
			stream.send_reset_stream
			
			expect do
				server.read_frame
			end.to raise_error(Protocol::HTTP2::ProtocolError, /Cannot reset stream/)
		end
	end
	
	context "open stream" do
		let(:stream) {client.create_stream.open!}
		
		it "can send data" do
			stream.send_data("Hello World!")
			
			server_stream = server.create_stream(stream.id)
			
			expect(server_stream).to receive(:receive_data)
			
			server.read_frame
		end
		
		it "can send reset stream" do
			stream.send_reset_stream
			
			server_stream = server.create_stream(stream.id)
			
			expect(server_stream).to receive(:receive_reset_stream)
			
			server.read_frame
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
	end
end
