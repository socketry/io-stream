# Write / Close / Exception Handling

If you use `@io.write` in `#syswrite` implementation, it's possible to invoke the gods of undefined behavior.

```
> write
/home/samuel/Projects/socketry/io-stream/lib/io/stream/buffered.rb:74: [BUG] Segmentation fault at 0x0000000000000000
ruby 3.3.0 (2023-12-25 revision 5124f9ac75) [x86_64-linux]

-- Control frame information -----------------------------------------------
c:0010 p:---- s:0042 e:000041 CFUNC  :write
c:0009 p:0007 s:0037 e:000036 METHOD /home/samuel/Projects/socketry/io-stream/lib/io/stream/buffered.rb:74
c:0008 p:0019 s:0031 e:000030 BLOCK  /home/samuel/Projects/socketry/io-stream/lib/io/stream/generic.rb:140 [FINISH]
c:0007 p:---- s:0028 e:000027 CFUNC  :synchronize
c:0006 p:0015 s:0024 e:000023 METHOD /home/samuel/Projects/socketry/io-stream/lib/io/stream/generic.rb:135
c:0005 p:0023 s:0020 e:000019 METHOD /home/samuel/Projects/socketry/io-stream/lib/io/stream/generic.rb:156
c:0004 p:0019 s:0015 e:000014 BLOCK  test/io/stream/buffered/syswrite.rb:22
c:0003 p:0010 s:0012 e:000011 BLOCK  /home/samuel/.gem/ruby/3.3.0/gems/async-2.10.2/lib/async/task.rb:163
c:0002 p:0008 s:0009 e:000007 BLOCK  /home/samuel/.gem/ruby/3.3.0/gems/async-2.10.2/lib/async/task.rb:376 [FINISH]
c:0001 p:---- s:0003 e:000002 DUMMY  [FINISH]

-- Ruby level backtrace information ----------------------------------------
/home/samuel/.gem/ruby/3.3.0/gems/async-2.10.2/lib/async/task.rb:376:in `block in schedule'
/home/samuel/.gem/ruby/3.3.0/gems/async-2.10.2/lib/async/task.rb:163:in `block in run'
test/io/stream/buffered/syswrite.rb:22:in `block (4 levels) in <top (required)>'
/home/samuel/Projects/socketry/io-stream/lib/io/stream/generic.rb:156:in `write'
/home/samuel/Projects/socketry/io-stream/lib/io/stream/generic.rb:135:in `flush'
/home/samuel/Projects/socketry/io-stream/lib/io/stream/generic.rb:135:in `synchronize'
/home/samuel/Projects/socketry/io-stream/lib/io/stream/generic.rb:140:in `block in flush'
/home/samuel/Projects/socketry/io-stream/lib/io/stream/buffered.rb:74:in `syswrite'
/home/samuel/Projects/socketry/io-stream/lib/io/stream/buffered.rb:74:in `write'

-- Threading information ---------------------------------------------------
Total ractor count: 1
Ruby thread count for this ractor: 1

-- Machine register context ------------------------------------------------
 RIP: 0x00007c92c3d14bf0 RBP: 0x00007c92c41d2760 RSP: 0x00007c92a92393d0
 RAX: 0x000056b2b4875700 RBX: 0x3596c72fd367c900 RCX: 0x000056b2b427cb70
 RDX: 0x00007c92c3865120 RDI: 0x0000000000000000 RSI: 0x00007c92c41d2760
  R8: 0x0000000000000038  R9: 0x000056b2b4eda390 R10: 0x0000000000000003
 R11: 0x00007c92a7f434e8 R12: 0x3596c72fd367c900 R13: 0x00007c92a7bd9be0
 R14: 0x0000000d00000009 R15: 0x000056b2b427f0f0 EFL: 0x0000000000010206

-- C level backtrace information -------------------------------------------
/home/samuel/.rubies/ruby-3.3.0/lib/libruby.so.3.3(rb_print_backtrace+0x14) [0x7c92c3f1c6bb] /tmp/ruby-build.20231228132516.30619.vhOi8F/ruby-3.3.0/vm_dump.c:820
/home/samuel/.rubies/ruby-3.3.0/lib/libruby.so.3.3(rb_vm_bugreport) /tmp/ruby-build.20231228132516.30619.vhOi8F/ruby-3.3.0/vm_dump.c:1151
/home/samuel/.rubies/ruby-3.3.0/lib/libruby.so.3.3(rb_bug_for_fatal_signal+0x100) [0x7c92c3d12ed0] /tmp/ruby-build.20231228132516.30619.vhOi8F/ruby-3.3.0/error.c:1065
/home/samuel/.rubies/ruby-3.3.0/lib/libruby.so.3.3(sigsegv+0x4b) [0x7c92c3e66dab] /tmp/ruby-build.20231228132516.30619.vhOi8F/ruby-3.3.0/signal.c:926
/usr/lib/libc.so.6(0x7c92c38c8770) [0x7c92c38c8770]
/home/samuel/.rubies/ruby-3.3.0/lib/libruby.so.3.3(displaying_class_of+0x1a) [0x7c92c3d14bf0] /tmp/ruby-build.20231228132516.30619.vhOi8F/ruby-3.3.0/error.c:1182
/home/samuel/.rubies/ruby-3.3.0/lib/libruby.so.3.3(RB_BUILTIN_TYPE) /tmp/ruby-build.20231228132516.30619.vhOi8F/ruby-3.3.0/error.c:1179
/home/samuel/.rubies/ruby-3.3.0/lib/libruby.so.3.3(rbimpl_RB_TYPE_P_fastpath) ./include/ruby/internal/value_type.h:351
/home/samuel/.rubies/ruby-3.3.0/lib/libruby.so.3.3(RB_TYPE_P) ./include/ruby/internal/value_type.h:378
/home/samuel/.rubies/ruby-3.3.0/lib/libruby.so.3.3(rb_check_typeddata) /tmp/ruby-build.20231228132516.30619.vhOi8F/ruby-3.3.0/error.c:1315
/home/samuel/.rubies/ruby-3.3.0/lib/libruby.so.3.3(mutex_ptr+0x5) [0x7c92c3eb293f] /tmp/ruby-build.20231228132516.30619.vhOi8F/ruby-3.3.0/thread_sync.c:155
/home/samuel/.rubies/ruby-3.3.0/lib/libruby.so.3.3(do_mutex_lock) /tmp/ruby-build.20231228132516.30619.vhOi8F/ruby-3.3.0/thread_sync.c:301
/home/samuel/.rubies/ruby-3.3.0/lib/libruby.so.3.3(rb_multi_ractor_p+0x0) [0x7c92c3eb5dbd] /tmp/ruby-build.20231228132516.30619.vhOi8F/ruby-3.3.0/thread.c:1674
/home/samuel/.rubies/ruby-3.3.0/lib/libruby.so.3.3(rb_vm_lock_enter) ./vm_sync.h:74
/home/samuel/.rubies/ruby-3.3.0/lib/libruby.so.3.3(thread_io_wake_pending_closer) /tmp/ruby-build.20231228132516.30619.vhOi8F/ruby-3.3.0/thread.c:1680
/home/samuel/.rubies/ruby-3.3.0/lib/libruby.so.3.3(rb_thread_io_blocking_call) /tmp/ruby-build.20231228132516.30619.vhOi8F/ruby-3.3.0/thread.c:1764
/home/samuel/.rubies/ruby-3.3.0/lib/libruby.so.3.3(rb_io_write_memory+0xa4) [0x7c92c3d57fe4] /tmp/ruby-build.20231228132516.30619.vhOi8F/ruby-3.3.0/io.c:1322
/home/samuel/.rubies/ruby-3.3.0/lib/libruby.so.3.3(io_binwrite_string+0x17e) [0x7c92c3d604ce] /tmp/ruby-build.20231228132516.30619.vhOi8F/ruby-3.3.0/io.c:1747
/home/samuel/.rubies/ruby-3.3.0/lib/libruby.so.3.3(rb_ensure+0x110) [0x7c92c3d1cb30] /tmp/ruby-build.20231228132516.30619.vhOi8F/ruby-3.3.0/eval.c:1009
/home/samuel/.rubies/ruby-3.3.0/lib/libruby.so.3.3(io_binwrite+0x140) [0x7c92c3d606e0] /tmp/ruby-build.20231228132516.30619.vhOi8F/ruby-3.3.0/io.c:1872
/home/samuel/.rubies/ruby-3.3.0/lib/libruby.so.3.3(io_fwrite+0x51) [0x7c92c3d608b2] /tmp/ruby-build.20231228132516.30619.vhOi8F/ruby-3.3.0/io.c:1977
/home/samuel/.rubies/ruby-3.3.0/lib/libruby.so.3.3(io_write) /tmp/ruby-build.20231228132516.30619.vhOi8F/ruby-3.3.0/io.c:2015
/home/samuel/.rubies/ruby-3.3.0/lib/libruby.so.3.3(vm_cfp_consistent_p+0x0) [0x7c92c3eee989] /tmp/ruby-build.20231228132516.30619.vhOi8F/ruby-3.3.0/vm_insnhelper.c:3490
/home/samuel/.rubies/ruby-3.3.0/lib/libruby.so.3.3(vm_call_cfunc_with_frame_) /tmp/ruby-build.20231228132516.30619.vhOi8F/ruby-3.3.0/vm_insnhelper.c:3492
/home/samuel/.rubies/ruby-3.3.0/lib/libruby.so.3.3(vm_call_cfunc_with_frame) /tmp/ruby-build.20231228132516.30619.vhOi8F/ruby-3.3.0/vm_insnhelper.c:3518
/home/samuel/.rubies/ruby-3.3.0/lib/libruby.so.3.3(vm_call_cfunc_other) /tmp/ruby-build.20231228132516.30619.vhOi8F/ruby-3.3.0/vm_insnhelper.c:3544
/home/samuel/.rubies/ruby-3.3.0/lib/libruby.so.3.3(vm_sendish+0xac) [0x7c92c3effe09] /tmp/ruby-build.20231228132516.30619.vhOi8F/ruby-3.3.0/vm_insnhelper.c:5581
/home/samuel/.rubies/ruby-3.3.0/lib/libruby.so.3.3(vm_exec_core) /tmp/ruby-build.20231228132516.30619.vhOi8F/ruby-3.3.0/insns.def:834
/home/samuel/.rubies/ruby-3.3.0/lib/libruby.so.3.3(rb_vm_exec+0x179) [0x7c92c3f05db9] /tmp/ruby-build.20231228132516.30619.vhOi8F/ruby-3.3.0/vm.c:2486
/home/samuel/.rubies/ruby-3.3.0/lib/libruby.so.3.3(rb_yield+0xc2) [0x7c92c3f0b442] /tmp/ruby-build.20231228132516.30619.vhOi8F/ruby-3.3.0/vm.c:1634
/home/samuel/.rubies/ruby-3.3.0/lib/libruby.so.3.3(rb_ensure+0x110) [0x7c92c3d1cb30] /tmp/ruby-build.20231228132516.30619.vhOi8F/ruby-3.3.0/eval.c:1009
/home/samuel/.rubies/ruby-3.3.0/lib/libruby.so.3.3(vm_call_cfunc_with_frame_+0xd5) [0x7c92c3eee624] /tmp/ruby-build.20231228132516.30619.vhOi8F/ruby-3.3.0/vm_insnhelper.c:3490
/home/samuel/.rubies/ruby-3.3.0/lib/libruby.so.3.3(vm_call_cfunc_with_frame) /tmp/ruby-build.20231228132516.30619.vhOi8F/ruby-3.3.0/vm_insnhelper.c:3518
/home/samuel/.rubies/ruby-3.3.0/lib/libruby.so.3.3(vm_sendish+0x160) [0x7c92c3ef4f00] /tmp/ruby-build.20231228132516.30619.vhOi8F/ruby-3.3.0/vm_insnhelper.c:5581
/home/samuel/.rubies/ruby-3.3.0/lib/libruby.so.3.3(vm_exec_core+0x2460) [0x7c92c3f02140] /tmp/ruby-build.20231228132516.30619.vhOi8F/ruby-3.3.0/insns.def:814
/home/samuel/.rubies/ruby-3.3.0/lib/libruby.so.3.3(rb_vm_exec+0x179) [0x7c92c3f05db9] /tmp/ruby-build.20231228132516.30619.vhOi8F/ruby-3.3.0/vm.c:2486
/home/samuel/.rubies/ruby-3.3.0/lib/libruby.so.3.3(rb_vm_invoke_proc+0x5e) [0x7c92c3f0b9fe] /tmp/ruby-build.20231228132516.30619.vhOi8F/ruby-3.3.0/vm.c:1728
/home/samuel/.rubies/ruby-3.3.0/lib/libruby.so.3.3(rb_fiber_start+0x19f) [0x7c92c3cee90f] /tmp/ruby-build.20231228132516.30619.vhOi8F/ruby-3.3.0/cont.c:2536
/home/samuel/.rubies/ruby-3.3.0/lib/libruby.so.3.3(fiber_entry+0x1c) [0x7c92c3ceec5c] /tmp/ruby-build.20231228132516.30619.vhOi8F/ruby-3.3.0/cont.c:847
```