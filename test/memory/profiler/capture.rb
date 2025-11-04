# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "memory/profiler/capture"

describe Memory::Profiler::Capture do
	let(:capture) {subject.new}
	
	with "#start" do
		it "can start capturing" do
			result = capture.start
			expect(result).to be == true
		end
		
		it "returns false if already started" do
			capture.start
			result = capture.start
			expect(result).to be == false
		end
	end
	
	with "#stop" do
		it "can stop capturing" do
			capture.start
			result = capture.stop
			expect(result).to be == true
		end
		
		it "returns false if not started" do
			result = capture.stop
			expect(result).to be == false
		end
	end
	
	with "#track" do
		it "can track a class" do
			capture.track(Hash)
			expect(capture.tracking?(Hash)).to be == true
		end
		
		it "returns false for untracked classes" do
			expect(capture.tracking?(Array)).to be == false
		end
	end
	
	with "#untrack" do
		it "can stop tracking a class" do
			capture.track(Hash)
			capture.untrack(Hash)
			expect(capture.tracking?(Hash)).to be == false
		end
	end
	
	with "#count_for" do
		it "tracks allocations for a class" do
			capture.start
			
			initial_count = capture.count_for(Hash)
			
			objects = 10.times.map do
				Hash.new
			end
			
			capture.stop
			
			new_count = capture.count_for(Hash)
			expect(new_count).to be >= initial_count + objects.size
		end
		
		it "decrements count when objects are freed" do
			GC.start
			
			capture.start
			
			initial_count = capture.count_for(Hash)
			
			# Allocate and retain
			retained = []
			5.times {retained << Hash.new}
			
			# Allocate and don't retain:
			10.times {Hash.new}
			
			# Force GC
			GC.start
			
			# Check count after GC (should only have retained + initial)
			final_count = capture.count_for(Hash)
			
			# Should be close to initial + 5 (some variation due to GC internals)
			expect(final_count).to be >= initial_count
			expect(final_count).to be <= initial_count + 10
			
			capture.stop
		end
		
		it "returns 0 for untracked classes" do
			expect(capture.count_for(String)).to be == 0
		end
		
		it "handles freeing objects allocated before tracking started" do
			# Disable GC to prevent premature collection:
			GC.disable
			
			# Allocate 100 hashes BEFORE tracking starts:
			hashes = 100.times.map {Hash.new}
			
			# Now start tracking:
			capture.track(Hash)
			capture.start
			
			# Drop references so they can be collected:
			hashes = nil
			
			# Re-enable GC and run it:
			GC.start
			
			# Stop tracking
			capture.stop
			
			# Count should NOT be negative - should be 0 or positive:
			# (Objects allocated before tracking don't get negative counts when freed):
			count = capture.count_for(Hash)
			expect(count).to be >= 0
		ensure
			GC.enable
		end
	end
	
	with "callback" do
		it "calls callback on allocation" do
			captured_classes = []
			
			capture.track(Hash) do |klass, event, state|
				captured_classes << klass if event == :newobj
			end
			
			capture.start
			
			hash = {}
			
			capture.stop
			
			# Should have captured the hash
			expect(captured_classes.length).to be >= 1
			
			# Find our hash in the captured classes
			found = captured_classes.any? {|klass| klass == Hash}
			expect(found).to be == true
		end
		
		it "does not call callback when not started" do
			call_count = 0
			
			capture.track(Hash) do |klass, event, state|
				call_count += 1
			end
			
			# Don't start!
			hash = {}
			
			expect(call_count).to be == 0
		end
		
		it "callback can capture caller_locations" do
			captured_locations = []
			
			capture.track(Hash) do |klass, event, state|
				if event == :newobj
					locations = caller_locations(1, 3)
					captured_locations << locations
				end
			end
			
			capture.start
			
			hash = {}
			
			capture.stop
			
			# Should have captured locations
			expect(captured_locations.length).to be >= 1
			expect(captured_locations.first).to be_a(Array)
		end
	end
	
	with "#clear" do
		it "resets all counts to zero" do
			capture.track(Hash)
			capture.start
			
			10.times {{}}
			
			expect(capture.count_for(Hash)).to be > 0
			
			capture.clear
			
			expect(capture.count_for(Hash)).to be == 0
			
			capture.stop
		end
	end
	
	with "multiple classes" do
		it "can track multiple classes independently" do
			capture.track(Hash)
			capture.track(Array)
			capture.start
			
			5.times {{}}
			3.times {[]}
			
			hash_count = capture.count_for(Hash)
			array_count = capture.count_for(Array)
			
			expect(hash_count).to be >= 5
			expect(array_count).to be >= 3
			
			capture.stop
		end
	end
	
	with "multiple capture instances" do
		it "supports multiple capture instances running simultaneously" do
			capture1 = Memory::Profiler::Capture.new
			capture2 = Memory::Profiler::Capture.new
			
			capture1.track(Hash)
			capture2.track(Array)
			
			capture1.start
			capture2.start
			
			5.times {{}}
			3.times {[]}
			
			capture1.stop
			capture2.stop
			
			# Both captures automatically track ALL allocations
			# The track() call is for setting up callbacks, not filtering
			expect(capture1.count_for(Hash)).to be >= 5
			expect(capture2.count_for(Array)).to be >= 3
			
			# Both instances also see the other classes (automatic tracking)
			expect(capture1.count_for(Array)).to be >= 3
			expect(capture2.count_for(Hash)).to be >= 5
		end
	end
	
	with "callback updates" do
		it "allows updating callback for already tracked class" do
			count1 = 0
			count2 = 0
			
			capture.track(Hash) do |klass, event, state|
				count1 += 1 if event == :newobj
			end
			
			capture.start
			Hash.new
			capture.stop
			
			# Track again with different callback
			capture.track(Hash) do |klass, event, state|
				count2 += 1 if event == :newobj
			end
			
			capture.start
			Hash.new
			capture.stop
			
			expect(count1).to be >= 1  # First callback called
			expect(count2).to be >= 1  # Second callback called
		end
	end
	
	with "start/stop cycles" do
		it "handles multiple start/stop cycles" do
			capture.track(Hash)
			
			# First cycle
			capture.start
			5.times {{}}
			capture.stop
			count1 = capture.count_for(Hash)
			
			# Second cycle
			capture.start
			3.times {{}}
			capture.stop
			count2 = capture.count_for(Hash)
			
			# Counts should accumulate across cycles
			expect(count2).to be >= count1 + 3
		end
		
		it "can restart after stop" do
			capture.track(Hash)
			
			capture.start
			capture.stop
			
			# Should be able to start again
			result = capture.start
			expect(result).to be == true
			
			capture.stop
		end
	end
	
	with "callback edge cases" do
		it "handles callback that raises exception gracefully" do
			capture.track(Hash) do |klass, event, state|
				raise "boom!" if event == :newobj
			end
			
			capture.start
			
			# Should not crash despite exception in callback
			# Exception is caught by RUBY_EVENT_HOOK_FLAG_SAFE
			expect {{} }.not.to raise_exception
			
			capture.stop
		end
		
		it "handles callback allocating same tracked class" do
			nested_count = 0
			
			capture.track(Hash) do |klass, event, state|
				# This allocates another Hash during the callback!
				# The enabled flag prevents infinite recursion
				if event == :newobj && nested_count < 5
					nested_count += 1
					Hash.new  # Allocate Hash in callback
				end
			end
			
			capture.start
			Hash.new # Triggers callback which allocates more
			capture.stop
			
			# Should handle nested allocations without infinite loop
			# enabled flag should prevent recursion
			expect(nested_count).to be > 0
			expect(nested_count).to be <= 5  # Should not recurse infinitely
		end
	end
	
	with "#clear during tracking" do
		it "can clear while tracking is active" do
			capture.track(Hash)
			capture.start
			
			10.times {{}}
			expect(capture.count_for(Hash)).to be > 0
			
			capture.clear
			expect(capture.count_for(Hash)).to be == 0
			
			# Continue tracking after clear
			5.times {{}}
			expect(capture.count_for(Hash)).to be >= 5
			
			capture.stop
		end
	end
	
	with "#untrack and re-track" do
		it "handles untrack and re-track of same class" do
			capture.track(Hash)
			capture.start
			5.times {{}}
			capture.stop
			
			count1 = capture.count_for(Hash)
			expect(count1).to be >= 5
			
			capture.untrack(Hash)
			expect(capture.tracking?(Hash)).to be == false
			
			# Untracking should clear the count
			expect(capture.count_for(Hash)).to be == 0
			
			# Re-track same class
			capture.track(Hash)
			capture.start
			3.times {{}}
			capture.stop
			
			count2 = capture.count_for(Hash)
			# Count should be fresh after re-track
			expect(count2).to be >= 3
			expect(count2).to be < count1  # Should be less than first cycle
		end
	end
	
	with "GC stress test" do
		it "handles GC during tracking with callbacks that store state" do
			# This test attempts to recreate the T_NONE marking bug
			# by storing state in callbacks and forcing GC
			
			# Pre-allocate state objects to avoid allocation during callback
			state_objects = 200.times.map {{index: rand}}
			state_index = 0
			
			capture.track(Hash) do |klass, event, state|
				if event == :newobj
					# Return pre-allocated state
					result = state_objects[state_index]
					state_index = (state_index + 1) % state_objects.size
					result
				elsif event == :freeobj
					# Just return state, don't allocate
					state
				end
			end
			
			capture.start
			
			# Allocate many objects without retaining them
			100.times do
				{}
			end
			
			# Mix old generation objects by running GC multiple times
			3.times {GC.start}
			
			# Should not crash with "try to mark T_NONE object"
			expect(capture.count_for(Hash)).to be >= 0
			
			capture.stop
		end
		
		it "handles tracking anonymous classes that get collected" do
			# Another way to trigger T_NONE: track a class that gets GC'd
			anonymous_class = Class.new
			
			capture.track(anonymous_class)
			capture.start
			
			# Allocate some instances
			3.times {anonymous_class.new}
			
			# Remove reference to the class
			anonymous_class = nil
			
			# Force GC multiple times to mix old generation objects
			# and increase chance the class gets collected
			3.times {GC.start}
			
			# Allocate some other objects to trigger more marking
			1000.times {[]}
			
			# Force more GC to trigger marking of tracked_classes
			3.times {GC.start}
			
			# Should not crash during GC marking
			capture.stop
		end
		
		it "recreates T_NONE marking failure during array join" do
			# Recreate the specific failure from the stack trace:
			# The bug occurs during rb_ary_join which allocates strings,
			# triggering GC, which tries to mark classes that became T_NONE
			
			capture.track(String)
			capture.start
			
			# Allocate many strings
			1000.times {"test"}
			
			# Mix old generation objects
			3.times {GC.start}
			
			# Now do array join which allocates strings and can trigger GC
			# This matches the stack trace: /array.c:2915 rb_ary_join
			large_array = 1000.times.map {"item_#{rand}"}
			result = large_array.join(",")
			
			# Mix old generation again
			3.times {GC.start}
			
			# Should not crash with "try to mark T_NONE object"
			expect(result).not.to be == nil
			
			capture.stop
		end
		
		it "handles GC compaction during tracking" do
			capture.track(String) do |klass, event, state|
				if event == :newobj
					# Store a string as state
					"allocated"
				end
			end
			
			capture.start
			
			# Allocate many strings
			strings = 1000.times.map {"test#{rand}"}
			
			# Should not crash
			expect(capture.count_for(String)).to be >= 1000
			
			capture.stop
			
			# Trigger GC compaction if available
			begin
				GC.verify_compaction_references(expand_heap: true, toward: :empty)
			rescue NotImplementedError
				# Compaction not available on this Ruby version
			end
		end
	end
end
