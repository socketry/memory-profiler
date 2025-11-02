# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "memory/profiler/call_tree"

Location = Struct.new(:path, :lineno, :label) do
	def to_s
		"#{path}:#{lineno}#{label ? " in '#{label}'" : ""}"
	end
end

describe Memory::Profiler::CallTree do
	let(:tree) {subject.new}
	
	with "#record" do
		it "can record a single allocation" do
			locations = [
				Location.new("a.rb", 1, "foo"),
				Location.new("b.rb", 2, "bar")
			]
			
			tree.record(locations)
			
			expect(tree.total_allocations).to be == 1
		end
		
		it "builds tree structure for common paths" do
			locations1 = [
				Location.new("a.rb", 1, "foo"),
				Location.new("b.rb", 2, "bar")
			]
			
			locations2 = [
				Location.new("a.rb", 1, "foo"),
				Location.new("c.rb", 3, "baz")
			]
			
			tree.record(locations1)
			tree.record(locations2)
			
			expect(tree.total_allocations).to be == 2
			
			paths = tree.top_paths(10)
			expect(paths.length).to be == 2
		end
		
		it "deduplicates common call prefixes" do
			a_rb = Location.new("a.rb", 1, "foo")
			b_rb = Location.new("b.rb", 2, "bar")
			c_rb = Location.new("c.rb", 3, "baz")
			
			# Same root, different branches
			10.times do
				tree.record([
					a_rb, b_rb
				])
			end
			
			5.times do
				tree.record([
					a_rb, c_rb
				])
			end
			
			expect(tree.total_allocations).to be == 15
			
			# Should have deduped the common root "a.rb:1"
			hotspots = tree.hotspots(10)
			total, retained = hotspots[a_rb.to_s]
			expect(total).to be == 15  # Both paths share this
			expect(retained).to be == 15  # All retained (no frees)
		end
	end
	
	with "#top_paths" do
		it "returns paths sorted by count" do
			5.times do
				tree.record([Location.new("a.rb", 1, "foo")])
			end
			
			10.times do
				tree.record([Location.new("b.rb", 2, "bar")])
			end
			
			paths = tree.top_paths(10)
			
			# top_paths now returns [locations, total_count, retained_count]
			expect(paths.first[1]).to be == 10  # Top path has 10 total allocations
			expect(paths.first[2]).to be == 10  # Top path has 10 retained
			expect(paths.last[1]).to be == 5    # Second path has 5 total
			expect(paths.last[2]).to be == 5    # Second path has 5 retained
		end
	end
	
	with "#hotspots" do
		it "counts individual frames correctly" do
			a_rb = Location.new("a.rb", 1, "foo")
			b_rb = Location.new("b.rb", 2, "bar")
			
			3.times do
				tree.record([a_rb])
			end
			
			2.times do
				tree.record([b_rb])
			end
			
			hotspots = tree.hotspots(10)
			total_a, retained_a = hotspots[a_rb.to_s]
			total_b, retained_b = hotspots[b_rb.to_s]
			
			expect(total_a).to be == 3
			expect(retained_a).to be == 3
			expect(total_b).to be == 2
			expect(retained_b).to be == 2
		end
	end
	
	with "#clear!" do
		it "clears all data" do
			tree.record([Location.new("a.rb", 1, "foo")])
			expect(tree.total_allocations).to be > 0
			
			tree.clear!
			expect(tree.total_allocations).to be == 0
		end
	end
	
	with "dual counters" do
		it "tracks both total and retained allocations" do
			location = Location.new("a.rb", 1, "foo")
			
			# Record 5 allocations
			nodes = 5.times.map do
				tree.record([location])
			end
			
			expect(tree.total_allocations).to be == 5
			expect(tree.retained_allocations).to be == 5
			
			# Simulate 2 objects being freed
			2.times do |i|
				nodes[i].decrement_path!
			end
			
			# Total should stay the same, retained should decrease
			expect(tree.total_allocations).to be == 5
			expect(tree.retained_allocations).to be == 3
		end
		
		it "decrements through entire path" do
			location1 = Location.new("a.rb", 1, "foo")
			location2 = Location.new("b.rb", 2, "bar")
			
			# Create nested path
			node = tree.record([location1, location2])
			
			expect(tree.total_allocations).to be == 1
			expect(tree.retained_allocations).to be == 1
			
			# Decrement - should affect entire path
			node.decrement_path!
			
			expect(tree.total_allocations).to be == 1
			expect(tree.retained_allocations).to be == 0
			
			# Verify hotspots show the decrement
			hotspots = tree.hotspots(10)
			location1_total, location1_retained = hotspots[location1.to_s]
			location2_total, location2_retained = hotspots[location2.to_s]
			
			expect(location1_total).to be == 1
			expect(location1_retained).to be == 0
			expect(location2_total).to be == 1
			expect(location2_retained).to be == 0
		end
	end
end


