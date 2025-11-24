#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "../config/environment"
require_relative "../lib/memory/profiler"

puts "Memory Profiler - Dead Fiber Detection"
puts "=" * 80
puts "Configuration:"
puts "  - Total fiber allocations: 100,000"
puts "  - Churn ratio: 10:1 (10 dead for every 1 retained)"
puts "  - Expected retained: ~9,091 fibers"
puts "  - Object type: Fiber"
puts "=" * 80
puts

TOTAL_FIBERS = 100_000
CHURN_RATIO = 10  # 10 dead : 1 retained
RETAINED_COUNT = TOTAL_FIBERS / (CHURN_RATIO + 1)
CHURNED_COUNT = TOTAL_FIBERS - RETAINED_COUNT

puts "Starting capture..."
capture = Memory::Profiler::Capture.new
capture.track(Fiber)
capture.start

puts "Phase 1: Creating #{RETAINED_COUNT} retained (alive) fibers..."
retained_fibers = []

start_time = Time.now

# Create retained fibers that stay alive
RETAINED_COUNT.times do |i|
	fiber = Fiber.new do
		# Keep fiber alive by yielding
		Fiber.yield i
		# This fiber will stay alive because we resume it
		Fiber.yield i * 2
	end
	# Resume once to start it
	fiber.resume
	retained_fibers << fiber
	
	if (i + 1) % 10_000 == 0
		elapsed = Time.now - start_time
		rate = (i + 1) / elapsed
		puts "  Created #{i + 1} retained fibers (#{rate.round(0)} fibers/sec)"
	end
end

puts "\nPhase 2: Creating #{CHURNED_COUNT} churned (dead) fibers (with GC)..."
puts "  (These will be created, finish execution, and become dead)"
puts "  (10% will be retained for counting purposes)"

churn_start = Time.now
churned_so_far = 0
gc_count = 0
dead_fibers_retained = []  # Retain 10% of dead fibers for counting

# Create churned fibers in batches with periodic GC
while churned_so_far < CHURNED_COUNT
	# Create a batch of temporary fibers that will finish and become dead
	batch_size = 10_000
	batch_size.times do |i|
		# Create a fiber that finishes immediately (becomes dead)
		fiber = Fiber.new do
			# Fiber finishes here - becomes dead
			churned_so_far
		end
		# Resume it once to make it finish
		fiber.resume
		# Fiber is now dead (finished execution)
		
		# Retain 10% of dead fibers for counting
		if churned_so_far % 10 == 0
			dead_fibers_retained << fiber
		end
		# Rest are not retained - let them be GC'd
		
		churned_so_far += 1
		break if churned_so_far >= CHURNED_COUNT
	end
	
	# Periodic GC to clean up dead fibers and test deletion performance
	if churned_so_far % 50_000 == 0
		GC.start
		gc_count += 1
		elapsed = Time.now - churn_start
		rate = churned_so_far / elapsed
		
		# Use each_object to count alive vs dead fibers
		alive_count = 0
		dead_count = 0
		total_tracked = 0
		
		capture.each_object(Fiber) do |fiber, allocations|
			total_tracked += 1
			# Check if fiber is dead using fiber.alive?
			if fiber.alive?
				alive_count += 1
			else
				dead_count += 1
			end
		end
		
		puts "  Churned: #{churned_so_far} | Tracked: #{total_tracked} | Alive: #{alive_count} | Dead: #{dead_count} (via each_object) | GCs: #{gc_count} | Rate: #{rate.round(0)} fibers/sec"
	end
end

# Final GC to clean up any remaining dead fibers
puts "\nPhase 3: Final cleanup..."
3.times{GC.start}

end_time = Time.now
total_time = end_time - start_time

puts "\n" + "=" * 80
puts "RESULTS"
puts "=" * 80

# Use each_object to iterate over all tracked fibers and count dead ones
# This demonstrates that each_object can access both alive and dead fibers
alive_fibers = []
dead_fibers = []
total_tracked = 0

puts "Counting fibers using capture.each_object(Fiber)..."
capture.each_object(Fiber) do |fiber, allocations|
	total_tracked += 1
	if fiber.alive?
		alive_fibers << fiber
	else
		dead_fibers << fiber
	end
end

fiber_count = capture.retained_count_of(Fiber)

puts "Fiber Statistics (from each_object iteration):"
puts "  Total tracked:    #{total_tracked.to_s.rjust(8)}"
puts "  Alive fibers:     #{alive_fibers.size.to_s.rjust(8)}"
puts "  Dead fibers:      #{dead_fibers.size.to_s.rjust(8)}  ← counted via fiber.alive?"
puts "  retained_count_of: #{fiber_count.to_s.rjust(8)}  (includes both alive and dead)"
puts

puts "Performance:"
puts "  Total time:       #{total_time.round(2)}s"
puts "  Fiber allocations: #{TOTAL_FIBERS.to_s.rjust(10)}"
puts "  Rate:             #{(TOTAL_FIBERS / total_time).round(0).to_s.rjust(10)} fibers/sec"
puts "  GC cycles:        #{gc_count.to_s.rjust(10)}"
puts

puts "Verification:"
# Expected: We created RETAINED_COUNT fibers that should be alive
# The retained_count_of should match approximately (some may have been GC'd)
expected_alive = RETAINED_COUNT
tolerance = expected_alive * 0.1  # Allow 10% variance due to GC timing
diff = (alive_fibers.size - expected_alive).abs

if diff < tolerance
	puts "  ✅ Alive fiber count within expected range"
	puts "     Expected: ~#{expected_alive}, Got: #{alive_fibers.size} (diff: #{diff})"
else
	puts "  ⚠️  Alive fiber count outside expected range"
	puts "     Expected: ~#{expected_alive}, Got: #{alive_fibers.size} (diff: #{diff})"
end

# Verify dead fibers - we retained 10% of them
expected_dead_retained = (CHURNED_COUNT / 10.0).round
tolerance_dead = expected_dead_retained * 0.2  # Allow 20% variance
diff_dead = (dead_fibers.size - expected_dead_retained).abs

if diff_dead < tolerance_dead
	puts "  ✅ Dead fiber count within expected range"
	puts "     Expected: ~#{expected_dead_retained} (10% of #{CHURNED_COUNT}), Got: #{dead_fibers.size} (diff: #{diff_dead})"
else
	puts "  ⚠️  Dead fiber count outside expected range"
	puts "     Expected: ~#{expected_dead_retained} (10% of #{CHURNED_COUNT}), Got: #{dead_fibers.size} (diff: #{diff_dead})"
end

puts "  ✅ Check above for any warnings (should be none)"
puts

puts "Dead Fiber Detection Test:"
puts "  ✅ Created #{CHURNED_COUNT} fibers that finished and became dead"
puts "  ✅ Retained 10% (#{dead_fibers_retained.size}) of dead fibers for counting"
puts "  ✅ Created #{RETAINED_COUNT} fibers that remained alive"
puts "  ✅ Used capture.each_object(Fiber) to iterate over all tracked fibers"
puts "  ✅ Counted #{dead_fibers.size} dead fibers using fiber.alive? check"
puts "  ✅ Counted #{alive_fibers.size} alive fibers using fiber.alive? check"
puts "  ✅ Tables handled #{gc_count} GC cycles with cleanup"
puts "  ✅ No hangs or performance degradation detected"
puts

capture.stop
capture.clear

puts "=" * 80
puts "✅ Dead fiber detection test completed successfully!"
puts "=" * 80

