#!/usr/bin/env ruby
# frozen_string_literal: true

# Demonstrate finding retention roots for a simulated memory leak

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
require "memory/profiler/graph"

puts "=" * 70
puts "Memory Leak Root Analysis Demo"
puts "=" * 70
puts

# Simulate a real-world memory leak scenario
module MyLibrary
	CACHE = {}
	REGISTRY = []
end

$global_buffer = []

class DataProcessor
	def initialize
		@connection_pool = []
		@pending_requests = []
	end
	
	attr_reader :connection_pool, :pending_requests
end

# Start tracking
capture = Memory::Profiler::Capture.new
capture.track(Hash)
capture.track(Array)
capture.start

# Simulate the leak: Create objects referenced by various roots
puts "Simulating memory leak..."

# 1. Leak through module constant (70% of hashes)
70.times do |i|
	key = "user_#{i}"
	MyLibrary::CACHE[key] = { data: "cached_value_#{i}", timestamp: Time.now }
end

# 2. Leak through global variable (20% of hashes)
20.times do |i|
	$global_buffer << { type: "buffer", content: "data_#{i}" }
end

# 3. Leak through instance variable (10% of hashes)
$processor = DataProcessor.new
10.times do |i|
	$processor.connection_pool << { connection: "conn_#{i}", status: :active }
end

# 4. Arrays in registry
50.times do |i|
	MyLibrary::REGISTRY << [i, i*2, i*3]
end

# 5. Some arrays in global
30.times do |i|
	$global_buffer << ["item_#{i}", "value_#{i}"]
end

capture.stop

puts "Allocation complete."
puts

# Show what we tracked
puts "Tracked Allocations:"
puts "  Hash: #{capture[Hash].retained_count} objects"
puts "  Array: #{capture[Array].retained_count} objects"
puts

# Now use the Graph API to find who's responsible
puts "=" * 70
puts "Finding Retention Roots (this may take a moment)..."
puts "=" * 70
puts

graph = Memory::Profiler::Graph.new
graph.add(capture[Hash])
graph.add(capture[Array])

begin
	roots = graph.roots(limit: 10)
	
	if roots.empty?
		puts "No retaining roots found."
	else
		puts "Top Retaining Roots:"
		puts
		
		roots.each_with_index do |root, i|
			puts "#{i+1}. #{root[:name]}"
			puts "   Retains: #{root[:count]} objects (#{root[:percentage]}%)"
			puts "   Example path: #{root[:path]}"
			puts
		end
	end
rescue => e
	puts "Error during root analysis: #{e.message}"
	puts e.backtrace.first(5)
end

# Also show per-class analysis
puts "=" * 70
puts "Hash-specific Roots:"
puts "=" * 70
puts

begin
	hash_roots = graph.roots_of(Hash, limit: 5)
	
	if hash_roots.empty?
		puts "No roots found for Hash."
	else
		hash_roots.each_with_index do |root, i|
			puts "#{i+1}. #{root[:name]}: #{root[:count]} objects (#{root[:percentage]}%)"
			puts "   Path: #{root[:path]}"
		end
	end
rescue => e
	puts "Error: #{e.message}"
end

puts
puts "=" * 70
puts "Analysis complete!"
puts "=" * 70

