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

# TODO: Create these test directories when tests are implemented
# add_subdirectory(write_past_flags)
# add_subdirectory(asymm_concat)
# add_subdirectory(asymm_split)
