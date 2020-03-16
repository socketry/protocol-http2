# Copyright, 2019, by Yuta Iwama.
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

require 'protocol/http2/flow_control'

RSpec.describe Protocol::HTTP2::FlowControl do
	let(:stream_class) do
		Class.new do
			include Protocol::HTTP2::FlowControl

			attr_reader :children, :weight

			def initialize(weight)
				@weight = weight
				@children = []
				@remote_window = Protocol::HTTP2::Window.new
			end

			def add_child(item)
				@children << item
			end

			def id
				object_id
			end
		end
	end

	describe '#consume_window' do
		it 'calls consume_window recursively' do
			stream1 = stream_class.new(1)
			stream2 = stream_class.new(2)
			parent = stream_class.new(1)
			parent.add_child(stream1)
			parent.add_child(stream2)

			expect(stream1).to receive(:consume_window).with((0xFFFF * 1) / 3).once
			expect(stream2).to receive(:consume_window).with((0xFFFF * 2) / 3).once

			parent.consume_window
		end
	end
end
