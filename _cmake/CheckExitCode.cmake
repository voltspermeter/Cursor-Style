#------------------------------------------------------------------------------
#
# CheckExitCode.cmake - Check VUnit exit code file
#
# This script is called after vvp simulation completes to check if the
# simulation reported a failure via the vunit_exit_code.txt file.
#
# Since Icarus Verilog doesn't propagate $finish() argument as exit code,
# we use a file-based mechanism to communicate test results.
#
#------------------------------------------------------------------------------

set(EXIT_CODE_FILE "${CMAKE_CURRENT_BINARY_DIR}/vunit_exit_code.txt")

if(EXISTS "${EXIT_CODE_FILE}")
    file(READ "${EXIT_CODE_FILE}" EXIT_CODE)
    string(STRIP "${EXIT_CODE}" EXIT_CODE)
    
    if(EXIT_CODE STREQUAL "0")
        message(STATUS "Test PASSED (exit code: 0)")
    else()
        message(FATAL_ERROR "Test FAILED (exit code: ${EXIT_CODE})")
    endif()
else()
    # If no exit code file, assume test didn't complete properly
    message(FATAL_ERROR "Test FAILED - no exit code file generated (simulation may have crashed)")
endif()
