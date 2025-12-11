//------------------------------------------------------------------------------
//
// vunit_defines.svh - VUnit compatibility macros for Icarus Verilog
//
// This file provides VUnit-compatible macros that work with Icarus Verilog.
// It implements a simplified version of the VUnit test framework.
//
//------------------------------------------------------------------------------

`ifndef VUNIT_DEFINES_SVH
`define VUNIT_DEFINES_SVH

//------------------------------------------------------------------------------
// Configuration
//------------------------------------------------------------------------------

// Set to 1 to stop simulation on first failure
`ifndef VUNIT_STOP_ON_FAILURE
`define VUNIT_STOP_ON_FAILURE 0
`endif

//------------------------------------------------------------------------------
// Test Status Tracking (global variables)
//------------------------------------------------------------------------------

// These are declared in the module scope by TEST_SUITE_VARS
`define TEST_SUITE_VARS \
    integer __vunit_test_passed = 1; \
    integer __vunit_check_count = 0; \
    integer __vunit_fail_count = 0; \
    integer __vunit_exit_code = 0; \
    string  __vunit_current_test = ""

//------------------------------------------------------------------------------
// TEST_SUITE - Defines a test suite
//
// Usage:
//   `TEST_SUITE begin
//     `TEST_CASE("test1") begin ... end
//     `TEST_CASE("test2") begin ... end
//   end
//
// The TEST_SUITE automatically:
//   - Declares tracking variables
//   - Prints test summary at end
//   - Calls $finish with appropriate exit code
//------------------------------------------------------------------------------
`define TEST_SUITE \
    `TEST_SUITE_VARS; \
    initial begin \
        __vunit_test_passed = 1; \
        __vunit_check_count = 0; \
        __vunit_fail_count = 0; \
        __vunit_exit_code = 0

//------------------------------------------------------------------------------
// TEST_SUITE_END - End of test suite (call after all TEST_CASEs)
//------------------------------------------------------------------------------
`define TEST_SUITE_END \
        /* Print summary */ \
        $display(""); \
        $display("=== TEST SUMMARY ==="); \
        $display("  Total checks: %0d", __vunit_check_count); \
        $display("  Failures: %0d", __vunit_fail_count); \
        if (__vunit_fail_count == 0) begin \
            $display("  Result: PASSED"); \
            __vunit_exit_code = 0; \
        end else begin \
            $display("  Result: FAILED"); \
            __vunit_exit_code = 1; \
        end \
        $display("===================="); \
        $display(""); \
        /* Write exit code to file for external checking */ \
        __vunit_write_exit_code(__vunit_exit_code); \
        $finish; \
    end

//------------------------------------------------------------------------------
// TEST_CASE - Defines a test case within a suite
//
// Usage:
//   `TEST_CASE("Test Name") begin
//     // test code
//   end
//------------------------------------------------------------------------------
`define TEST_CASE(name) \
    __vunit_current_test = name; \
    __vunit_test_passed = 1; \
    $display(""); \
    $display("=== TEST CASE: %s ===", name); \
    $display("");

//------------------------------------------------------------------------------
// CHECK_EQUAL - Assert that two values are equal
//
// Usage:
//   `CHECK_EQUAL(expected, actual)
//
// On failure:
//   - Prints diagnostic message
//   - Increments failure counter
//   - Optionally stops simulation (if VUNIT_STOP_ON_FAILURE=1)
//------------------------------------------------------------------------------
`define CHECK_EQUAL(expected, actual) \
    __vunit_check_count = __vunit_check_count + 1; \
    if ((expected) !== (actual)) begin \
        $display(""); \
        $display("FAIL: CHECK_EQUAL at %s:%0d", `__FILE__, `__LINE__); \
        $display("  Test: %s", __vunit_current_test); \
        $display("  Expected: %0d (0x%0h)", (expected), (expected)); \
        $display("  Actual:   %0d (0x%0h)", (actual), (actual)); \
        $display(""); \
        __vunit_test_passed = 0; \
        __vunit_fail_count = __vunit_fail_count + 1; \
        __vunit_exit_code = 1; \
        if (`VUNIT_STOP_ON_FAILURE) begin \
            $display("!!! STOPPING ON FIRST FAILURE !!!"); \
            __vunit_write_exit_code(1); \
            $finish; \
        end \
    end

//------------------------------------------------------------------------------
// CHECK_TRUE - Assert that a condition is true
//
// Usage:
//   `CHECK_TRUE(condition)
//------------------------------------------------------------------------------
`define CHECK_TRUE(condition) \
    __vunit_check_count = __vunit_check_count + 1; \
    if (!(condition)) begin \
        $display(""); \
        $display("FAIL: CHECK_TRUE at %s:%0d", `__FILE__, `__LINE__); \
        $display("  Test: %s", __vunit_current_test); \
        $display("  Condition was false"); \
        $display(""); \
        __vunit_test_passed = 0; \
        __vunit_fail_count = __vunit_fail_count + 1; \
        __vunit_exit_code = 1; \
        if (`VUNIT_STOP_ON_FAILURE) begin \
            $display("!!! STOPPING ON FIRST FAILURE !!!"); \
            __vunit_write_exit_code(1); \
            $finish; \
        end \
    end

//------------------------------------------------------------------------------
// CHECK_FALSE - Assert that a condition is false
//
// Usage:
//   `CHECK_FALSE(condition)
//------------------------------------------------------------------------------
`define CHECK_FALSE(condition) \
    __vunit_check_count = __vunit_check_count + 1; \
    if (condition) begin \
        $display(""); \
        $display("FAIL: CHECK_FALSE at %s:%0d", `__FILE__, `__LINE__); \
        $display("  Test: %s", __vunit_current_test); \
        $display("  Condition was true"); \
        $display(""); \
        __vunit_test_passed = 0; \
        __vunit_fail_count = __vunit_fail_count + 1; \
        __vunit_exit_code = 1; \
        if (`VUNIT_STOP_ON_FAILURE) begin \
            $display("!!! STOPPING ON FIRST FAILURE !!!"); \
            __vunit_write_exit_code(1); \
            $finish; \
        end \
    end

//------------------------------------------------------------------------------
// WATCHDOG - Set a timeout for the simulation
//
// Usage:
//   `WATCHDOG(10000us)  // 10ms timeout
//
// If the watchdog triggers, it's considered a failure.
//------------------------------------------------------------------------------
`define WATCHDOG(timeout) \
    initial begin \
        #(timeout); \
        $display(""); \
        $display("!!! WATCHDOG TIMEOUT after %0t !!!", $time); \
        $display(""); \
        __vunit_fail_count = __vunit_fail_count + 1; \
        __vunit_exit_code = 1; \
        /* Print summary before exit */ \
        $display("=== TEST SUMMARY ==="); \
        $display("  Total checks: %0d", __vunit_check_count); \
        $display("  Failures: %0d (includes timeout)", __vunit_fail_count); \
        $display("  Result: FAILED (TIMEOUT)"); \
        $display("===================="); \
        $display(""); \
        __vunit_write_exit_code(1); \
        $finish; \
    end

//------------------------------------------------------------------------------
// Helper function to write exit code to file
//
// Since Icarus Verilog doesn't propagate $finish argument to shell,
// we write the exit code to a file that can be checked by the test runner.
//------------------------------------------------------------------------------
function automatic void __vunit_write_exit_code(input integer code);
    integer fd;
    fd = $fopen("vunit_exit_code.txt", "w");
    if (fd) begin
        $fdisplay(fd, "%0d", code);
        $fclose(fd);
    end
endfunction

//------------------------------------------------------------------------------
// Compatibility defines
//------------------------------------------------------------------------------

// File and line macros (Icarus Verilog supports these)
`ifndef __FILE__
`define __FILE__ "unknown"
`endif

`ifndef __LINE__
`define __LINE__ 0
`endif

`endif // VUNIT_DEFINES_SVH
