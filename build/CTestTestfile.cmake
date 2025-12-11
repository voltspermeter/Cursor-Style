# CMake generated Testfile for 
# Source directory: /workspace
# Build directory: /workspace/build
# 
# This file includes the relevant testing commands required for 
# testing this directory and lists subdirectories to be tested as well.
add_test(async_fifo_clkrates_tb "/usr/bin/vvp" "/workspace/build/async_fifo_clkrates_tb.vvp")
set_tests_properties(async_fifo_clkrates_tb PROPERTIES  DEPENDS "test_async_fifo_clkrates_tb_compile" WORKING_DIRECTORY "/workspace/build" _BACKTRACE_TRIPLES "/workspace/CMakeLists.txt;148;add_test;/workspace/CMakeLists.txt;0;")
add_test(async_fifo_writepast_tb "/usr/bin/vvp" "/workspace/build/async_fifo_writepast_tb.vvp")
set_tests_properties(async_fifo_writepast_tb PROPERTIES  DEPENDS "test_async_fifo_writepast_tb_compile" WORKING_DIRECTORY "/workspace/build" _BACKTRACE_TRIPLES "/workspace/CMakeLists.txt;148;add_test;/workspace/CMakeLists.txt;0;")
add_test(async_fifo_fwft_writepast_tb "/usr/bin/vvp" "/workspace/build/async_fifo_fwft_writepast_tb.vvp")
set_tests_properties(async_fifo_fwft_writepast_tb PROPERTIES  DEPENDS "test_async_fifo_fwft_writepast_tb_compile" WORKING_DIRECTORY "/workspace/build" _BACKTRACE_TRIPLES "/workspace/CMakeLists.txt;148;add_test;/workspace/CMakeLists.txt;0;")
subdirs("src/cores/async_fifo/rtl")
subdirs("src/cores/async_fifo/test/clock_rates")
subdirs("src/cores/async_fifo/test/write_past")
subdirs("src/cores/async_fifo/test/write_past_fwft")
