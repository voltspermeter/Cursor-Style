# CMake generated Testfile for 
# Source directory: /workspace
# Build directory: /workspace/build
# 
# This file includes the relevant testing commands required for 
# testing this directory and lists subdirectories to be tested as well.
add_test(async_fifo_clkrates_tb "/usr/bin/vvp" "/workspace/build/async_fifo_clkrates_tb.vvp")
set_tests_properties(async_fifo_clkrates_tb PROPERTIES  DEPENDS "test_async_fifo_clkrates_tb_compile" WORKING_DIRECTORY "/workspace/build" _BACKTRACE_TRIPLES "/workspace/CMakeLists.txt;146;add_test;/workspace/CMakeLists.txt;0;")
add_test(async_fifo_writepast_tb "/usr/bin/vvp" "/workspace/build/async_fifo_writepast_tb.vvp")
set_tests_properties(async_fifo_writepast_tb PROPERTIES  DEPENDS "test_async_fifo_writepast_tb_compile" WORKING_DIRECTORY "/workspace/build" _BACKTRACE_TRIPLES "/workspace/CMakeLists.txt;146;add_test;/workspace/CMakeLists.txt;0;")
add_test(async_fifo_fwft_writepast_tb "/usr/bin/vvp" "/workspace/build/async_fifo_fwft_writepast_tb.vvp")
set_tests_properties(async_fifo_fwft_writepast_tb PROPERTIES  DEPENDS "test_async_fifo_fwft_writepast_tb_compile" WORKING_DIRECTORY "/workspace/build" _BACKTRACE_TRIPLES "/workspace/CMakeLists.txt;146;add_test;/workspace/CMakeLists.txt;0;")
add_test(async_fifo_reset_sync_tb "/usr/bin/vvp" "/workspace/build/async_fifo_reset_sync_tb.vvp")
set_tests_properties(async_fifo_reset_sync_tb PROPERTIES  DEPENDS "test_async_fifo_reset_sync_tb_compile" WORKING_DIRECTORY "/workspace/build" _BACKTRACE_TRIPLES "/workspace/CMakeLists.txt;146;add_test;/workspace/CMakeLists.txt;0;")
add_test(async_fifo_ptr_wraparound_tb "/usr/bin/vvp" "/workspace/build/async_fifo_ptr_wraparound_tb.vvp")
set_tests_properties(async_fifo_ptr_wraparound_tb PROPERTIES  DEPENDS "test_async_fifo_ptr_wraparound_tb_compile" WORKING_DIRECTORY "/workspace/build" _BACKTRACE_TRIPLES "/workspace/CMakeLists.txt;146;add_test;/workspace/CMakeLists.txt;0;")
add_test(async_fifo_empty_timing_tb "/usr/bin/vvp" "/workspace/build/async_fifo_empty_timing_tb.vvp")
set_tests_properties(async_fifo_empty_timing_tb PROPERTIES  DEPENDS "test_async_fifo_empty_timing_tb_compile" WORKING_DIRECTORY "/workspace/build" _BACKTRACE_TRIPLES "/workspace/CMakeLists.txt;146;add_test;/workspace/CMakeLists.txt;0;")
add_test(async_fifo_full_timing_tb "/usr/bin/vvp" "/workspace/build/async_fifo_full_timing_tb.vvp")
set_tests_properties(async_fifo_full_timing_tb PROPERTIES  DEPENDS "test_async_fifo_full_timing_tb_compile" WORKING_DIRECTORY "/workspace/build" _BACKTRACE_TRIPLES "/workspace/CMakeLists.txt;146;add_test;/workspace/CMakeLists.txt;0;")
add_test(async_fifo_read_empty_tb "/usr/bin/vvp" "/workspace/build/async_fifo_read_empty_tb.vvp")
set_tests_properties(async_fifo_read_empty_tb PROPERTIES  DEPENDS "test_async_fifo_read_empty_tb_compile" WORKING_DIRECTORY "/workspace/build" _BACKTRACE_TRIPLES "/workspace/CMakeLists.txt;146;add_test;/workspace/CMakeLists.txt;0;")
add_test(async_fifo_data_patterns_tb "/usr/bin/vvp" "/workspace/build/async_fifo_data_patterns_tb.vvp")
set_tests_properties(async_fifo_data_patterns_tb PROPERTIES  DEPENDS "test_async_fifo_data_patterns_tb_compile" WORKING_DIRECTORY "/workspace/build" _BACKTRACE_TRIPLES "/workspace/CMakeLists.txt;146;add_test;/workspace/CMakeLists.txt;0;")
add_test(async_fifo_back_to_back_tb "/usr/bin/vvp" "/workspace/build/async_fifo_back_to_back_tb.vvp")
set_tests_properties(async_fifo_back_to_back_tb PROPERTIES  DEPENDS "test_async_fifo_back_to_back_tb_compile" WORKING_DIRECTORY "/workspace/build" _BACKTRACE_TRIPLES "/workspace/CMakeLists.txt;146;add_test;/workspace/CMakeLists.txt;0;")
add_test(async_fifo_simultaneous_tb "/usr/bin/vvp" "/workspace/build/async_fifo_simultaneous_tb.vvp")
set_tests_properties(async_fifo_simultaneous_tb PROPERTIES  DEPENDS "test_async_fifo_simultaneous_tb_compile" WORKING_DIRECTORY "/workspace/build" _BACKTRACE_TRIPLES "/workspace/CMakeLists.txt;146;add_test;/workspace/CMakeLists.txt;0;")
add_test(async_fifo_single_entry_tb "/usr/bin/vvp" "/workspace/build/async_fifo_single_entry_tb.vvp")
set_tests_properties(async_fifo_single_entry_tb PROPERTIES  DEPENDS "test_async_fifo_single_entry_tb_compile" WORKING_DIRECTORY "/workspace/build" _BACKTRACE_TRIPLES "/workspace/CMakeLists.txt;146;add_test;/workspace/CMakeLists.txt;0;")
subdirs("src/cores/async_fifo/rtl")
subdirs("src/cores/async_fifo/test")
