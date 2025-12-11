# Bug Report: CMake Infrastructure and Testbench Issues

This document reports bugs found during testing of the CMake infrastructure with Icarus Verilog.

---

## Summary

| ID | Severity | Component | Description |
|----|----------|-----------|-------------|
| BUG-001 | High | VUnit Macros | `$finish(1)` exit code not propagated to shell |
| BUG-002 | High | VUnit Macros | `CHECK_EQUAL` failures don't stop test execution |
| BUG-003 | Medium | VUnit Macros | Tests don't auto-terminate after TEST_SUITE completes |
| BUG-004 | Medium | Test Config | Missing test directories referenced in CMakeLists.txt |
| BUG-005 | Low | VUnit Macros | No test summary printed at end of test |
| BUG-006 | Low | VCD Output | VCD warning about $unit package |

---

## BUG-001: Exit Code Not Propagated

**Severity:** High  
**Component:** `_cmake/vunit/vunit_defines.svh`  
**Affected:** All tests

### Description

When `$finish(1)` is called (indicating failure), Icarus Verilog's `vvp` returns exit code 0 to the shell. This causes CTest to report passing tests even when failures occur.

### Evidence

```
!!! WATCHDOG TIMEOUT after 10000000000 !!!
/workspace/.../async_fifo_writepast_tb.sv:159: $finish(1) called at 10000000100 (1ps)
Exit code: 0
```

### Expected Behavior

`$finish(1)` should cause vvp to return exit code 1, causing CTest to mark the test as failed.

### Root Cause

Icarus Verilog does not propagate the `$finish` argument as the process exit code. This is a known limitation of iverilog/vvp.

### Suggested Fix

Use `$fatal` or a custom PLI/VPI function to set the exit code, or use a post-processing script to parse output for "FAIL" strings.

---

## BUG-002: CHECK_EQUAL Failures Don't Stop Execution

**Severity:** High  
**Component:** `_cmake/vunit/vunit_defines.svh`  
**Affected:** All tests using `CHECK_EQUAL`

### Description

When `CHECK_EQUAL` detects a mismatch, it prints a failure message but allows test execution to continue. This can mask the root cause of failures and cause misleading test results.

### Evidence

```systemverilog
`CHECK_EQUAL(8'd10, 8'd20);  // This fails
$display("After failed check");  // This still executes
```

Output:
```
FAIL: CHECK_EQUAL at test_vunit_macros.sv:9
  Expected: 10 (0xa)
  Actual:   20 (0x14)
After failed check (should not reach here cleanly)
```

### Expected Behavior

Test execution should optionally stop on first failure, or at minimum the final exit code should reflect the failure.

### Suggested Fix

Add an option to stop on first failure:
```systemverilog
`ifdef STOP_ON_FAILURE
    $finish(1);
`endif
```

---

## BUG-003: Tests Don't Auto-Terminate

**Severity:** Medium  
**Component:** `_cmake/vunit/vunit_defines.svh`  
**Affected:** All tests

### Description

Tests complete their stimulus but don't call `$finish`. They rely entirely on the `WATCHDOG` macro to terminate the simulation. This means all tests appear to "timeout" even when they pass.

### Evidence

All three tests show:
```
!!! WATCHDOG TIMEOUT after 10000000000 !!!
```

Even though all data checks passed (all "MATCH" messages).

### Expected Behavior

The `TEST_SUITE` macro should call `$finish(0)` after all test cases complete successfully.

### Suggested Fix

Modify `TEST_SUITE` to add automatic termination:
```systemverilog
`define TEST_SUITE \
    initial begin \
        // test cases here \
        // ... \
        $display("All tests completed"); \
        $finish(0); \
    end
```

Or add a `TEST_COMPLETE` macro that users must call.

---

## BUG-004: Missing Test Directories

**Severity:** Medium  
**Component:** `src/cores/async_fifo/test/CMakeLists.txt`  
**Affected:** Build system

### Description

The test CMakeLists.txt references directories that don't exist:

```cmake
add_subdirectory(write_past_flags)   # Does not exist
add_subdirectory(asymm_concat)       # Does not exist
add_subdirectory(asymm_split)        # Does not exist
```

### Evidence

```bash
$ ls src/cores/async_fifo/test/
clock_rates/  CMakeLists.txt  TESTBENCH.md  TEST_PLAN.md  write_past/  write_past_fwft/
```

### Impact

If the full test/CMakeLists.txt were included (via add_subdirectory), CMake would fail with:
```
CMake Error: The source directory does not exist
```

Currently avoided because top-level CMakeLists.txt includes test directories individually.

### Suggested Fix

Either:
1. Create the missing test directories with placeholder CMakeLists.txt
2. Remove the non-existent subdirectory references from test/CMakeLists.txt
3. Add conditional checks in CMakeLists.txt

---

## BUG-005: No Test Summary Printed

**Severity:** Low  
**Component:** `_cmake/vunit/vunit_defines.svh`  
**Affected:** Test output readability

### Description

The `TEST_COMPLETE` macro exists in vunit_defines.svh but is never called by tests. As a result, no summary of passed/failed checks is printed at the end.

### Expected Behavior

At end of test:
```
=== TEST SUMMARY ===
  Checks: 2000
  Failures: 0
  Result: PASSED
====================
```

### Suggested Fix

Either:
1. Require tests to call `TEST_COMPLETE`
2. Automatically call summary in `TEST_SUITE` end
3. Document the need to call `TEST_COMPLETE`

---

## BUG-006: VCD Warning About $unit Package

**Severity:** Low  
**Component:** Icarus Verilog / Testbenches  
**Affected:** VCD output

### Description

Every test produces a warning during VCD generation:

```
VCD warning: $dumpvars: Package ($unit) is not dumpable with VCD.
```

### Impact

Warning is cosmetic only. VCD files are generated correctly and contain all expected signals.

### Root Cause

SystemVerilog's `$unit` compilation unit scope cannot be dumped to VCD format. This is a limitation of the VCD format / Icarus Verilog.

### Suggested Fix

Suppress warning or ignore (no functional impact).

---

## Test Results Summary

Despite the bugs above, the core functionality works:

| Test | Compilation | Data Integrity | Exit Code | Overall |
|------|-------------|----------------|-----------|---------|
| async_fifo_clkrates_tb | ✅ Pass | ✅ All MATCH | ⚠️ 0 (watchdog) | Functional |
| async_fifo_writepast_tb | ✅ Pass | ✅ All MATCH | ⚠️ 0 (watchdog) | Functional |
| async_fifo_fwft_writepast_tb | ✅ Pass | ✅ All MATCH | ⚠️ 0 (watchdog) | Functional |

**Key Observations:**
- All HDL modules compile without errors
- All data integrity checks pass (FIFO behavior correct)
- All tests produce valid VCD waveforms
- Dependency tracking works correctly
- CTest integration works (but reports false positives due to BUG-001)

---

## Recommendations

### Priority 1 (Must Fix)
1. **BUG-001/002**: Implement proper exit code handling or output parsing
2. **BUG-003**: Add auto-termination to TEST_SUITE

### Priority 2 (Should Fix)
3. **BUG-004**: Sync test/CMakeLists.txt with actual directory structure
4. **BUG-005**: Add test summary output

### Priority 3 (Nice to Have)
5. **BUG-006**: Document or suppress VCD warning

---

## Environment

- **OS:** Ubuntu (linux 6.1.147)
- **CMake:** 3.16+
- **Icarus Verilog:** 12.0-2build2
- **iverilog location:** /usr/bin/iverilog
- **vvp location:** /usr/bin/vvp
