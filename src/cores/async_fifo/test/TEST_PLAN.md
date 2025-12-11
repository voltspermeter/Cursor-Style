# Async FIFO Test Plan

This document outlines important tests to add to the async_fifo testing suite for comprehensive verification coverage.

## Current Test Coverage

| Test | Status | Coverage Area |
|------|--------|---------------|
| clock_rates | ✅ Exists | Clock frequency ratios |
| write_past | ✅ Exists | Write-past-full (standard) |
| write_past_fwft | ✅ Exists | Write-past-full (FWFT) |
| write_past_flags | ✅ Exists | Write-past-full (flags) |
| asymm_concat | ✅ Exists | Width conversion (narrow→wide) |
| asymm_split | ✅ Exists | Width conversion (wide→narrow) |
| reset_sync | ✅ **NEW** | Reset synchronization across domains |
| ptr_wraparound | ✅ **NEW** | Pointer wraparound behavior |
| empty_timing | ✅ **NEW** | Empty flag timing verification |
| full_timing | ✅ **NEW** | Full flag timing verification |
| read_empty | ✅ **NEW** | Read-while-empty protection |

---

## Priority 1: Critical Functional Tests ✅ COMPLETED

### 1. Reset Synchronization Test ✅
**Directory:** `test/reset_sync/`  
**Target:** All modules  
**Priority:** Critical  
**Status:** ✅ **Implemented**

**Description:** Verify proper reset behavior across both clock domains.

**Test Scenarios:**
- [x] Assert reset while FIFO contains data - verify data is cleared
- [x] Assert reset during active write - verify pointer resets
- [x] Assert reset during active read - verify pointer resets
- [x] Verify reset release timing (8-cycle counter + sync delay)
- [x] Verify `rd_rst` and `wr_rst` synchronization
- [x] Multiple reset pulses in succession
- [x] Short reset pulse (< 8 cycles) behavior
- [x] Full flag during reset behavior
- [x] Functional operation after reset

**Key Signals to Monitor:**
```
rst, rst_sw, rst_sr, wr_rst, rd_rst, wr_rst_cnt, rd_rst_cnt, wr_ptr, rd_ptr
```

---

### 2. Pointer Wraparound Test ✅
**Directory:** `test/ptr_wraparound/`  
**Target:** `async_fifo`, `async_fifo_fwft`  
**Priority:** Critical  
**Status:** ✅ **Implemented**

**Description:** Verify correct operation when read/write pointers wrap around.

**Test Scenarios:**
- [x] Fill and empty FIFO multiple times to force wraparound
- [x] Verify data integrity across wraparound boundary
- [x] Test with small FIFO (ADDR_WIDTH=2, 4 entries) to quickly reach wraparound
- [x] Verify Gray code encoding at wraparound point
- [x] Verify full/empty detection when pointers wrap at different times
- [x] Continuous streaming across many pointer wraps

**Configuration:**
```systemverilog
.ADDR_WIDTH( 2 )  // 4 entries - fast wraparound
```

---

### 3. Empty Flag Timing Test ✅
**Directory:** `test/empty_timing/`  
**Target:** `async_fifo`, `async_fifo_fwft`  
**Priority:** Critical  
**Status:** ✅ **Implemented**

**Description:** Verify empty flag asserts/deasserts at correct times.

**Test Scenarios:**
- [x] Empty deasserts within expected cycles after first write
- [x] Empty asserts within expected cycles after last read
- [x] Empty behavior with single entry write/read
- [x] Empty flag during reset
- [x] `has_data` is always inverse of `empty`
- [x] Empty timing consistency across multiple trials

**Measurement:**
- Cycle count from `wr_en` to `empty` deassertion
- Cycle count from last `rd_en` to `empty` assertion

---

### 4. Full Flag Timing Test ✅
**Directory:** `test/full_timing/`  
**Target:** `async_fifo`, `async_fifo_flags`  
**Priority:** Critical  
**Status:** ✅ **Implemented**

**Description:** Verify full flag asserts/deasserts at correct times.

**Test Scenarios:**
- [x] Full asserts within expected cycles when FIFO fills
- [x] Full deasserts within expected cycles after read
- [x] Full behavior at exact capacity boundary
- [x] Full flag during reset (should be asserted)
- [x] Verify conservative full assertion (may assert early, never late)
- [x] Full flag transitions (fill/partial-drain cycles)

---

### 5. Read-While-Empty Protection Test ✅
**Directory:** `test/read_empty/`  
**Target:** `async_fifo`, `async_fifo_fwft`  
**Priority:** Critical  
**Status:** ✅ **Implemented**

**Description:** Verify FIFO handles read attempts when empty.

**Test Scenarios:**
- [x] Assert `rd_en` while `empty=1` - verify no pointer change
- [x] Assert `rd_en` while `has_data=0` - verify no corruption
- [x] Continuous `rd_en` assertion on empty FIFO
- [x] `rd_en` asserted as FIFO becomes empty (race condition)
- [x] Verify `rd_data` stability when reading empty FIFO
- [x] Read before any writes
- [x] Interleaved writes/reads with empty gaps

---

## Priority 2: Data Integrity Tests

### 6. Data Pattern Test
**Directory:** `test/data_patterns/`  
**Target:** All modules  
**Priority:** High

**Description:** Verify data integrity with various bit patterns.

**Test Patterns:**
- [ ] All zeros (0x00)
- [ ] All ones (0xFF)
- [ ] Alternating bits (0xAA, 0x55)
- [ ] Walking ones (0x01, 0x02, 0x04, ...)
- [ ] Walking zeros (0xFE, 0xFD, 0xFB, ...)
- [ ] Sequential count (0x00, 0x01, 0x02, ...)
- [ ] Pseudo-random (LFSR pattern)
- [ ] Maximum width patterns (for DATA_WIDTH > 8)

---

### 7. Back-to-Back Operations Test
**Directory:** `test/back_to_back/`  
**Target:** `async_fifo`, `async_fifo_fwft`  
**Priority:** High

**Description:** Verify continuous streaming operation.

**Test Scenarios:**
- [ ] Continuous writes until full, continuous reads until empty
- [ ] Simultaneous continuous read and write (steady state)
- [ ] Write burst, read burst, repeat
- [ ] Single-cycle gaps in read stream
- [ ] Single-cycle gaps in write stream

---

### 8. Simultaneous Read/Write Test
**Directory:** `test/simultaneous_rdwr/`  
**Target:** `async_fifo`, `async_fifo_fwft`  
**Priority:** High

**Description:** Verify operation when reading and writing simultaneously.

**Test Scenarios:**
- [ ] Read and write on same cycle (both clocks aligned)
- [ ] Read and write with phase offset
- [ ] Simultaneous read/write at near-full
- [ ] Simultaneous read/write at near-empty
- [ ] Throughput measurement at steady state

---

### 9. Single Entry Test
**Directory:** `test/single_entry/`  
**Target:** `async_fifo_fwft`  
**Priority:** High

**Description:** Verify operation with single entry in FIFO.

**Test Scenarios:**
- [ ] Write one entry, read one entry - repeat many times
- [ ] Verify latency for single entry (FWFT should be 0)
- [ ] Verify flags for single entry state
- [ ] Single entry with different clock ratios

---

## Priority 3: Boundary Condition Tests

### 10. Near-Full Threshold Test
**Directory:** `test/near_full/`  
**Target:** `async_fifo`, `async_fifo_flags`  
**Priority:** High

**Description:** Verify behavior near full condition.

**Test Scenarios:**
- [ ] Write to N-1 entries, verify not full
- [ ] Write to N entries, verify full
- [ ] Operate at N-1 entries for extended period
- [ ] Verify RESERVE parameter correctly triggers early full
- [ ] `prog_full` vs `full` timing (flags variant)

**Test Matrix:**
| RESERVE | Expected prog_full at |
|---------|----------------------|
| 0 | Same as full |
| 1 | 1 entry before full |
| 4 | 4 entries before full |
| DEPTH/2 | Half full |

---

### 11. Near-Empty Threshold Test
**Directory:** `test/near_empty/`  
**Target:** `async_fifo`, `async_fifo_fwft`  
**Priority:** High

**Description:** Verify behavior near empty condition.

**Test Scenarios:**
- [ ] Read to 1 entry remaining, verify not empty
- [ ] Read last entry, verify empty
- [ ] Operate at 1 entry for extended period
- [ ] `has_data` vs `empty` consistency

---

### 12. Depth Variation Test
**Directory:** `test/depth_variation/`  
**Target:** `async_fifo`  
**Priority:** Medium

**Description:** Verify operation across different FIFO depths.

**Test Configurations:**
- [ ] ADDR_WIDTH=2 (4 entries) - minimum practical
- [ ] ADDR_WIDTH=4 (16 entries) - small
- [ ] ADDR_WIDTH=8 (256 entries) - medium
- [ ] ADDR_WIDTH=10 (1024 entries) - large
- [ ] Verify RAM_STYLE switches at ADDR_WIDTH=6 boundary

---

### 13. Width Variation Test
**Directory:** `test/width_variation/`  
**Target:** `async_fifo`  
**Priority:** Medium

**Description:** Verify operation across different data widths.

**Test Configurations:**
- [ ] DATA_WIDTH=1 (single bit)
- [ ] DATA_WIDTH=8 (byte)
- [ ] DATA_WIDTH=32 (word)
- [ ] DATA_WIDTH=64 (double word)
- [ ] DATA_WIDTH=128 (quad word)

---

## Priority 4: Stress Tests

### 14. Random Traffic Test
**Directory:** `test/random_traffic/`  
**Target:** All modules  
**Priority:** High

**Description:** Long-running test with randomized operations.

**Test Parameters:**
- [ ] Random write enable (with probability P_write)
- [ ] Random read enable (with probability P_read)
- [ ] Random data patterns
- [ ] Run for 100,000+ transactions
- [ ] Verify zero data errors

**Configurations to Test:**
| P_write | P_read | Expected Behavior |
|---------|--------|-------------------|
| 0.8 | 0.5 | FIFO tends toward full |
| 0.5 | 0.8 | FIFO tends toward empty |
| 0.5 | 0.5 | FIFO oscillates |
| 1.0 | 1.0 | Maximum throughput |

---

### 15. Clock Jitter Test
**Directory:** `test/clock_jitter/`  
**Target:** `async_fifo_fwft`  
**Priority:** Medium

**Description:** Verify operation with clock period variation (jitter).

**Test Scenarios:**
- [ ] ±5% period jitter on write clock
- [ ] ±5% period jitter on read clock
- [ ] Jitter on both clocks simultaneously
- [ ] Verify no data corruption with jitter

---

### 16. Rapid Clock Switching Test
**Directory:** `test/clock_switching/`  
**Target:** `async_fifo_fwft`  
**Priority:** Medium

**Description:** Verify operation when clock frequency changes abruptly.

**Test Scenarios:**
- [ ] Instantaneous frequency change mid-transfer
- [ ] Frequency change while FIFO is full
- [ ] Frequency change while FIFO is empty
- [ ] Clock stopping and restarting

---

## Priority 5: Flag Variant Tests

### 17. Programmable Full Accuracy Test
**Directory:** `test/prog_full_accuracy/`  
**Target:** `async_fifo_flags`, `async_fifo_flags_fwft`  
**Priority:** High

**Description:** Verify `prog_full` asserts at correct threshold.

**Test Matrix:**
| DEPTH | RESERVE | Expected prog_full occupancy |
|-------|---------|------------------------------|
| 16 | 0 | 16 (same as full) |
| 16 | 4 | 12 |
| 16 | 8 | 8 |
| 256 | 32 | 224 |

**Test Scenarios:**
- [ ] Fill to exactly RESERVE entries below full
- [ ] Verify `prog_full=0`, `full=0`
- [ ] Write one more entry
- [ ] Verify `prog_full=1`, `full=0`
- [ ] Continue to full, verify `full=1`

---

### 18. Flag Consistency Test
**Directory:** `test/flag_consistency/`  
**Target:** `async_fifo_flags`  
**Priority:** Medium

**Description:** Verify flag relationships are always consistent.

**Invariants to Verify:**
- [ ] `full=1` implies `prog_full=1` (always)
- [ ] `prog_full=0` implies `full=0` (always)
- [ ] `empty=1` implies `has_data=0` (always)
- [ ] `has_data=1` implies `empty=0` (always)
- [ ] Never `full=1` and `empty=1` simultaneously (except during reset)

---

## Priority 6: Asymmetric Width Tests

### 19. Asymmetric Boundary Test
**Directory:** `test/asymm_boundary/`  
**Target:** `async_fifo_asymm_concat_fwft`, `async_fifo_asymm_split_fwft`  
**Priority:** High

**Description:** Verify asymmetric FIFOs at width ratio boundaries.

**Test Scenarios (Concat - narrow write, wide read):**
- [ ] Write exactly WIDTH_RATIO entries, verify one read available
- [ ] Partial fill (< WIDTH_RATIO writes), verify no read available
- [ ] Verify byte ordering in concatenated output

**Test Scenarios (Split - wide write, narrow read):**
- [ ] Write one entry, verify WIDTH_RATIO reads available
- [ ] Verify byte ordering in split output
- [ ] Read partial (< WIDTH_RATIO), write another, continue reading

---

### 20. Asymmetric Ratio Variation Test
**Directory:** `test/asymm_ratios/`  
**Target:** `async_fifo_asymm_concat_fwft`, `async_fifo_asymm_split_fwft`  
**Priority:** Medium

**Test Configurations:**
| WIDTH_RATIO_LOG2 | Ratio | Write Width | Read Width |
|------------------|-------|-------------|------------|
| 1 | 2:1 | 8-bit | 16-bit (concat) |
| 2 | 4:1 | 8-bit | 32-bit (concat) |
| 3 | 8:1 | 8-bit | 64-bit (concat) |
| 1 | 2:1 | 16-bit | 8-bit (split) |
| 2 | 4:1 | 32-bit | 8-bit (split) |
| 3 | 8:1 | 64-bit | 8-bit (split) |

---

## Test Implementation Priority

### Phase 1 (Critical)
1. Reset Synchronization Test
2. Pointer Wraparound Test
3. Empty Flag Timing Test
4. Full Flag Timing Test
5. Read-While-Empty Protection Test

### Phase 2 (High Priority)
6. Data Pattern Test
7. Back-to-Back Operations Test
8. Simultaneous Read/Write Test
9. Single Entry Test
10. Near-Full Threshold Test
11. Near-Empty Threshold Test
12. Random Traffic Test
13. Programmable Full Accuracy Test

### Phase 3 (Medium Priority)
14. Depth Variation Test
15. Width Variation Test
16. Clock Jitter Test
17. Rapid Clock Switching Test
18. Flag Consistency Test
19. Asymmetric Boundary Test
20. Asymmetric Ratio Variation Test

---

## Test Metrics

### Coverage Goals

| Metric | Target |
|--------|--------|
| Line coverage | > 95% |
| Branch coverage | > 90% |
| FSM state coverage | 100% |
| Parameter combinations | All documented values |
| Clock ratio combinations | At least 10 ratios |

### Performance Benchmarks

| Test | Minimum Transactions |
|------|---------------------|
| Data integrity | 10,000 |
| Random traffic | 100,000 |
| Stress tests | 1,000,000 |

---

## Appendix: Test Template

```systemverilog
`timescale 1ps/1ps
`include "vunit_defines.svh"

module async_fifo_<testname>_tb;

  // Parameters
  localparam DATA_WIDTH = 8;
  localparam ADDR_WIDTH = 4;
  localparam RESERVE = 0;

  // Signals
  logic rst, wr_clk = 1'b0, rd_clk = 1'b0;
  logic wr_en, rd_en;
  logic [DATA_WIDTH-1:0] wr_data;
  wire [DATA_WIDTH-1:0] rd_data;
  wire full, empty, has_data;

  // Verification
  logic [DATA_WIDTH-1:0] data_queue[$];
  integer error_count = 0;

  // Clock generation
  always #10000 wr_clk <= !wr_clk;
  always #10000 rd_clk <= !rd_clk;

  // DUT
  async_fifo #(
        .DATA_WIDTH(DATA_WIDTH)
      , .ADDR_WIDTH(ADDR_WIDTH)
      , .RESERVE(RESERVE)
  ) DUT (
        .rst(rst)
      , .wr_clk(wr_clk)
      , .wr_en(wr_en)
      , .wr_data(wr_data)
      , .full(full)
      , .rd_clk(rd_clk)
      , .rd_en(rd_en)
      , .rd_data(rd_data)
      , .empty(empty)
      , .has_data(has_data)
  );

  `TEST_SUITE begin
    `TEST_CASE("<test-case-name>") begin
      $dumpfile("test_case_1.vcd");
      $dumpvars();

      // Initialize
      rst <= 1'b1;
      wr_en <= 1'b0;
      rd_en <= 1'b0;
      wr_data <= '0;

      repeat(20) @(posedge wr_clk);
      rst <= 1'b0;
      repeat(20) @(posedge wr_clk);

      // Test stimulus here
      // ...

      // Final check
      `CHECK_EQUAL(error_count, 0);
    end
  end

  `WATCHDOG(10000us);

endmodule
```

---

## CMakeLists.txt Template

```cmake
add_vunit_test( async_fifo_<testname>_tb.sv
  DEPENDS async_fifo
  VCDS
    test_case_1
  VIEW_SIGNALS
    DUT.rst
    DUT.wr_clk
    DUT.wr_en
    DUT.wr_data
    DUT.full
    DUT.rd_clk
    DUT.rd_en
    DUT.rd_data
    DUT.empty
    DUT.has_data
    DUT.wr_ptr
    DUT.rd_ptr
)
```
