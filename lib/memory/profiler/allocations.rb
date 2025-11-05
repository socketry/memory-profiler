# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require_relative "capture"

module Memory
	module Profiler
		# Ruby extensions to the C-defined Allocations class.
		# The base Allocations class is defined in the C extension.
		class Allocations
			# Convert allocation statistics to JSON-compatible hash.
			#
			# @returns [Hash] Allocation statistics as a hash.
			def as_json(...)
				{
					new_count: self.new_count,
					free_count: self.free_count,
					retained_count: self.retained_count,
				}
			end
			
			# Convert allocation statistics to JSON string.
			#
			# @returns [String] Allocation statistics as JSON.
			def to_json(...)
				as_json.to_json(...)
			end
		end
	end
end

