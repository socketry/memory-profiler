// Released under the MIT License.
// Copyright, 2025, by Samuel Williams.

#pragma once

#include <ruby.h>
#include "queue.h"

// Event types
enum Memory_Profiler_Event_Type {
	MEMORY_PROFILER_EVENT_TYPE_NEWOBJ,
	MEMORY_PROFILER_EVENT_TYPE_FREEOBJ,
};

// Event queue item - stores all info needed to process an event
struct Memory_Profiler_Event {
	enum Memory_Profiler_Event_Type type;
	
	// Which Capture instance this event belongs to:
	VALUE capture;
	
	// The class of the object:
	VALUE klass;

	// The Allocations wrapper:
	VALUE allocations;

	// The object itself:
	VALUE object;
};

struct Memory_Profiler_Events;

struct Memory_Profiler_Events* Memory_Profiler_Events_instance(void);

// Enqueue an event to the global queue.
// Returns non-zero on success, zero on failure.
int Memory_Profiler_Events_enqueue(
	enum Memory_Profiler_Event_Type type,
	VALUE capture,
	VALUE klass,
	VALUE allocations,
	VALUE object
);

// Process all queued events immediately (flush the queue)
// Called from Capture stop() to ensure all events are processed before stopping
void Memory_Profiler_Events_process_all(void);
