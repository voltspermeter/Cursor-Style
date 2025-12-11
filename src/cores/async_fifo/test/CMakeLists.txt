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

# Priority 3 tests
add_subdirectory(near_full)
add_subdirectory(near_empty)
add_subdirectory(depth_variation)
add_subdirectory(width_variation)

# Priority 4 tests
add_subdirectory(random_traffic)
add_subdirectory(clock_jitter)
add_subdirectory(clock_switching)

# Priority 5 tests
add_subdirectory(prog_full_accuracy)
add_subdirectory(flag_consistency)

# Priority 6 tests
add_subdirectory(asymm_boundary)
add_subdirectory(asymm_ratios)

# TODO: Create these test directories when tests are implemented
# add_subdirectory(write_past_flags)
