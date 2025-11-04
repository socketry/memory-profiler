// Released under the MIT License.
// Copyright, 2025, by Samuel Williams.

#pragma once

#include <ruby.h>

// Initialize the Capture module.
void Init_Memory_Profiler_Capture(VALUE Memory_Profiler);

// Forward declaration.
struct Memory_Profiler_Event;

// Process a single event. Called from the global event queue processor.
// This is wrapped with rb_protect to catch exceptions.
void Memory_Profiler_Capture_process_event(struct Memory_Profiler_Event *event);
