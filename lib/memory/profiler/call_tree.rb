# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

module Memory
	module Profiler
		# Efficient tree structure for tracking allocation call paths.
		# Each node represents a frame in the call stack, with counts of how many
		# allocations occurred at this point in the call path.
		class CallTree
			# Represents a node in the call tree.
			#
			# Each node tracks how many allocations occurred at a specific point in a call path.
			# Nodes form a tree structure where each path from root to leaf represents a unique
			# call stack that led to allocations.
			#
			# Nodes now track both total allocations and currently retained (live) allocations.
			class Node
				# Create a new call tree node.
				#
				# @parameter location [Thread::Backtrace::Location] The source location for this frame.
				# @parameter parent [Node] The parent node in the tree.
				def initialize(location = nil, parent = nil)
					@location = location
					@parent = parent
					@total_count = 0      # Total allocations (never decrements)
					@retained_count = 0   # Current live objects (decrements on free)
					@children = nil
				end
				
				# @attribute [Thread::Backtrace::Location] The location of the call.
				attr_reader :location, :parent, :children
				attr_accessor :total_count, :retained_count
				
				# Increment both total and retained counts up the entire path to root.
				def increment_path!
					current = self
					while current
						current.total_count += 1
						current.retained_count += 1
						current = current.parent
					end
				end
				
				# Decrement retained count up the entire path to root.
				def decrement_path!
					current = self
					while current
						current.retained_count -= 1
						current = current.parent
					end
				end
				
				# Check if this node is a leaf (end of a call path).
				#
				# @returns [Boolean] True if this node has no children.
				def leaf?
					@children.nil?
				end
				
				# Find or create a child node for the given location.
				#
				# @parameter location [Thread::Backtrace::Location] The frame location for the child node.
				# @returns [Node] The child node for this location.
				def find_or_create_child(location)
					@children ||= {}
					@children[location.to_s] ||= Node.new(location, self)
				end
				
				# Iterate over child nodes.
				#
				# @yields {|child| ...} If a block is given, yields each child node.
				def each_child(&block)
					@children&.each_value(&block)
				end
				
				# Enumerate all paths from this node to leaves with their counts
				#
				# @parameter prefix [Array] The path prefix (nodes traversed so far).
				# @yields {|path, total_count, retained_count| ...} For each leaf path.
				def each_path(prefix = [], &block)
					current = prefix + [self]
					
					if leaf?
						yield current, @total_count, @retained_count
					end
					
					@children&.each_value do |child|
						child.each_path(current, &block)
					end
				end
			end
			
			# Create a new call tree for tracking allocation paths.
			def initialize
				@root = Node.new
			end
			
			# Record an allocation with the given caller locations.
			#
			# @parameter caller_locations [Array<Thread::Backtrace::Location>] The call stack.
			# @returns [Node] The leaf node representing this allocation path.
			def record(caller_locations)
				return nil if caller_locations.empty?
				
				current = @root
				
				# Build tree path from root to leaf:
				caller_locations.each do |location|
					current = current.find_or_create_child(location)
				end
				
				# Increment counts for entire path (from leaf back to root):
				current.increment_path!
				
				# Return leaf node for object tracking:
				current
			end
			
			# Get the top N call paths by allocation count.
			#
			# @parameter limit [Integer] Maximum number of paths to return.
			# @parameter by [Symbol] Sort by :total or :retained count.
			# @returns [Array<Array>] Array of [locations, total_count, retained_count].
			def top_paths(limit = 10, by: :retained)
				paths = []
				
				@root.each_path do |path, total_count, retained_count|
					# Filter out root node (has nil location) and map to location strings
					locations = path.select(&:location).map {|node| node.location.to_s}
					paths << [locations, total_count, retained_count] unless locations.empty?
				end
				
				# Sort by the requested metric (default: retained, since that's what matters for leaks)
				sort_index = (by == :total) ? 1 : 2
				paths.sort_by {|path_data| -path_data[sort_index]}.first(limit)
			end
			
			# Get hotspot locations (individual frames with highest counts).
			#
			# @parameter limit [Integer] Maximum number of hotspots to return.
			# @parameter by [Symbol] Sort by :total or :retained count.
			# @returns [Hash] Map of location => [total_count, retained_count].
			def hotspots(limit = 20, by: :retained)
				frames = Hash.new {|h, k| h[k] = [0, 0]}
				
				collect_frames(@root, frames)
				
				# Sort by the requested metric
				sort_index = (by == :total) ? 0 : 1
				frames.sort_by {|_, counts| -counts[sort_index]}.first(limit).to_h
			end
			
			# Total number of allocations tracked.
			#
			# @returns [Integer] Total allocation count.
			def total_allocations
				@root.total_count
			end
			
			# Number of currently retained (live) allocations.
			#
			# @returns [Integer] Retained allocation count.
			def retained_allocations
				@root.retained_count
			end
			
			# Clear all tracking data
			def clear!
				@root = Node.new
			end
			
		private
			
			def collect_frames(node, frames)
				# Skip root node (has no location)
				if node.location
					location_str = node.location.to_s
					frames[location_str][0] += node.total_count
					frames[location_str][1] += node.retained_count
				end
				
				node.each_child {|child| collect_frames(child, frames)}
			end
		end
	end
end

