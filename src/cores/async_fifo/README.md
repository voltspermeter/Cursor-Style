# Asynchronous FIFO Cores

A collection of asynchronous FIFO (First-In-First-Out) cores with separate read and write clock domains. These cores are designed for reliable cross-clock-domain data transfer using Gray code pointer synchronization.

## Table of Contents

- [Overview](#overview)
- [Module Hierarchy](#module-hierarchy)
- [Core Modules](#core-modules)
  - [async_fifo](#async_fifo)
  - [async_fifo_fwft](#async_fifo_fwft)
  - [async_fifo_flags](#async_fifo_flags)
  - [async_fifo_flags_fwft](#async_fifo_flags_fwft)
  - [async_fifo_asymm_concat_fwft](#async_fifo_asymm_concat_fwft)
  - [async_fifo_asymm_split_fwft](#async_fifo_asymm_split_fwft)
- [Architecture](#architecture)
- [Usage Examples](#usage-examples)
- [Integration](#integration)
- [Testing](#testing)

---

## Overview

These FIFO cores provide safe data transfer between two independent clock domains. Key features include:

- **Gray code synchronization** - Prevents metastability issues during pointer crossing
- **Configurable depth** - Parameterized address width for flexible sizing
- **Configurable data width** - Supports arbitrary data bus widths
- **Reserve/programmable full** - Optional early full indication for flow control
- **First Word Fall Through (FWFT)** - Zero-latency read variants
- **Asymmetric widths** - Support for different read/write port widths

### Design Philosophy

- All modules use a consistent port interface style
- Reset is active-high and properly synchronized to both clock domains
- Full/empty flags are conservatively generated to prevent overflow/underflow
- RAM inference uses synthesis attributes for optimal FPGA implementation

---

## Module Hierarchy

```
async_fifo                      # Base standard FIFO
├── async_fifo_fwft             # FWFT wrapper
│   ├── async_fifo_asymm_concat_fwft  # Asymmetric (narrow write, wide read)
│   └── async_fifo_asymm_split_fwft   # Asymmetric (wide write, narrow read)

async_fifo_flags                # Base FIFO with prog_full + full
└── async_fifo_flags_fwft       # FWFT wrapper with flags
```

### External Dependencies

All modules depend on `sync_reg` - a synchronizer register module for clock domain crossing of the reset signal.

---

## Core Modules

### async_fifo

**File:** `src/cores/async_fifo/rtl/async_fifo.v`

The base asynchronous FIFO with standard read latency (data appears one cycle after `rd_en`).

#### Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `DATA_WIDTH` | 8 | Width of the data bus in bits |
| `ADDR_WIDTH` | 12 | Address width (depth = 2^ADDR_WIDTH) |
| `RESERVE` | 0 | Reserved entries for early full (0 = disabled) |

#### Ports

| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| `rst` | input | 1 | Active-high asynchronous reset |
| **Write Domain** |
| `wr_clk` | input | 1 | Write clock |
| `wr_en` | input | 1 | Write enable |
| `wr_data` | input | DATA_WIDTH | Write data |
| `full` | output | 1 | FIFO full flag (or prog_full if RESERVE > 0) |
| **Read Domain** |
| `rd_clk` | input | 1 | Read clock |
| `rd_en` | input | 1 | Read enable |
| `rd_data` | output | DATA_WIDTH | Read data (registered) |
| `empty` | output | 1 | FIFO empty flag |
| `has_data` | output | 1 | Data available flag (inverse of empty) |

#### Behavior

- **Write:** Data is written on rising edge of `wr_clk` when `wr_en=1` and `full=0`
- **Read:** Data appears on `rd_data` one clock cycle after `rd_en=1` and `empty=0`
- **Reset:** Both domains enter reset state; pointers cleared after 8 clock cycles

#### Timing Diagram (Standard Read)

```
wr_clk:  ‾‾|__|‾‾|__|‾‾|__|‾‾|__|‾‾
wr_en:   ___|‾‾‾‾‾‾‾|___________
wr_data: ---<D0><D1>------------
         
rd_clk:  ‾‾|__|‾‾|__|‾‾|__|‾‾|__|‾‾
rd_en:   _________|‾‾‾‾‾‾‾|_____
rd_data: ---------<XX><D0><D1>--
                   ↑
                   1 cycle latency
```

---

### async_fifo_fwft

**File:** `src/cores/async_fifo/rtl/async_fifo_fwft.v`

First Word Fall Through variant. Data is pre-fetched and available on `rd_data` as soon as `has_data=1`, with zero read latency.

#### Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `DATA_WIDTH` | 8 | Width of the data bus in bits |
| `ADDR_WIDTH` | 12 | Address width (depth = 2^ADDR_WIDTH) |
| `RESERVE` | 0 | Reserved entries for early full |

#### Ports

Same as `async_fifo`.

#### Behavior

- **Read:** Data is immediately valid on `rd_data` when `has_data=1`
- **Advance:** Assert `rd_en=1` to advance to next word
- Data is pre-fetched from the underlying FIFO into an output register

#### Timing Diagram (FWFT Read)

```
rd_clk:   ‾‾|__|‾‾|__|‾‾|__|‾‾|__|‾‾
has_data: ____|‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾|____
rd_data:  ----<D0      ><D1   >----
rd_en:    ________|‾‾‾‾‾|__________
                  ↑
                  D1 available immediately
```

#### Use Cases

- Stream processing where data must be inspected before consumption
- Protocol interfaces requiring look-ahead capability
- Reducing effective read latency in pipelined designs

---

### async_fifo_flags

**File:** `src/cores/async_fifo/rtl/async_fifo_flags.v`

Extended version with separate `full` and `prog_full` outputs.

#### Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `DATA_WIDTH` | 8 | Width of the data bus in bits |
| `ADDR_WIDTH` | 12 | Address width (depth = 2^ADDR_WIDTH) |
| `RESERVE` | 0 | Threshold for programmable full |

#### Additional Ports

| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| `full` | output | 1 | True full flag (FIFO completely full) |
| `prog_full` | output | 1 | Programmable full (space ≤ RESERVE) |

#### Behavior

- `full` asserts when the FIFO has zero space remaining
- `prog_full` asserts when available space ≤ RESERVE
- Useful for flow control with advance warning

---

### async_fifo_flags_fwft

**File:** `src/cores/async_fifo/rtl/async_fifo_flags_fwft.v`

FWFT variant with both `full` and `prog_full` flags.

#### Parameters

Same as `async_fifo_flags`.

#### Ports

Combines FWFT behavior with dual full flags.

---

### async_fifo_asymm_concat_fwft

**File:** `src/cores/async_fifo/rtl/async_fifo_asymm_concat_fwft.v`

Asymmetric FIFO where the **read port is wider** than the write port. Multiple narrow writes are concatenated into a single wide read word.

#### Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `WR_WIDTH_BYTES` | 1 | Write port width in bytes |
| `WR_ADDR_WIDTH` | 12 | Write-side address width |
| `WIDTH_RATIO_LOG2` | 2 | Log2 of width ratio (read_width = write_width × 2^N) |
| `RESERVE` | 0 | Reserved entries for early full |

#### Port Widths

- **Write data:** `8 × WR_WIDTH_BYTES` bits
- **Read data:** `8 × WR_WIDTH_BYTES × 2^WIDTH_RATIO_LOG2` bits

#### Example Configuration

```verilog
// 8-bit write, 32-bit read (ratio = 4, log2 = 2)
async_fifo_asymm_concat_fwft #(
    .WR_WIDTH_BYTES(1),      // 8-bit writes
    .WR_ADDR_WIDTH(12),      // 4096 write entries
    .WIDTH_RATIO_LOG2(2)     // 4:1 ratio → 32-bit reads
) FIFO_INST (...);
```

#### Behavior

- Writes accumulate until `2^WIDTH_RATIO_LOG2` words received
- Data is concatenated LSB-first (first write → LSBs of read word)
- Read side sees `depth / 2^WIDTH_RATIO_LOG2` entries

---

### async_fifo_asymm_split_fwft

**File:** `src/cores/async_fifo/rtl/async_fifo_asymm_split_fwft.v`

Asymmetric FIFO where the **write port is wider** than the read port. A single wide write is split into multiple narrow read words.

#### Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `WR_WIDTH_BYTES` | 4 | Write port width in bytes |
| `WR_ADDR_WIDTH` | 12 | Write-side address width |
| `WIDTH_RATIO_LOG2` | 2 | Log2 of width ratio (write_width = read_width × 2^N) |
| `RESERVE` | 0 | Reserved entries for early full |

#### Port Widths

- **Write data:** `8 × WR_WIDTH_BYTES` bits
- **Read data:** `8 × WR_WIDTH_BYTES / 2^WIDTH_RATIO_LOG2` bits

#### Example Configuration

```verilog
// 32-bit write, 8-bit read (ratio = 4, log2 = 2)
async_fifo_asymm_split_fwft #(
    .WR_WIDTH_BYTES(4),      // 32-bit writes
    .WR_ADDR_WIDTH(12),      // 4096 write entries
    .WIDTH_RATIO_LOG2(2)     // 4:1 ratio → 8-bit reads
) FIFO_INST (...);
```

#### Behavior

- Each write produces `2^WIDTH_RATIO_LOG2` read words
- Data is read LSB-first (LSBs of write → first read)
- Read side sees `depth × 2^WIDTH_RATIO_LOG2` entries

---

## Architecture

### Gray Code Synchronization

Pointers are converted to Gray code before crossing clock domains to ensure only one bit changes per increment, preventing glitches during metastability resolution.

```
Write Domain                    Read Domain
─────────────                   ───────────
wr_ptr (binary)                 
    ↓                           
wr_ptr_gray ──→ [sync] ──→ wr_ptr_s1 → wr_ptr_s2
                                    ↓
                              wr_ptr_dec (binary)
                                    ↓
                              empty calculation
```

### Reset Synchronization

Reset is synchronized to each clock domain independently using `sync_reg` instances. A reset counter ensures stable operation:

1. External `rst` is synchronized to each clock domain
2. Internal reset (`wr_rst`/`rd_rst`) held for 8 cycles
3. Pointers and flags cleared during reset

### RAM Inference

RAM style is automatically selected based on depth:

| ADDR_WIDTH | Depth | RAM Style |
|------------|-------|-----------|
| ≤ 6 | ≤ 64 | DISTRIBUTED |
| > 6 | > 64 | BLOCK |

This is controlled via synthesis attributes:
```verilog
(* RAM_STYLE = RAM_TYPE *) reg [DATA_WIDTH-1:0] ram[DEPTH-1:0];
```

### Full/Empty Generation

- **Empty:** Generated in read domain by comparing `rd_ptr` with synchronized `wr_ptr`
- **Full:** Generated in write domain by comparing `wr_ptr` with synchronized `rd_ptr`
- Comparisons are conservative (may indicate full/empty slightly early)

---

## Usage Examples

### Basic Asynchronous FIFO

```verilog
async_fifo #(
    .DATA_WIDTH(32),
    .ADDR_WIDTH(10),    // 1024 entries
    .RESERVE(0)
) u_fifo (
    .rst(rst)
    
    , .wr_clk(clk_100mhz)
    , .wr_en(wr_valid && !full)
    , .wr_data(wr_data)
    , .full(full)
    
    , .rd_clk(clk_150mhz)
    , .rd_en(rd_ready && has_data)
    , .rd_data(rd_data)
    , .empty(empty)
    , .has_data(has_data)
);
```

### FWFT with Flow Control

```verilog
async_fifo_fwft #(
    .DATA_WIDTH(64),
    .ADDR_WIDTH(8),     // 256 entries
    .RESERVE(4)         // Assert full when 4 or fewer spaces
) u_fifo (
    .rst(rst)
    
    , .wr_clk(producer_clk)
    , .wr_en(producer_valid)
    , .wr_data(producer_data)
    , .full(producer_stall)  // Backpressure to producer
    
    , .rd_clk(consumer_clk)
    , .rd_en(consumer_ready) // Advance when consumer ready
    , .rd_data(consumer_data)
    , .empty()
    , .has_data(consumer_valid)
);

// Consumer sees data immediately when has_data=1
// No need to wait a cycle after rd_en
```

### Width Conversion (Narrow to Wide)

```verilog
// Receive 8-bit bytes, output 64-bit words
async_fifo_asymm_concat_fwft #(
    .WR_WIDTH_BYTES(1),     // 8-bit input
    .WR_ADDR_WIDTH(12),
    .WIDTH_RATIO_LOG2(3),   // 8:1 ratio → 64-bit output
    .RESERVE(8)
) u_byte_to_word (
    .rst(rst)
    
    , .wr_clk(byte_clk)
    , .wr_en(byte_valid)
    , .wr_data(byte_data)
    , .full(byte_stall)
    
    , .rd_clk(word_clk)
    , .rd_en(word_ready)
    , .rd_data(word_data)   // 64 bits
    , .empty()
    , .has_data(word_valid)
);
```

### Width Conversion (Wide to Narrow)

```verilog
// Receive 32-bit words, output 8-bit bytes
async_fifo_asymm_split_fwft #(
    .WR_WIDTH_BYTES(4),     // 32-bit input
    .WR_ADDR_WIDTH(10),
    .WIDTH_RATIO_LOG2(2),   // 4:1 ratio → 8-bit output
    .RESERVE(4)
) u_word_to_byte (
    .rst(rst)
    
    , .wr_clk(word_clk)
    , .wr_en(word_valid)
    , .wr_data(word_data)   // 32 bits
    , .full(word_stall)
    
    , .rd_clk(byte_clk)
    , .rd_en(byte_ready)
    , .rd_data(byte_data)   // 8 bits
    , .empty()
    , .has_data(byte_valid)
);
```

---

## Integration

### CMake Integration

The project uses a hierarchical CMake structure:

```
src/
├── CMakeText.txt                    # add_subdirectory(cores)
└── cores/
    ├── CMakeText.txt                # add_subdirectory(async_fifo)
    └── async_fifo/
        ├── CMakeText.txt            # add_subdirectory(rtl), add_subdirectory(test)
        ├── rtl/
        │   └── CMakeLists.txt       # RTL source definitions
        └── test/
            └── ...
```

Register RTL sources in `src/cores/async_fifo/rtl/CMakeLists.txt`:

```cmake
add_hdl_source( async_fifo.v
  DEPENDS
    sync_reg )

add_hdl_source( async_fifo_fwft.v
  DEPENDS
    async_fifo )
```

**CMake File Naming Convention:**
- `CMakeText.txt` - Directory includes only (`add_subdirectory()` calls)
- `CMakeLists.txt` - Source/test definitions (`add_hdl_source()` or `add_vunit_test()`)

### File Include Order

When not using CMake, include files in dependency order:

1. `sync_reg.v` (external dependency)
2. `src/cores/async_fifo/rtl/async_fifo.v`
3. `src/cores/async_fifo/rtl/async_fifo_fwft.v` (if using FWFT)
4. `src/cores/async_fifo/rtl/async_fifo_flags.v` (if using flags variant)
5. Asymmetric variants as needed

---

## Testing

For detailed testbench documentation, see [test/TESTBENCH.md](test/TESTBENCH.md).

### Test Structure

Tests are located in `src/cores/async_fifo/test/` subdirectories:

| Directory | Target Module | Description |
|-----------|---------------|-------------|
| `clock_rates/` | `async_fifo_fwft` | Multiple write/read clock ratios (40-500 MHz) |
| `write_past/` | `async_fifo` | Write-past-full protection (standard) |
| `write_past_fwft/` | `async_fifo_fwft` | Write-past-full protection (FWFT) |
| `write_past_flags/` | `async_fifo_flags` | Write-past-full with flag variants |
| `asymm_concat/` | `async_fifo_asymm_concat_fwft` | Asymmetric width (narrow→wide) |
| `asymm_split/` | `async_fifo_asymm_split_fwft` | Asymmetric width (wide→narrow) |

### Running Tests

Tests use the VUnit framework with VCD waveform generation:

```bash
# From build directory
cmake ..
ctest -R async_fifo         # Run all async_fifo tests
ctest -R async_fifo -V      # Verbose output
ctest -R clock_rates        # Run specific test
```

### Viewing Waveforms

```bash
gtkwave test_case_1.vcd
```

### Test Coverage

The test suite verifies:

- Multiple clock frequency ratios (40 MHz to 500 MHz)
- Full condition handling
- Empty condition handling
- Reset behavior
- Data integrity across clock domains
- Write-past-full protection
- FWFT vs standard read latency behavior

### Verification Methodology

All testbenches use a reference queue model:
- Write data is pushed to a SystemVerilog dynamic array
- Read data is compared against queue entries
- VUnit `CHECK_EQUAL` macro asserts correctness
- `WATCHDOG` macro prevents test hangs

---

## Design Notes

### Metastability

- All clock domain crossings use 2-stage synchronizers
- Gray code ensures single-bit transitions
- Pointers are registered before Gray conversion

### Latency

| Module | Write-to-Read Latency |
|--------|----------------------|
| `async_fifo` | 3-4 cycles (sync) + 1 cycle (read) |
| `async_fifo_fwft` | 3-4 cycles (sync) + 0 cycles (pre-fetched) |

### Resource Usage (Approximate)

| Component | LUTs | FFs | BRAM |
|-----------|------|-----|------|
| Pointers + sync | ~4×ADDR_WIDTH | ~8×ADDR_WIDTH | 0 |
| Gray encode/decode | ~2×ADDR_WIDTH | 0 | 0 |
| RAM (ADDR_WIDTH ≤ 6) | ~DEPTH×DATA_WIDTH | 0 | 0 |
| RAM (ADDR_WIDTH > 6) | ~0 | 0 | varies |

---

## License

Copyright (c) 2019

See individual source files for license details.
