#------------------------------------------------------------------------------
#
# CMakeLists.txt - Test directory index for async_fifo
#
# Only include subdirectories that exist.
#
#------------------------------------------------------------------------------

add_subdirectory(clock_rates)
add_subdirectory(write_past)
add_subdirectory(write_past_fwft)

# Priority 1 tests
add_subdirectory(reset_sync)
add_subdirectory(ptr_wraparound)
add_subdirectory(empty_timing)
add_subdirectory(full_timing)
add_subdirectory(read_empty)

# Priority 2 tests
add_subdirectory(data_patterns)
add_subdirectory(back_to_back)
add_subdirectory(simultaneous_rdwr)
add_subdirectory(single_entry)

# TODO: Create these test directories when tests are implemented
# add_subdirectory(write_past_flags)
# add_subdirectory(asymm_concat)
# add_subdirectory(asymm_split)
