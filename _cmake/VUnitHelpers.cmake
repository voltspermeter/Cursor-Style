#------------------------------------------------------------------------------
#
# VUnitHelpers.cmake - CMake functions for VUnit testbench support
#
# This module provides functions to register and run VUnit-based testbenches
# using Icarus Verilog.
#
#------------------------------------------------------------------------------

# Global properties to track testbenches
define_property(GLOBAL PROPERTY VUNIT_TESTS
    BRIEF_DOCS "List of all registered VUnit tests"
    FULL_DOCS "Contains the names of all VUnit tests registered with add_vunit_test")

set_property(GLOBAL PROPERTY VUNIT_TESTS "")

# Path to VUnit includes (can be overridden)
set(VUNIT_INCLUDE_DIR "${CMAKE_SOURCE_DIR}/_cmake/vunit" CACHE PATH "Path to VUnit include files")

#------------------------------------------------------------------------------
# add_vunit_test(<testbench_file>
#                DEPENDS <module>
#                [VCDS <vcd_name> ...]
#                [VIEW_SIGNALS <signal> ...]
#                [TIMEOUT <seconds>])
#
# Register a VUnit testbench and create simulation targets.
#
# Arguments:
#   testbench_file - The SystemVerilog testbench file
#   DEPENDS        - The RTL module being tested
#   VCDS           - List of VCD file names to generate
#   VIEW_SIGNALS   - Signals to include in waveform viewer
#   TIMEOUT        - Simulation timeout in seconds (default: 10000)
#
# Creates targets:
#   test_<name>_compile - Compile the testbench
#   test_<name>_run     - Run the simulation
#   test_<name>         - Alias for run
#
# Example:
#   add_vunit_test(async_fifo_tb.sv
#     DEPENDS async_fifo
#     VCDS test_case_1
#     VIEW_SIGNALS DUT.rst DUT.clk)
#
#------------------------------------------------------------------------------
function(add_vunit_test TESTBENCH_FILE)
    # Parse arguments
    cmake_parse_arguments(ARG "" "TIMEOUT" "DEPENDS;VCDS;VIEW_SIGNALS" ${ARGN})

    # Get testbench name from filename
    get_filename_component(TB_NAME ${TESTBENCH_FILE} NAME_WE)

    # Get absolute path to testbench
    get_filename_component(TB_PATH ${TESTBENCH_FILE} ABSOLUTE)

    # Check if testbench exists
    if(NOT EXISTS ${TB_PATH})
        message(FATAL_ERROR "Testbench file not found: ${TB_PATH}")
    endif()

    # Register in global list
    get_property(TESTS GLOBAL PROPERTY VUNIT_TESTS)
    list(APPEND TESTS ${TB_NAME})
    set_property(GLOBAL PROPERTY VUNIT_TESTS ${TESTS})

    # Store testbench properties
    set_property(GLOBAL PROPERTY VUNIT_TEST_${TB_NAME}_SOURCE ${TB_PATH})
    set_property(GLOBAL PROPERTY VUNIT_TEST_${TB_NAME}_DEPENDS ${ARG_DEPENDS})
    set_property(GLOBAL PROPERTY VUNIT_TEST_${TB_NAME}_VCDS "${ARG_VCDS}")
    set_property(GLOBAL PROPERTY VUNIT_TEST_${TB_NAME}_VIEW_SIGNALS "${ARG_VIEW_SIGNALS}")

    if(ARG_TIMEOUT)
        set_property(GLOBAL PROPERTY VUNIT_TEST_${TB_NAME}_TIMEOUT ${ARG_TIMEOUT})
    else()
        set_property(GLOBAL PROPERTY VUNIT_TEST_${TB_NAME}_TIMEOUT 10000)
    endif()

    message(STATUS "Registered VUnit test: ${TB_NAME}")
    if(ARG_DEPENDS)
        message(STATUS "  Depends on: ${ARG_DEPENDS}")
    endif()
endfunction()

#------------------------------------------------------------------------------
# create_vunit_test_target(<test_name>)
#
# Create Icarus Verilog simulation targets for a registered VUnit test.
#
#------------------------------------------------------------------------------
function(create_vunit_test_target TEST_NAME)
    if(NOT IVERILOG_EXECUTABLE OR NOT VVP_EXECUTABLE)
        message(WARNING "Icarus Verilog not found, skipping test: ${TEST_NAME}")
        return()
    endif()

    # Get testbench properties
    get_property(TB_SOURCE GLOBAL PROPERTY VUNIT_TEST_${TEST_NAME}_SOURCE)
    get_property(TB_DEPENDS GLOBAL PROPERTY VUNIT_TEST_${TEST_NAME}_DEPENDS)
    get_property(TB_TIMEOUT GLOBAL PROPERTY VUNIT_TEST_${TEST_NAME}_TIMEOUT)

    if(NOT TB_SOURCE)
        message(FATAL_ERROR "VUnit test not found: ${TEST_NAME}")
    endif()

    # Collect all source files
    set(ALL_SOURCES "")

    # Add RTL dependency sources
    foreach(DEP ${TB_DEPENDS})
        get_property(DEP_EXISTS GLOBAL PROPERTY HDL_MODULE_${DEP}_SOURCE)
        if(DEP_EXISTS)
            get_hdl_module_all_sources(${DEP} DEP_SOURCES)
            list(APPEND ALL_SOURCES ${DEP_SOURCES})
        else()
            message(WARNING "Dependency module not found: ${DEP} (required by ${TEST_NAME})")
        endif()
    endforeach()

    # Add testbench source
    list(APPEND ALL_SOURCES ${TB_SOURCE})

    # Remove duplicates
    list(REMOVE_DUPLICATES ALL_SOURCES)

    # Target names
    set(TARGET_NAME "test_${TEST_NAME}")

    # Output files
    set(VVP_FILE ${CMAKE_CURRENT_BINARY_DIR}/${TEST_NAME}.vvp)
    set(LOG_FILE ${CMAKE_CURRENT_BINARY_DIR}/${TEST_NAME}.log)
    set(EXIT_CODE_FILE ${CMAKE_CURRENT_BINARY_DIR}/vunit_exit_code.txt)

    # Build include flags
    set(INCLUDE_FLAGS "")
    foreach(INC_DIR ${IVERILOG_INCLUDE_DIRS})
        list(APPEND INCLUDE_FLAGS "-I${INC_DIR}")
    endforeach()

    # Add VUnit include directory
    if(EXISTS ${VUNIT_INCLUDE_DIR})
        list(APPEND INCLUDE_FLAGS "-I${VUNIT_INCLUDE_DIR}")
    endif()

    # Compile command
    add_custom_command(
        OUTPUT ${VVP_FILE}
        COMMAND ${IVERILOG_EXECUTABLE}
            ${IVERILOG_FLAGS}
            ${INCLUDE_FLAGS}
            -s ${TEST_NAME}
            -o ${VVP_FILE}
            ${ALL_SOURCES}
        DEPENDS ${ALL_SOURCES}
        COMMENT "Compiling test: ${TEST_NAME}"
        VERBATIM
    )

    # Compile target
    add_custom_target(${TARGET_NAME}_compile
        DEPENDS ${VVP_FILE}
    )

    # Run target - runs simulation and checks exit code file
    add_custom_target(${TARGET_NAME}_run
        COMMAND ${CMAKE_COMMAND} -E remove -f ${EXIT_CODE_FILE}
        COMMAND ${VVP_EXECUTABLE} ${VVP_FILE}
        COMMAND ${CMAKE_COMMAND} -P ${CMAKE_SOURCE_DIR}/_cmake/CheckExitCode.cmake
        DEPENDS ${VVP_FILE}
        WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
        COMMENT "Running test: ${TEST_NAME}"
        VERBATIM
    )

    # Alias target
    add_custom_target(${TARGET_NAME}
        DEPENDS ${TARGET_NAME}_run
    )

    # Store properties
    set_target_properties(${TARGET_NAME}_compile PROPERTIES
        VVP_FILE ${VVP_FILE}
        TESTBENCH ${TEST_NAME}
        SOURCES "${ALL_SOURCES}"
    )

    message(STATUS "Created test target: ${TARGET_NAME}")
    message(STATUS "  Sources: ${ALL_SOURCES}")
endfunction()

#------------------------------------------------------------------------------
# create_all_vunit_test_targets()
#
# Create simulation targets for all registered VUnit tests.
#
#------------------------------------------------------------------------------
function(create_all_vunit_test_targets)
    get_property(TESTS GLOBAL PROPERTY VUNIT_TESTS)

    foreach(TEST ${TESTS})
        create_vunit_test_target(${TEST})
    endforeach()
endfunction()

#------------------------------------------------------------------------------
# add_build_all_tests_target()
#
# Create a target that compiles all registered tests without running them.
# This is useful for ensuring all tests are built before running ctest.
#
#------------------------------------------------------------------------------
function(add_build_all_tests_target)
    get_property(TESTS GLOBAL PROPERTY VUNIT_TESTS)

    set(COMPILE_TARGETS "")
    foreach(TEST ${TESTS})
        list(APPEND COMPILE_TARGETS "test_${TEST}_compile")
    endforeach()

    if(COMPILE_TARGETS)
        add_custom_target(build_all_tests
            DEPENDS ${COMPILE_TARGETS}
            COMMENT "Building all test benches"
        )
        message(STATUS "Created target: build_all_tests")
    endif()
endfunction()

#------------------------------------------------------------------------------
# add_test_suite(<suite_name>)
#
# Create a target that runs all registered tests.
# Note: This target stops on first failure. Use 'ctest' for running all tests
# and collecting results even when some fail.
#
#------------------------------------------------------------------------------
function(add_test_suite SUITE_NAME)
    get_property(TESTS GLOBAL PROPERTY VUNIT_TESTS)

    set(TEST_TARGETS "")
    foreach(TEST ${TESTS})
        list(APPEND TEST_TARGETS "test_${TEST}_run")
    endforeach()

    if(TEST_TARGETS)
        add_custom_target(${SUITE_NAME}
            DEPENDS ${TEST_TARGETS}
            COMMENT "Running all tests in suite: ${SUITE_NAME}"
        )
        message(STATUS "Created test suite: ${SUITE_NAME}")
    endif()
endfunction()

#------------------------------------------------------------------------------
# add_test_suite_script(<suite_name>)
#
# Create a target that runs all tests via a script, continuing past failures.
# Results are summarized at the end.
#
#------------------------------------------------------------------------------
function(add_test_suite_script SUITE_NAME)
    get_property(TESTS GLOBAL PROPERTY VUNIT_TESTS)

    # Create a shell script that runs all tests and collects results
    set(SCRIPT_FILE "${CMAKE_BINARY_DIR}/run_${SUITE_NAME}.sh")
    
    set(SCRIPT_CONTENT "#!/bin/bash\n")
    string(APPEND SCRIPT_CONTENT "# Auto-generated test runner script\n")
    string(APPEND SCRIPT_CONTENT "# Runs all tests and reports summary\n\n")
    string(APPEND SCRIPT_CONTENT "cd \"${CMAKE_BINARY_DIR}\"\n\n")
    string(APPEND SCRIPT_CONTENT "PASSED=0\n")
    string(APPEND SCRIPT_CONTENT "FAILED=0\n")
    string(APPEND SCRIPT_CONTENT "FAILED_TESTS=\"\"\n\n")

    foreach(TEST ${TESTS})
        string(APPEND SCRIPT_CONTENT "echo \"Running: ${TEST}\"\n")
        string(APPEND SCRIPT_CONTENT "if ${VVP_EXECUTABLE} ${CMAKE_BINARY_DIR}/${TEST}.vvp\; then\n")
        string(APPEND SCRIPT_CONTENT "    ((PASSED++))\n")
        string(APPEND SCRIPT_CONTENT "else\n")
        string(APPEND SCRIPT_CONTENT "    ((FAILED++))\n")
        string(APPEND SCRIPT_CONTENT "    FAILED_TESTS=\"\$FAILED_TESTS ${TEST}\"\n")
        string(APPEND SCRIPT_CONTENT "fi\n\n")
    endforeach()

    string(APPEND SCRIPT_CONTENT "echo \"\"\n")
    string(APPEND SCRIPT_CONTENT "echo \"============================================\"\n")
    string(APPEND SCRIPT_CONTENT "echo \"  TEST SUMMARY\"\n")
    string(APPEND SCRIPT_CONTENT "echo \"============================================\"\n")
    string(APPEND SCRIPT_CONTENT "echo \"  Passed: \$PASSED\"\n")
    string(APPEND SCRIPT_CONTENT "echo \"  Failed: \$FAILED\"\n")
    string(APPEND SCRIPT_CONTENT "echo \"  Total:  \$((PASSED + FAILED))\"\n")
    string(APPEND SCRIPT_CONTENT "if [ \$FAILED -gt 0 ]\; then\n")
    string(APPEND SCRIPT_CONTENT "    echo \"\"\n")
    string(APPEND SCRIPT_CONTENT "    echo \"  Failed tests:\$FAILED_TESTS\"\n")
    string(APPEND SCRIPT_CONTENT "fi\n")
    string(APPEND SCRIPT_CONTENT "echo \"============================================\"\n")
    string(APPEND SCRIPT_CONTENT "exit \$FAILED\n")

    file(WRITE ${SCRIPT_FILE} ${SCRIPT_CONTENT})

    # Make script executable
    file(CHMOD ${SCRIPT_FILE} 
        PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE
                    GROUP_READ GROUP_EXECUTE
                    WORLD_READ WORLD_EXECUTE)

    # Create target that depends on compilation and runs the script
    get_property(TESTS GLOBAL PROPERTY VUNIT_TESTS)
    set(COMPILE_TARGETS "")
    foreach(TEST ${TESTS})
        list(APPEND COMPILE_TARGETS "test_${TEST}_compile")
    endforeach()

    add_custom_target(${SUITE_NAME}_all
        COMMAND ${SCRIPT_FILE}
        DEPENDS ${COMPILE_TARGETS}
        WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
        COMMENT "Running all tests (continues past failures)"
    )
    message(STATUS "Created test suite script: ${SUITE_NAME}_all")
endfunction()

#------------------------------------------------------------------------------
# print_vunit_tests()
#
# Print all registered VUnit tests (for debugging).
#
#------------------------------------------------------------------------------
function(print_vunit_tests)
    get_property(TESTS GLOBAL PROPERTY VUNIT_TESTS)

    message(STATUS "")
    message(STATUS "=== Registered VUnit Tests ===")
    foreach(TEST ${TESTS})
        get_property(SOURCE GLOBAL PROPERTY VUNIT_TEST_${TEST}_SOURCE)
        get_property(DEPENDS GLOBAL PROPERTY VUNIT_TEST_${TEST}_DEPENDS)
        get_property(VCDS GLOBAL PROPERTY VUNIT_TEST_${TEST}_VCDS)

        message(STATUS "Test: ${TEST}")
        message(STATUS "  Source: ${SOURCE}")
        if(DEPENDS)
            message(STATUS "  Depends: ${DEPENDS}")
        endif()
        if(VCDS)
            message(STATUS "  VCDs: ${VCDS}")
        endif()
    endforeach()
    message(STATUS "==============================")
    message(STATUS "")
endfunction()

#------------------------------------------------------------------------------
# generate_dependency_list(<output_file>)
#
# Generate a file listing all modules, tests, and their dependencies.
#
#------------------------------------------------------------------------------
function(generate_dependency_list OUTPUT_FILE)
    # Get all modules
    get_property(MODULES GLOBAL PROPERTY HDL_MODULES)
    get_property(TESTS GLOBAL PROPERTY VUNIT_TESTS)

    # Generate content
    set(CONTENT "# Auto-generated dependency list\n")
    string(APPEND CONTENT "# Generated by CMake on ${CMAKE_CURRENT_DATE}\n\n")

    string(APPEND CONTENT "# HDL Modules\n")
    foreach(MODULE ${MODULES})
        get_property(SOURCE GLOBAL PROPERTY HDL_MODULE_${MODULE}_SOURCE)
        get_property(DEPS GLOBAL PROPERTY HDL_MODULE_${MODULE}_DEPS)

        string(APPEND CONTENT "MODULE ${MODULE}\n")
        string(APPEND CONTENT "  SOURCE ${SOURCE}\n")
        if(DEPS)
            string(APPEND CONTENT "  DEPENDS ${DEPS}\n")
        endif()
        string(APPEND CONTENT "\n")
    endforeach()

    string(APPEND CONTENT "# VUnit Tests\n")
    foreach(TEST ${TESTS})
        get_property(SOURCE GLOBAL PROPERTY VUNIT_TEST_${TEST}_SOURCE)
        get_property(DEPENDS GLOBAL PROPERTY VUNIT_TEST_${TEST}_DEPENDS)

        string(APPEND CONTENT "TEST ${TEST}\n")
        string(APPEND CONTENT "  SOURCE ${SOURCE}\n")
        if(DEPENDS)
            string(APPEND CONTENT "  DEPENDS ${DEPENDS}\n")
        endif()
        string(APPEND CONTENT "\n")
    endforeach()

    file(WRITE ${OUTPUT_FILE} ${CONTENT})
    message(STATUS "Generated dependency list: ${OUTPUT_FILE}")
endfunction()
