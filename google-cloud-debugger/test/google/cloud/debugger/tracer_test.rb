# Copyright 2017 Google Inc. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


require "helper"

describe Google::Cloud::Debugger::Tracer, :mock_debugger do
  describe "#update_breakpoints_cache" do
    it "update @breakpoints_cache with a new hash everytime" do
      breakpoint_manager.stub :active_breakpoints, [] do
        original_hash = agent.tracer.breakpoints_cache
        new_hash = agent.tracer.update_breakpoints_cache

        original_hash.object_id.wont_equal new_hash.object_id
      end
    end

    it "sets @breakpoints_cache with a nested hash" do
      breakpoint1 = OpenStruct.new line: 123, path: "path/to/file1.rb"
      breakpoint2 = OpenStruct.new line: 345, path: "path/to/file1.rb"
      breakpoint3 = OpenStruct.new line: 987, path: "path/to/file2.rb"
      breakpoint4 = OpenStruct.new line: 987, path: "path/to/file2.rb"

      stubbed_full_path = ->(path) { path }

      breakpoint_manager.stub :active_breakpoints, [breakpoint1, breakpoint2, breakpoint3, breakpoint4] do
        tracer.stub :full_breakpoint_path, stubbed_full_path do
          breakpoints_hash = agent.tracer.update_breakpoints_cache

          breakpoints_hash["path/to/file1.rb"][123].must_equal [breakpoint1]
          breakpoints_hash["path/to/file1.rb"][345].must_equal [breakpoint2]
          breakpoints_hash["path/to/file2.rb"][987].must_equal [breakpoint3, breakpoint4]
        end
      end
    end
  end

  describe "#breakpoint_hit" do
    let(:breakpoint) {
      Google::Cloud::Debugger::Breakpoint.new nil, "path/to/file.rb", 123
    }

    it "doesn't call BreakpointManager#breakpoint_hit if breakpoint is already completed" do
      stubbed_breakpoint_hit = ->(_) { fail "Shouldn't be called" }

      breakpoint_manager.stub :breakpoint_hit, stubbed_breakpoint_hit do
        breakpoint.stub :complete?, true do
          tracer.breakpoint_hit breakpoint, nil
        end
      end
    end

    it "calls #disable_traces if all breakpoints are finished evaluation" do
      breakpoint_manager.instance_variable_set :@active_breakpoints, [breakpoint]

      tracer.update_breakpoints_cache
      tracer.breakpoints_cache.wont_be_empty

      stubbed_evaluate = ->(_) { breakpoint.complete }
      mocked_disable_traces = Minitest::Mock.new
      mocked_disable_traces.expect :call, nil

      breakpoint.stub :evaluate, stubbed_evaluate do
        transmitter.stub :submit, nil do
          tracer.stub :disable_traces, mocked_disable_traces do
            tracer.breakpoint_hit breakpoint, nil
          end
        end
      end

      mocked_disable_traces.verify
    end
  end

  describe "#start" do
    let(:breakpoint) {
      Google::Cloud::Debugger::Breakpoint.new nil, "path/to/file.rb", 123
    }
    
    it "doesn't call #enable_traces if no active breakpoints" do
      stubbed_enable_traces = ->() { fail "Shouldn't be called" }

      tracer.stub :enable_traces, stubbed_enable_traces do
        tracer.start
      end
    end

    it "calls enable_traces if there are active breakpoints" do
      breakpoint_manager.instance_variable_set :@active_breakpoints, [breakpoint]

      mocked_enable_traces = Minitest::Mock.new
      mocked_enable_traces.expect :call, nil

      tracer.stub :enable_traces, mocked_enable_traces do
        tracer.start
      end
    end
  end
end
