// Released under the MIT License.
// Copyright, 2025, by Samuel Williams.

#include "capture.h"

void Init_Memory_Profiler(void)
{
#ifdef HAVE_RB_EXT_RACTOR_SAFE
    rb_ext_ractor_safe(true);
#endif
    
    VALUE Memory = rb_const_get(rb_cObject, rb_intern("Memory"));
    VALUE Memory_Profiler = rb_define_module_under(Memory, "Profiler");
    
    Init_Memory_Profiler_Capture(Memory_Profiler);
}

