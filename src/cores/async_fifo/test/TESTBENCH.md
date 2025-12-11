# Async FIFO Testbench Documentation

This document describes the testbenches for the asynchronous FIFO cores. All testbenches use the VUnit framework for test management and verification.

## Table of Contents

- [Overview](#overview)
- [Test Framework](#test-framework)
- [Testbench Architecture](#testbench-architecture)
- [Test Cases](#test-cases)
  - [Clock Rates Test](#clock-rates-test)
  - [Write-Past Test (Standard)](#write-past-test-standard)
  - [Write-Past Test (FWFT)](#write-past-test-fwft)
- [Verification Methodology](#verification-methodology)
- [Running Tests](#running-tests)
- [Adding New Tests](#adding-new-tests)

---

## Overview

The test suite validates the asynchronous FIFO cores under various operating conditions:

| Test Directory | Target Module | Purpose |
|----------------|---------------|---------|
| `clock_rates/` | `async_fifo_fwft` | Multiple clock frequency ratios |
| `write_past/` | `async_fifo` | Write-past-full protection (standard) |
| `write_past_fwft/` | `async_fifo_fwft` | Write-past-full protection (FWFT) |
| `write_past_flags/` | `async_fifo_flags` | Write-past-full with flag variants |
| `asymm_concat/` | `async_fifo_asymm_concat_fwft` | Asymmetric width (narrow→wide) |
| `asymm_split/` | `async_fifo_asymm_split_fwft` | Asymmetric width (wide→narrow) |

---

## Test Framework

### VUnit Integration

All testbenches use the VUnit framework, which provides:

- Test case management (`TEST_SUITE`, `TEST_CASE`)
- Assertions (`CHECK_EQUAL`)
- Timeout protection (`WATCHDOG`)
- Automatic test discovery and execution

### Required Includes

```systemverilog
`timescale 1ps/1ps
`include "vunit_defines.svh"
```

### Basic Test Structure

```systemverilog
module <module_name>_tb;

  // Signal declarations
  // DUT instantiation
  // Clock generation
  // Stimulus/checking logic

  `TEST_SUITE begin
    `TEST_CASE("<test-name>") begin
      // Test stimulus
    end
  end

  `WATCHDOG(10000us);

endmodule
```

---

## Testbench Architecture

### Common Components

All async FIFO testbenches share a common architecture:

```
┌─────────────────────────────────────────────────────────────┐
│                      Testbench                              │
│  ┌─────────────┐    ┌─────────┐    ┌─────────────────────┐ │
│  │   Writer    │───▶│   DUT   │───▶│      Reader         │ │
│  │  (wr_clk)   │    │  FIFO   │    │     (rd_clk)        │ │
│  └─────────────┘    └─────────┘    └─────────────────────┘ │
│         │                                    │              │
│         ▼                                    ▼              │
│  ┌─────────────┐                    ┌─────────────────────┐ │
│  │ data_queue  │◀───────────────────│   Data Checker      │ │
│  │   (ref)     │    Compare         │                     │ │
│  └─────────────┘                    └─────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### Signal Declarations

```systemverilog
// Control signals
logic rst;
logic wr_clk = 1'b0, rd_clk = 1'b0;
logic wr_allow, wr_allow_r;
logic rd_allow, rd_allow_r;

// DUT interface
wire  full, empty, has_data;
wire  rd_en, wr_en;
logic [7:0] wr_data;
wire  [7:0] rd_data;

// Verification
logic [7:0] data_queue[$];      // Reference queue
logic [7:0] data_rec;           // Written data record
logic [7:0] data_rec_out;       // Expected read data
integer write_count = 0;        // Write transaction counter
```

### Clock Generation

#### Fixed Frequency Clock

```systemverilog
always begin
  #10000;              // 10ns half-period = 50 MHz
  rd_clk <= !rd_clk;
end
```

#### Variable Frequency Clock

```systemverilog
// Manually toggled in test case for variable rates
while( write_count < 200 ) begin
  #6250;               // 6.25ns half-period = 80 MHz
  wr_clk <= !wr_clk;
end
```

### DUT Instantiation

```systemverilog
async_fifo_fwft #(
      .DATA_WIDTH( 8 )
    , .ADDR_WIDTH( 4 )
    , .RESERVE( 3 )
) DUT (
      .rst      ( rst     )
    , .wr_clk   ( wr_clk  )
    , .wr_en    ( wr_en   )
    , .full     ( full    )
    , .wr_data  ( wr_data )

    , .rd_clk   ( rd_clk   )
    , .rd_en    ( rd_en    )
    , .empty    ( empty    )
    , .has_data ( has_data )
    , .rd_data  ( rd_data  )
);
```

### Write Logic

```systemverilog
assign wr_en = wr_allow_r & ~full;

always @(posedge wr_clk) begin
  wr_allow_r <= wr_allow;
  if( rst ) begin
    wr_data <= 8'd0;
  end else if( wr_en ) begin
    $display( "Input data was %d ", wr_data );
    data_rec = wr_data;
    data_queue.push_back(data_rec);  // Store for verification
    write_count = write_count + 1;
    wr_data <= $urandom;             // or wr_data + 1 for sequential
  end
end
```

### Read and Verification Logic

#### For Standard FIFO (1-cycle read latency)

```systemverilog
assign rd_en = rd_allow_r & has_data;

always @(posedge rd_clk) begin
  rd_en_d1 <= rd_en;
  rd_allow_r <= rd_allow;
  if( rd_en_d1 ) begin               // Check one cycle after rd_en
    if( data_queue.size() == 0) begin
      $display( "NO DATA IN RECORD QUEUE" );
      `CHECK_EQUAL( 8'hXX, rd_data );
    end else begin
      data_rec_out = data_queue.pop_front();
      $display( "Output data was %d, %s", rd_data, 
                data_rec_out == rd_data ? "MATCH" : "NO MATCH!!!!!!!" );
      `CHECK_EQUAL( data_rec_out, rd_data );
    end
  end
end
```

#### For FWFT FIFO (0-cycle read latency)

```systemverilog
assign rd_en = has_data;

always @(posedge rd_clk) begin
  if( rd_en ) begin                  // Check immediately on rd_en
    if( data_queue.size() == 0) begin
      $display( "NO DATA IN RECORD QUEUE" );
    end else begin
      data_rec_out = data_queue.pop_front();
      $display( "Output data was %d, %s", rd_data, 
                data_rec_out == rd_data ? "MATCH" : "NO MATCH!!!!!!!" );
      `CHECK_EQUAL( data_rec_out, rd_data );
    end
  end
end
```

---

## Test Cases

### Clock Rates Test

**File:** `clock_rates/async_fifo_clkrates_tb.sv`

**Module Under Test:** `async_fifo_fwft`

**Purpose:** Validates FIFO operation across multiple write clock frequencies while the read clock remains fixed.

#### Test Configuration

| Parameter | Value |
|-----------|-------|
| DATA_WIDTH | 8 |
| ADDR_WIDTH | 4 (16 entries) |
| RESERVE | 3 |
| Read Clock | 50 MHz (fixed) |

#### Test Phases

| Phase | Write Clock | Writes | Description |
|-------|-------------|--------|-------------|
| 1 | 80 MHz | 0-200 | Writer faster than reader |
| 2 | 40.81 MHz | 200-400 | Writer slower than reader |
| 3 | 199.92 MHz | 400-600 | Writer ~4x faster |
| 4 | 250 MHz | 600-800 | Writer 5x faster |
| 5 | 50 MHz | 800-1000 | Equal frequencies |
| 6 | Flush | - | Drain FIFO |
| 7 | 500 MHz | 1000-2000 | Writer 10x faster |

#### Key Verification Points

- Data integrity across all clock ratios
- No data loss during frequency transitions
- Proper full/empty flag behavior at extreme ratios

#### Timing Details

```
Read clock:  50 MHz  (20ns period, 10000ps half-period)
Write clocks:
  - 80 MHz:     12.5ns period (6250ps half-period)
  - 40.81 MHz:  24.5ns period (12250ps half-period)
  - 199.92 MHz: 5ns period (2501ps half-period)
  - 250 MHz:    4ns period (2000ps half-period)
  - 500 MHz:    2ns period (1000ps half-period)
```

---

### Write-Past Test (Standard)

**File:** `write_past/async_fifo_writepast_tb.sv`

**Module Under Test:** `async_fifo`

**Purpose:** Verifies that the FIFO correctly handles writes when full, ensuring data written past full is rejected.

#### Test Configuration

| Parameter | Value |
|-----------|-------|
| DATA_WIDTH | 8 |
| ADDR_WIDTH | 4 (16 entries) |
| RESERVE | 8 |
| Write Clock | 50 MHz |
| Read Clock | 50 MHz |

#### Test Sequence

```
1. Reset (20 cycles)
2. Wait for reset release (20 cycles)
3. Enable writes with wr_expect=1 for 16 cycles
4. Continue writes with wr_expect=0 for 4 cycles (write-past-full)
5. Stop writes
6. Enable reads, drain FIFO
7. Repeat steps 3-6
8. Verify all expected data received
```

#### Control Signals

| Signal | Purpose |
|--------|---------|
| `wr_allow` | Enable write attempts |
| `wr_expect` | When high, written data is expected to be stored |
| `rd_allow` | Enable read operations |

#### Key Verification Points

- Only first 16 writes (before full) are stored
- Writes after full are silently rejected
- All expected data is read correctly
- No extra data appears in output

---

### Write-Past Test (FWFT)

**File:** `write_past_fwft/async_fifo_fwft_writepast_tb.sv`

**Module Under Test:** `async_fifo_fwft`

**Purpose:** Same as standard write-past test but for FWFT variant.

#### Test Configuration

| Parameter | Value |
|-----------|-------|
| DATA_WIDTH | 8 |
| ADDR_WIDTH | 4 (16 entries) |
| RESERVE | 8 |
| Write Clock | 50 MHz |
| Read Clock | 50 MHz |

#### Differences from Standard Test

| Aspect | Standard | FWFT |
|--------|----------|------|
| Expected writes before full | 16 | 17 |
| Write-past cycles | 4 | 3 |
| Read verification timing | `rd_en_d1` | `rd_en` |

The FWFT version expects one additional write because the FWFT output register provides an extra storage location.

---

## Verification Methodology

### Reference Queue Model

The testbenches use a SystemVerilog dynamic array as a reference queue:

```systemverilog
logic [7:0] data_queue[$];

// On write (when expected to succeed)
data_queue.push_back(wr_data);

// On read
expected = data_queue.pop_front();
`CHECK_EQUAL(expected, rd_data);
```

### Selective Recording

For write-past tests, the `wr_expect` signal controls whether writes are recorded:

```systemverilog
if(wr_expect_r) begin
  data_queue.push_back(data_rec);  // Only record expected writes
end
```

### Assertion Macros

```systemverilog
// Equality check (fails test if not equal)
`CHECK_EQUAL( expected, actual );

// Watchdog timer (fails test if exceeded)
`WATCHDOG(10000us);
```

### Debug Output

All testbenches include `$display` statements for debugging:

```systemverilog
$display( "Input data was %d ", wr_data );
$display( "Output data was %d, %s", rd_data, 
          data_rec_out == rd_data ? "MATCH" : "NO MATCH!!!!!!!" );
```

### Waveform Generation

Each test case generates VCD files for waveform analysis:

```systemverilog
`TEST_CASE("test-name") begin
  $dumpfile("test_case_1.vcd");
  $dumpvars();
  // ...
end
```

---

## Running Tests

### Prerequisites

- VUnit Python package
- Verilator, ModelSim, or compatible simulator
- CMake build system

### Build and Run

```bash
# Configure
mkdir build && cd build
cmake ..

# Run all async_fifo tests
ctest -R async_fifo

# Run specific test
ctest -R async_fifo_clkrates

# Verbose output
ctest -R async_fifo -V
```

### Viewing Waveforms

After running tests, VCD files are generated in the build directory:

```bash
gtkwave test_case_1.vcd
```

---

## Adding New Tests

### 1. Create Test Directory

```bash
mkdir -p src/cores/async_fifo/test/new_test/
```

### 2. Create Testbench File

```systemverilog
// src/cores/async_fifo/test/new_test/async_fifo_newtest_tb.sv
`timescale 1ps/1ps
`include "vunit_defines.svh"

module async_fifo_newtest_tb;

  // Signal declarations
  logic rst, wr_clk = 1'b0, rd_clk = 1'b0;
  // ... other signals ...

  // Clock generation
  always begin
    #10000;
    wr_clk <= !wr_clk;
  end

  always begin
    #10000;
    rd_clk <= !rd_clk;
  end

  // DUT instantiation
  async_fifo #(
        .DATA_WIDTH( 8 )
      , .ADDR_WIDTH( 4 )
      , .RESERVE( 0 )
  ) DUT (
      .rst      ( rst     )
      , .wr_clk   ( wr_clk  )
      // ... other ports ...
  );

  // Stimulus and checking
  // ...

  `TEST_SUITE begin
    `TEST_CASE("New-Test-Case") begin
      $dumpfile("test_case_1.vcd");
      $dumpvars();

      // Test stimulus here
      rst <= 1'b1;
      repeat(20) @(posedge wr_clk);
      rst <= 1'b0;
      
      // ... test operations ...

      `CHECK_EQUAL( 1'b1, 1'b1 );  // Final check
    end
  end

  `WATCHDOG(10000us);

endmodule
```

### 3. Create CMakeLists.txt

```cmake
# src/cores/async_fifo/test/new_test/CMakeLists.txt
add_vunit_test( async_fifo_newtest_tb.sv
  DEPENDS async_fifo
  VCDS
    test_case_1
  VIEW_SIGNALS
    DUT.rst
    DUT.wr_clk
    DUT.wr_en
    DUT.rd_clk
    DUT.full
    DUT.empty
    DUT.has_data
    DUT.rd_en
    DUT.wr_data
    DUT.rd_data
)
```

### 4. Register in Parent CMakeLists.txt

Add to `src/cores/async_fifo/test/CMakeLists.txt`:

```cmake
add_subdirectory(new_test)
```

### 5. Build and Run

```bash
cd build
cmake ..
ctest -R async_fifo_newtest -V
```

---

## Appendix: Test Parameters Quick Reference

| Test | Module | Depth | Reserve | Wr Clk | Rd Clk |
|------|--------|-------|---------|--------|--------|
| clock_rates | async_fifo_fwft | 16 | 3 | Variable | 50 MHz |
| write_past | async_fifo | 16 | 8 | 50 MHz | 50 MHz |
| write_past_fwft | async_fifo_fwft | 16 | 8 | 50 MHz | 50 MHz |
