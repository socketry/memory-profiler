#!/usr/bin/env ruby
# frozen_string_literal: true

# Demonstrate graph analysis for finding retaining roots

# Define Memory module first (required by C extension)
module Memory
end

# Load the local extension
$LOAD_PATH.unshift File.expand_path("../ext", __dir__)
require "Memory_Profiler"

# Load the rest of the library
$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "memory/profiler/version"
require "memory/profiler/call_tree"
require "memory/profiler/capture"
require "memory/profiler/allocations"
require "memory/profiler/sampler"

puts "Memory::Profiler::Graph Analysis Demo"
puts "=" * 60
puts

# Check if native graph traversal is available
if Memory::Profiler::Graph.native_available?
	puts "✓ Native rb_objspace_reachable_objects_from is available!"
	puts "  (Fast graph traversal enabled)"
else
	puts "✗ Native function not available, using Ruby fallback"
	puts "  (Performance will be slower)"
end

if Memory::Profiler::Graph.root_available?
	puts "✓ Native rb_objspace_reachable_objects_from_root is available!"
	puts "  (TRUE GC root analysis enabled)"
else
	puts "✗ GC root analysis not available"
end
puts

# Create a scenario with retained objects
capture = Memory::Profiler::Capture.new
capture.track(Array)
capture.start

# Create a root container that holds many arrays
root_container = []

# Create nested structure - root contains many child arrays
100.times do |i|
	child_array = [i, i * 2, i * 3]
	root_container << child_array
end

# Create some independent arrays too
independent = []
20.times do |i|
	independent << ["independent_#{i}"]
end

capture.stop

puts "Allocation Statistics:"
allocations = capture[Array]
puts "  Allocated: #{allocations.new_count}"
puts "  Freed: #{allocations.free_count}"
puts "  Retained: #{allocations.retained_count}"
puts

# Test count_reachable
puts "Testing Graph.count_reachable:"
tracked_ids = []
allocations.each do |obj, state|
	tracked_ids << obj.object_id
end

reachable_from_root = Memory::Profiler::Graph.count_reachable(root_container, tracked_ids)
puts "  Objects reachable from root_container: #{reachable_from_root}"
puts

# Test analyze_roots - find TRUE GC roots
if Memory::Profiler::Graph.root_available?
	puts "Analyzing TRUE GC roots (from Ruby VM)..."
	
	begin
		root_categories = Memory::Profiler::Graph.analyze_roots(tracked_ids)
		
		if root_categories.empty?
			puts "  No roots found (unexpected!)"
		else
			puts "  GC Root Categories retaining tracked objects:"
			root_categories.sort_by{|cat, count| -count}.each do |category, count|
				percentage = (count.to_f / tracked_ids.size * 100).round(1)
				puts "    #{category}: #{count} objects (#{percentage}%)"
			end
		end
	rescue => e
		puts "  Error: #{e.message}"
		puts "  #{e.class}"
	end
	puts
end

# Test find_roots (heuristic analysis)
puts "Finding potential retaining roots (heuristic)..."
puts "  (Analyzing sample of tracked objects)"

begin
	roots = Memory::Profiler::Graph.find_roots(allocations, max_samples: 50, max_candidates: 10)
	
	if roots.empty?
		puts "  No significant roots found (may need more objects)"
	else
		puts "  Found #{roots.size} potential roots:"
		roots.take(5).each_with_index do |(obj, count), i|
			puts "    #{i+1}. #{obj.class} (size: #{obj.size rescue 'N/A'}) -> reaches #{count} tracked objects"
		end
	end
rescue => e
	puts "  Error during root analysis: #{e.message}"
end

puts
puts "Analysis complete!"

