#------------------------------------------------------------------------------
#
# CMakeLists.txt - Top-level CMake configuration for async_fifo project
#
# This project uses Icarus Verilog for HDL simulation.
#
# Build instructions:
#   mkdir build && cd build
#   cmake ..
#   make                    # Build all targets
#   make test_<name>        # Run specific test
#   make run_all_tests      # Run all tests
#
#------------------------------------------------------------------------------

cmake_minimum_required(VERSION 3.16)
project(async_fifo_project VERSION 1.0.0 LANGUAGES NONE)

# Add CMake module path
list(APPEND CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/_cmake")

# Include helper modules
include(HDLHelpers)
include(IcarusVerilog)
include(VUnitHelpers)

# Set VUnit include directory
set(VUNIT_INCLUDE_DIR "${CMAKE_SOURCE_DIR}/_cmake/vunit" CACHE PATH "VUnit include directory")

# Add to iverilog include path
list(APPEND IVERILOG_INCLUDE_DIRS "${VUNIT_INCLUDE_DIR}")

#------------------------------------------------------------------------------
# Project configuration
#------------------------------------------------------------------------------

message(STATUS "")
message(STATUS "=== Async FIFO Project Configuration ===")
message(STATUS "  Source directory: ${CMAKE_SOURCE_DIR}")
message(STATUS "  Build directory: ${CMAKE_BINARY_DIR}")
message(STATUS "  VUnit includes: ${VUNIT_INCLUDE_DIR}")
message(STATUS "")

#------------------------------------------------------------------------------
# External dependencies
#
# The sync_reg module is an external dependency. Create a stub or provide path.
#------------------------------------------------------------------------------

# Check for external sync_reg module
set(SYNC_REG_SOURCE "" CACHE FILEPATH "Path to sync_reg.v (external dependency)")

if(EXISTS "${SYNC_REG_SOURCE}")
    message(STATUS "Using external sync_reg: ${SYNC_REG_SOURCE}")
    add_hdl_source(${SYNC_REG_SOURCE})
else()
    # Create a stub sync_reg module for testing
    message(STATUS "Creating stub sync_reg module (set SYNC_REG_SOURCE for real implementation)")

    set(STUB_DIR "${CMAKE_BINARY_DIR}/stubs")
    file(MAKE_DIRECTORY ${STUB_DIR})

    file(WRITE "${STUB_DIR}/sync_reg.v" [=[
//------------------------------------------------------------------------------
// sync_reg.v - Synchronizer register stub for testing
//
// This is a stub implementation. Replace with actual sync_reg for production.
//------------------------------------------------------------------------------

module sync_reg #(
    parameter WIDTH = 1,
    parameter RST_ST = 0
) (
    input wire clk,
    input wire rst,
    input wire [WIDTH-1:0] din,
    output reg [WIDTH-1:0] dout
);

    reg [WIDTH-1:0] sync_r1;
    reg [WIDTH-1:0] sync_r2;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sync_r1 <= RST_ST;
            sync_r2 <= RST_ST;
            dout <= RST_ST;
        end else begin
            sync_r1 <= din;
            sync_r2 <= sync_r1;
            dout <= sync_r2;
        end
    end

endmodule
]=])

    # Register stub module
    add_hdl_source("${STUB_DIR}/sync_reg.v")
endif()

#------------------------------------------------------------------------------
# Include source directories
#
# Process CMakeLists.txt files in the source tree
#------------------------------------------------------------------------------

# Add RTL sources
add_subdirectory(src/cores/async_fifo/rtl)

# Add test directories
add_subdirectory(src/cores/async_fifo/test/clock_rates)
add_subdirectory(src/cores/async_fifo/test/write_past)
add_subdirectory(src/cores/async_fifo/test/write_past_fwft)

#------------------------------------------------------------------------------
# Create targets
#------------------------------------------------------------------------------

# Create HDL module targets
create_all_hdl_targets()

# Create VUnit test targets
create_all_vunit_test_targets()

# Create test suite target
add_test_suite(run_all_tests)

#------------------------------------------------------------------------------
# Print summary
#------------------------------------------------------------------------------

print_hdl_modules()
print_vunit_tests()

# Generate dependency list file
generate_dependency_list("${CMAKE_BINARY_DIR}/dependencies.txt")

#------------------------------------------------------------------------------
# CTest integration
#------------------------------------------------------------------------------

enable_testing()

# Add CTest tests for each VUnit test
get_property(TESTS GLOBAL PROPERTY VUNIT_TESTS)
foreach(TEST ${TESTS})
    add_test(
        NAME ${TEST}
        COMMAND ${VVP_EXECUTABLE} ${CMAKE_BINARY_DIR}/${TEST}.vvp
        WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
    )
    set_tests_properties(${TEST} PROPERTIES
        DEPENDS test_${TEST}_compile
    )
endforeach()

message(STATUS "")
message(STATUS "=== Build Targets ===")
message(STATUS "  make                    - Build all")
message(STATUS "  make hdl_<module>       - Compile specific HDL module")
message(STATUS "  make test_<name>        - Run specific test")
message(STATUS "  make run_all_tests      - Run all tests")
message(STATUS "  ctest                   - Run tests via CTest")
message(STATUS "")
