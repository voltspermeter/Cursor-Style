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
// Test Status Tracking
//------------------------------------------------------------------------------
integer __vunit_test_passed = 1;
integer __vunit_check_count = 0;
integer __vunit_fail_count = 0;
string  __vunit_current_test = "";

//------------------------------------------------------------------------------
// TEST_SUITE - Defines a test suite
//
// Usage:
//   `TEST_SUITE begin
//     `TEST_CASE("test1") begin ... end
//     `TEST_CASE("test2") begin ... end
//   end
//------------------------------------------------------------------------------
`define TEST_SUITE \
    initial

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
    __vunit_check_count = 0; \
    $display(""); \
    $display("=== TEST CASE: %s ===", name); \
    $display("");

//------------------------------------------------------------------------------
// CHECK_EQUAL - Assert that two values are equal
//
// Usage:
//   `CHECK_EQUAL(expected, actual)
//------------------------------------------------------------------------------
`define CHECK_EQUAL(expected, actual) \
    __vunit_check_count = __vunit_check_count + 1; \
    if ((expected) !== (actual)) begin \
        $display("FAIL: CHECK_EQUAL at %s:%0d", `__FILE__, `__LINE__); \
        $display("  Expected: %0d (0x%0h)", expected, expected); \
        $display("  Actual:   %0d (0x%0h)", actual, actual); \
        __vunit_test_passed = 0; \
        __vunit_fail_count = __vunit_fail_count + 1; \
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
        $display("FAIL: CHECK_TRUE at %s:%0d", `__FILE__, `__LINE__); \
        $display("  Condition was false"); \
        __vunit_test_passed = 0; \
        __vunit_fail_count = __vunit_fail_count + 1; \
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
        $display("FAIL: CHECK_FALSE at %s:%0d", `__FILE__, `__LINE__); \
        $display("  Condition was true"); \
        __vunit_test_passed = 0; \
        __vunit_fail_count = __vunit_fail_count + 1; \
    end

//------------------------------------------------------------------------------
// WATCHDOG - Set a timeout for the simulation
//
// Usage:
//   `WATCHDOG(10000us)  // 10ms timeout
//------------------------------------------------------------------------------
`define WATCHDOG(timeout) \
    initial begin \
        #(timeout); \
        $display(""); \
        $display("!!! WATCHDOG TIMEOUT after %0t !!!", $time); \
        $display(""); \
        __vunit_test_passed = 0; \
        __vunit_fail_count = __vunit_fail_count + 1; \
        #100; \
        $finish(1); \
    end

//------------------------------------------------------------------------------
// TEST_COMPLETE - End of test reporting (call at end of test suite)
//------------------------------------------------------------------------------
`define TEST_COMPLETE \
    $display(""); \
    $display("=== TEST SUMMARY ==="); \
    $display("  Checks: %0d", __vunit_check_count); \
    $display("  Failures: %0d", __vunit_fail_count); \
    if (__vunit_fail_count == 0) begin \
        $display("  Result: PASSED"); \
    end else begin \
        $display("  Result: FAILED"); \
    end \
    $display("===================="); \
    $display(""); \
    $finish(__vunit_fail_count > 0 ? 1 : 0);

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
