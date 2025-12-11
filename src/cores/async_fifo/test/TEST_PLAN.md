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
| reset_sync | ✅ Priority 1 | Reset synchronization across domains |
| ptr_wraparound | ✅ Priority 1 | Pointer wraparound behavior |
| empty_timing | ✅ Priority 1 | Empty flag timing verification |
| full_timing | ✅ Priority 1 | Full flag timing verification |
| read_empty | ✅ Priority 1 | Read-while-empty protection |
| data_patterns | ✅ Priority 2 | Data integrity with various patterns |
| back_to_back | ✅ Priority 2 | Continuous streaming operations |
| simultaneous_rdwr | ✅ Priority 2 | Simultaneous read/write |
| single_entry | ✅ Priority 2 | Single entry FWFT operations |
| near_full | ✅ Priority 3 | Near-full threshold behavior |
| near_empty | ✅ Priority 3 | Near-empty threshold behavior |
| depth_variation | ✅ Priority 3 | Multiple FIFO depth configurations |
| width_variation | ✅ Priority 3 | Multiple data width configurations |
| random_traffic | ✅ Priority 4 | Long-running random operations |
| clock_jitter | ✅ Priority 4 | Clock period variation stress |
| clock_switching | ✅ Priority 4 | Frequency change stress |
| prog_full_accuracy | ✅ Priority 5 | Programmable full threshold |
| flag_consistency | ✅ Priority 5 | Flag relationship invariants |
| asymm_boundary | ✅ Priority 6 | Asymmetric FIFO boundary tests |
| asymm_ratios | ✅ Priority 6 | Asymmetric width ratio variations |

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

## Priority 2: Data Integrity Tests ✅ COMPLETED

### 6. Data Pattern Test ✅
**Directory:** `test/data_patterns/`  
**Target:** All modules  
**Priority:** High  
**Status:** ✅ **Implemented**

**Description:** Verify data integrity with various bit patterns.

**Test Patterns:**
- [x] All zeros (0x00)
- [x] All ones (0xFF)
- [x] Alternating bits (0xAA, 0x55)
- [x] Walking ones (0x01, 0x02, 0x04, ...)
- [x] Walking zeros (0xFE, 0xFD, 0xFB, ...)
- [x] Sequential count (0x00, 0x01, 0x02, ...)
- [x] Pseudo-random (LFSR pattern)
- [x] Boundary patterns

---

### 7. Back-to-Back Operations Test ✅
**Directory:** `test/back_to_back/`  
**Target:** `async_fifo`, `async_fifo_fwft`  
**Priority:** High  
**Status:** ✅ **Implemented**

**Description:** Verify continuous streaming operation.

**Test Scenarios:**
- [x] Continuous writes until full, continuous reads until empty
- [x] Simultaneous continuous read and write (steady state)
- [x] Write burst, read burst, repeat
- [x] Single-cycle gaps in read stream
- [x] Single-cycle gaps in write stream
- [x] Maximum throughput measurement

---

### 8. Simultaneous Read/Write Test ✅
**Directory:** `test/simultaneous_rdwr/`  
**Target:** `async_fifo`, `async_fifo_fwft`  
**Priority:** High  
**Status:** ✅ **Implemented**

**Description:** Verify operation when reading and writing simultaneously.

**Test Scenarios:**
- [x] Read and write on same cycle (aligned clocks)
- [x] Simultaneous read/write at near-full
- [x] Simultaneous read/write at near-empty
- [x] Continuous simultaneous stress test
- [x] Alternating single operations

---

### 9. Single Entry Test ✅
**Directory:** `test/single_entry/`  
**Target:** `async_fifo_fwft`  
**Priority:** High  
**Status:** ✅ **Implemented**

**Description:** Verify operation with single entry in FIFO.

**Test Scenarios:**
- [x] Write one entry, read one entry - repeat many times
- [x] Verify FWFT latency measurement
- [x] Verify flags for single entry state
- [x] Rapid single entry operations
- [x] Single entry data integrity

---

## Priority 3: Boundary Condition Tests ✅ COMPLETED

### 10. Near-Full Threshold Test ✅
**Directory:** `test/near_full/`  
**Target:** `async_fifo`, `async_fifo_flags`  
**Priority:** High  
**Status:** ✅ **Implemented**

**Description:** Verify behavior near full condition.

**Test Scenarios:**
- [x] Write to N-1 entries, verify not full
- [x] Write to N entries, verify full
- [x] Operate at N-1 entries for extended period
- [x] Verify RESERVE parameter correctly triggers early full
- [x] Full flag boundary timing
- [x] Data integrity at near-full

**Test Matrix:**
| RESERVE | Expected prog_full at |
|---------|----------------------|
| 0 | Same as full |
| 1 | 1 entry before full |
| 4 | 4 entries before full |
| DEPTH/2 | Half full |

---

### 11. Near-Empty Threshold Test ✅
**Directory:** `test/near_empty/`  
**Target:** `async_fifo`, `async_fifo_fwft`  
**Priority:** High  
**Status:** ✅ **Implemented**

**Description:** Verify behavior near empty condition.

**Test Scenarios:**
- [x] Read to 1 entry remaining, verify not empty
- [x] Read last entry, verify empty
- [x] Operate at 1 entry for extended period
- [x] `has_data` vs `empty` consistency
- [x] Empty flag boundary timing
- [x] Data integrity at near-empty

---

### 12. Depth Variation Test ✅
**Directory:** `test/depth_variation/`  
**Target:** `async_fifo`  
**Priority:** Medium  
**Status:** ✅ **Implemented**

**Description:** Verify operation across different FIFO depths.

**Test Configurations:**
- [x] ADDR_WIDTH=2 (4 entries) - minimum practical
- [x] ADDR_WIDTH=4 (16 entries) - small
- [x] ADDR_WIDTH=6 (64 entries) - medium (RAM_STYLE boundary)
- [x] Streaming test at minimum depth
- [x] All depths concurrent operation

---

### 13. Width Variation Test ✅
**Directory:** `test/width_variation/`  
**Target:** `async_fifo`  
**Priority:** Medium  
**Status:** ✅ **Implemented**

**Description:** Verify operation across different data widths.

**Test Configurations:**
- [x] DATA_WIDTH=1 (single bit)
- [x] DATA_WIDTH=8 (byte)
- [x] DATA_WIDTH=32 (word)
- [x] DATA_WIDTH=64 (double word)
- [x] All widths concurrent operation
- [x] Full bit utilization (all 1s/0s/alternating)

---

## Priority 4: Stress Tests ✅ COMPLETED

### 14. Random Traffic Test ✅
**Directory:** `test/random_traffic/`  
**Target:** All modules  
**Priority:** High  
**Status:** ✅ **Implemented**

**Description:** Long-running test with randomized operations.

**Test Parameters:**
- [x] Random write enable (with probability P_write)
- [x] Random read enable (with probability P_read)
- [x] Random data patterns (LFSR-based)
- [x] 5000 transactions per configuration
- [x] Verify zero data errors

**Configurations Tested:**
| P_write | P_read | Expected Behavior |
|---------|--------|-------------------|
| 0.5 | 0.5 | Balanced oscillation |
| 0.8 | 0.5 | FIFO tends toward full |
| 0.5 | 0.8 | FIFO tends toward empty |
| 1.0 | 1.0 | Maximum throughput |

---

### 15. Clock Jitter Test ✅
**Directory:** `test/clock_jitter/`  
**Target:** `async_fifo`  
**Priority:** Medium  
**Status:** ✅ **Implemented**

**Description:** Verify operation with clock period variation (jitter).

**Test Scenarios:**
- [x] ±5% period jitter on write clock
- [x] ±5% period jitter on read clock
- [x] Jitter on both clocks simultaneously
- [x] Verify no data corruption with jitter
- [x] Jitter during full/empty transitions

---

### 16. Clock Switching Test ✅
**Directory:** `test/clock_switching/`  
**Target:** `async_fifo`  
**Priority:** Medium  
**Status:** ✅ **Implemented**

**Description:** Verify operation when clock frequency changes abruptly.

**Test Scenarios:**
- [x] Instantaneous frequency change mid-transfer
- [x] Frequency change while FIFO is full
- [x] Frequency change while FIFO is empty
- [x] Write clock stopping and restarting
- [x] Read clock stopping and restarting

---

## Priority 5: Flag Variant Tests ✅ COMPLETED

### 17. Programmable Full Accuracy Test ✅
**Directory:** `test/prog_full_accuracy/`  
**Target:** `async_fifo_flags`, `async_fifo_flags_fwft`  
**Priority:** High  
**Status:** ✅ **Implemented**

**Description:** Verify `prog_full` asserts at correct threshold.

**Test Matrix:**
| DEPTH | RESERVE | Expected prog_full occupancy |
|-------|---------|------------------------------|
| 16 | 0 | 16 (same as full) |
| 16 | 4 | 12 |
| 16 | 8 | 8 |

**Test Scenarios:**
- [x] Fill to exactly RESERVE entries below full
- [x] Verify `prog_full=0`, `full=0`
- [x] Write one more entry
- [x] Verify `prog_full=1`, `full=0`
- [x] Continue to full, verify `full=1`
- [x] prog_full deasserts on read
- [x] full implies prog_full relationship

---

### 18. Flag Consistency Test ✅
**Directory:** `test/flag_consistency/`  
**Target:** `async_fifo_flags`  
**Priority:** Medium  
**Status:** ✅ **Implemented**

**Description:** Verify flag relationships are always consistent.

**Invariants Verified:**
- [x] `full=1` implies `prog_full=1` (always)
- [x] `prog_full=0` implies `full=0` (always)
- [x] `empty=1` implies `has_data=0` (always)
- [x] `has_data=1` implies `empty=0` (always)
- [x] Never `full=1` and `empty=1` simultaneously (except during reset)
- [x] Continuous monitoring during fill/empty cycles
- [x] Random operation monitoring
- [x] Boundary transition monitoring
- [x] Reset transition monitoring

---

## Priority 6: Asymmetric Width Tests ✅ COMPLETED

### 19. Asymmetric Boundary Test ✅
**Directory:** `test/asymm_boundary/`  
**Target:** `async_fifo_asymm_concat_fwft`, `async_fifo_asymm_split_fwft`  
**Priority:** High  
**Status:** ✅ **Implemented**

**Description:** Verify asymmetric FIFOs at width ratio boundaries.

**Test Scenarios (Concat - narrow write, wide read):**
- [x] Write exactly WIDTH_RATIO entries, verify one read available
- [x] Partial fill (< WIDTH_RATIO writes), verify no read available
- [x] Verify byte ordering in concatenated output
- [x] Multiple complete words
- [x] Streaming data integrity

**Test Scenarios (Split - wide write, narrow read):**
- [x] Write one entry, verify WIDTH_RATIO reads available
- [x] Verify byte ordering in split output
- [x] Read partial (< WIDTH_RATIO), write another, continue reading
- [x] Streaming data integrity

---

### 20. Asymmetric Ratio Variation Test ✅
**Directory:** `test/asymm_ratios/`  
**Target:** `async_fifo_asymm_concat_fwft`, `async_fifo_asymm_split_fwft`  
**Priority:** Medium  
**Status:** ✅ **Implemented**

**Test Configurations:**
| WIDTH_RATIO_LOG2 | Ratio | Write Width | Read Width |
|------------------|-------|-------------|------------|
| 1 | 2:1 | 8-bit | 16-bit (concat) ✅ |
| 2 | 4:1 | 8-bit | 32-bit (concat) ✅ |
| 1 | 2:1 | 16-bit | 8-bit (split) ✅ |
| 2 | 4:1 | 32-bit | 8-bit (split) ✅ |
| - | All | Concurrent operation ✅ |

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
