// Released under the MIT License.
// Copyright, 2025, by Samuel Williams.

// Provides a simple queue for storing elements directly (not as pointers).
// Elements are enqueued during GC and batch-processed afterward.

#pragma once

#include <stdlib.h>
#include <string.h>
#include <assert.h>

static const size_t MEMORY_PROFILER_QUEUE_DEFAULT_COUNT = 128;

struct Memory_Profiler_Queue {
	// The queue storage (elements stored directly, not as pointers):
	void *base;
	
	// The allocated capacity (number of elements):
	size_t capacity;
	
	// The number of used elements:
	size_t count;
	
	// The size of each element in bytes:
	size_t element_size;
};

// Initialize an empty queue
inline static void Memory_Profiler_Queue_initialize(struct Memory_Profiler_Queue *queue, size_t element_size)
{
	queue->base = NULL;
	queue->capacity = 0;
	queue->count = 0;
	queue->element_size = element_size;
}

// Free the queue and its contents
inline static void Memory_Profiler_Queue_free(struct Memory_Profiler_Queue *queue)
{
	if (queue->base) {
		free(queue->base);
		queue->base = NULL;
	}
	
	queue->capacity = 0;
	queue->count = 0;
}

// Resize the queue to have at least the given capacity
inline static int Memory_Profiler_Queue_resize(struct Memory_Profiler_Queue *queue, size_t required_capacity)
{
	if (required_capacity <= queue->capacity) {
		// Already big enough:
		return 0;
	}
	
	size_t new_capacity = queue->capacity;
	
	// If the queue is empty, we need to set the initial size:
	if (new_capacity == 0) {
		new_capacity = MEMORY_PROFILER_QUEUE_DEFAULT_COUNT;
	}
	
	// Double until we reach required capacity
	while (new_capacity < required_capacity) {
		// Check for overflow
		if (new_capacity > (SIZE_MAX / (2 * queue->element_size))) {
			return -1; // Would overflow
		}
		new_capacity *= 2;
	}
	
	// Check final size doesn't overflow
	if (new_capacity > (SIZE_MAX / queue->element_size)) {
		return -1; // Too large
	}
	
	// Reallocate
	void *new_base = realloc(queue->base, new_capacity * queue->element_size);
	if (new_base == NULL) {
		return -1; // Allocation failed
	}
	
	queue->base = new_base;
	queue->capacity = new_capacity;
	
	return 1; // Success
}

// Push a new element onto the end of the queue, returning pointer to the allocated space
// WARNING: The returned pointer is only valid until the next push operation
inline static void* Memory_Profiler_Queue_push(struct Memory_Profiler_Queue *queue)
{
	// Ensure we have capacity
	size_t new_count = queue->count + 1;
	if (new_count > queue->capacity) {
		if (Memory_Profiler_Queue_resize(queue, new_count) == -1) {
			return NULL;
		}
	}
	
	// Calculate pointer to the new element
	void *element = (char*)queue->base + (queue->count * queue->element_size);
	queue->count++;
	
	return element;
}

// Clear the queue (reset count to 0, reusing allocated memory)
inline static void Memory_Profiler_Queue_clear(struct Memory_Profiler_Queue *queue)
{
	queue->count = 0;
}

// Get element at index (for iteration)
// WARNING: Do not hold these pointers across push operations
inline static void* Memory_Profiler_Queue_at(struct Memory_Profiler_Queue *queue, size_t index)
{
	assert(index < queue->count);
	return (char*)queue->base + (index * queue->element_size);
}
