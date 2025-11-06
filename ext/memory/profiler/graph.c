// Released under the MIT License.
// Copyright, 2025, by Samuel Williams.

#include "graph.h"
#include "allocations.h"

#include "ruby.h"
#include "ruby/st.h"
#include <stdio.h>

#ifdef HAVE_RB_OBJSPACE_REACHABLE_OBJECTS_FROM
extern void rb_objspace_reachable_objects_from(VALUE obj, void (*func)(VALUE, void *), void *data);
#else
static void rb_objspace_reachable_objects_from(VALUE obj, void (*func)(VALUE, void *), void *data) {
	// Use ObjectSpace.reachable_objects_from instead.
}
#endif

void Init_Memory_Profiler_Graph(VALUE Memory_Profiler)
{
}
