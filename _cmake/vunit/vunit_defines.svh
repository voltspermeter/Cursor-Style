//------------------------------------------------------------------------------
//
// vunit_defines.svh - VUnit compatibility macros for Icarus Verilog
//
// This file provides VUnit-compatible macros that work with Icarus Verilog
// in standalone mode (without the VUnit Python runner).
//
// Features:
//   - CHECK_EQUAL, CHECK_TRUE, CHECK_FALSE assertions
//   - TEST_SUITE / TEST_CASE structure
//   - WATCHDOG timeout protection
//   - Exit code file for CMake integration
//   - Automatic test completion and summary
//
//------------------------------------------------------------------------------

`ifndef VUNIT_DEFINES_SVH
`define VUNIT_DEFINES_SVH

//------------------------------------------------------------------------------
// Global test state variables
// These must be declared at module scope before TEST_SUITE
//------------------------------------------------------------------------------

integer __vunit_check_count = 0;
integer __vunit_fail_count = 0;
integer __vunit_test_done = 0;
string  __vunit_current_test = "";

//------------------------------------------------------------------------------
// Exit code file writer
// Writes test result to file for CMake to check
//------------------------------------------------------------------------------

task automatic __vunit_write_result(input integer failed);
    integer fd;
    fd = $fopen("vunit_exit_code.txt", "w");
    if (fd) begin
        $fdisplay(fd, "%0d", failed ? 1 : 0);
        $fclose(fd);
    end
endtask

//------------------------------------------------------------------------------
// Test summary printer
//------------------------------------------------------------------------------

task automatic __vunit_print_summary();
    $display("");
    $display("============================================================");
    $display("                     TEST SUMMARY");
    $display("============================================================");
    $display("  Total Checks : %0d", __vunit_check_count);
    $display("  Failures     : %0d", __vunit_fail_count);
    $display("------------------------------------------------------------");
    if (__vunit_fail_count == 0) begin
        $display("  RESULT: *** PASSED ***");
    end else begin
        $display("  RESULT: *** FAILED ***");
    end
    $display("============================================================");
    $display("");
endtask

//------------------------------------------------------------------------------
// TEST_SUITE - Defines a test suite
//
// Usage:
//   `TEST_SUITE begin
//     `TEST_CASE("test1") begin ... end
//   end
//
// The closing 'end' will trigger test completion.
//------------------------------------------------------------------------------

`define TEST_SUITE \
    initial

//------------------------------------------------------------------------------
// TEST_CASE - Defines a test case
//
// Usage:
//   `TEST_CASE("Test Name") begin
//     // test code
//   end
//------------------------------------------------------------------------------

`define TEST_CASE(test_name) \
    __vunit_current_test = test_name; \
    $display(""); \
    $display("============================================================"); \
    $display("  TEST CASE: %s", test_name); \
    $display("============================================================"); \
    $display("");

//------------------------------------------------------------------------------
// CHECK_EQUAL - Assert equality
//
// Usage:
//   `CHECK_EQUAL(expected, actual)
//------------------------------------------------------------------------------

`define CHECK_EQUAL(expected, actual) \
    begin \
        __vunit_check_count = __vunit_check_count + 1; \
        if ((expected) !== (actual)) begin \
            $display(""); \
            $display("*** ASSERTION FAILED ***"); \
            $display("  CHECK_EQUAL at %s:%0d", `__FILE__, `__LINE__); \
            $display("  Test: %s", __vunit_current_test); \
            $display("  Expected: %0d (0x%0h)", (expected), (expected)); \
            $display("  Actual:   %0d (0x%0h)", (actual), (actual)); \
            $display(""); \
            __vunit_fail_count = __vunit_fail_count + 1; \
        end \
    end

//------------------------------------------------------------------------------
// CHECK_TRUE - Assert condition is true
//------------------------------------------------------------------------------

`define CHECK_TRUE(condition) \
    begin \
        __vunit_check_count = __vunit_check_count + 1; \
        if (!(condition)) begin \
            $display(""); \
            $display("*** ASSERTION FAILED ***"); \
            $display("  CHECK_TRUE at %s:%0d", `__FILE__, `__LINE__); \
            $display("  Test: %s", __vunit_current_test); \
            $display("  Condition was FALSE"); \
            $display(""); \
            __vunit_fail_count = __vunit_fail_count + 1; \
        end \
    end

//------------------------------------------------------------------------------
// CHECK_FALSE - Assert condition is false
//------------------------------------------------------------------------------

`define CHECK_FALSE(condition) \
    begin \
        __vunit_check_count = __vunit_check_count + 1; \
        if (condition) begin \
            $display(""); \
            $display("*** ASSERTION FAILED ***"); \
            $display("  CHECK_FALSE at %s:%0d", `__FILE__, `__LINE__); \
            $display("  Test: %s", __vunit_current_test); \
            $display("  Condition was TRUE"); \
            $display(""); \
            __vunit_fail_count = __vunit_fail_count + 1; \
        end \
    end

//------------------------------------------------------------------------------
// WATCHDOG - Timeout protection
//
// Usage:
//   `WATCHDOG(10000us)
//
// The watchdog monitors the __vunit_test_done flag and terminates
// the simulation with proper cleanup if the test completes or times out.
//------------------------------------------------------------------------------

`define WATCHDOG(timeout) \
    initial begin : __vunit_watchdog_block \
        fork \
            begin : timeout_thread \
                #(timeout); \
                if (!__vunit_test_done) begin \
                    $display(""); \
                    $display("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"); \
                    $display("  WATCHDOG TIMEOUT after %0t", $time); \
                    $display("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"); \
                    __vunit_fail_count = __vunit_fail_count + 1; \
                    __vunit_print_summary(); \
                    __vunit_write_result(1); \
                    $finish; \
                end \
            end \
            begin : completion_thread \
                wait(__vunit_test_done == 1); \
                disable timeout_thread; \
                __vunit_print_summary(); \
                __vunit_write_result(__vunit_fail_count > 0); \
                $finish; \
            end \
        join \
    end

//------------------------------------------------------------------------------
// TEST_DONE - Mark test as complete (call at end of TEST_SUITE)
//
// This triggers the watchdog's completion thread to finish gracefully.
//------------------------------------------------------------------------------

`define TEST_DONE \
    __vunit_test_done = 1

//------------------------------------------------------------------------------
// Compatibility: File/line macros
//------------------------------------------------------------------------------

`ifndef __FILE__
`define __FILE__ "unknown"
`endif

`ifndef __LINE__
`define __LINE__ 0
`endif

`endif // VUNIT_DEFINES_SVH
