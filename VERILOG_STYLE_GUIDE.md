# Verilog Style Guide

This style guide documents the coding conventions and patterns found in this codebase. Following these conventions ensures consistency and readability across all Verilog/SystemVerilog files.

---

## Table of Contents

1. [File Organization](#file-organization)
2. [Module Declaration](#module-declaration)
3. [Naming Conventions](#naming-conventions)
4. [Data Types and Declarations](#data-types-and-declarations)
5. [Constants and Parameters](#constants-and-parameters)
6. [Sequential Logic](#sequential-logic)
7. [Combinational Logic](#combinational-logic)
8. [Module Instantiation](#module-instantiation)
9. [Functions](#functions)
10. [Synthesis Directives](#synthesis-directives)
11. [Testbench Conventions](#testbench-conventions)
12. [Formatting and Whitespace](#formatting-and-whitespace)
13. [CMake Build System](#cmake-build-system)

---

## File Organization

### File Header

Every RTL file begins with a standardized header block:

```verilog
//-----------------------------------------------------------------------------
//
// <filename>.v - <brief description of the module>
//                <additional description lines if needed>
//
// Copyright (c) <year> 
//
// Contact: 
//
// ----------------------------------------------------------------------------
```

### File Extensions

| Type | Extension |
|------|-----------|
| RTL modules | `.v` |
| SystemVerilog testbenches | `.sv` |

### File Naming

- Use **snake_case** for file names
- File name should match the module name contained within
- Use descriptive suffixes for module variants:
  - `_fwft` - First Word Fall Through variants
  - `_flags` - Modules with additional flag outputs
  - `_asymm` - Asymmetric width modules
  - `_tb` - Testbench files

**Examples:**
- `async_fifo.v`
- `async_fifo_fwft.v`
- `async_fifo_flags_fwft.v`
- `async_fifo_writepast_tb.sv`

---

## Module Declaration

### Parameter Declaration

Parameters are declared first in the module header, each with explicit default values:

```verilog
module async_fifo #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 12,
    parameter RESERVE = 0
) (
```

### Port List Style

Use the **leading comma style** for port declarations. The first port begins with `(` on the parameter closing line, and subsequent ports begin with `, `:

```verilog
) (   input rst

    , input wr_clk
    , input wr_en
    , input [DATA_WIDTH-1:0] wr_data
    , output full

    , input  rd_clk
    , input  rd_en
    , output reg [DATA_WIDTH-1:0] rd_data
    , output empty
    , output has_data
);
```

### Port Grouping

Group related ports together with a blank line separator:
1. Reset signals
2. Write clock domain signals
3. Read clock domain signals

### Port Direction Alignment

Align `input` and `output` keywords for visual clarity, and use consistent spacing for signal names.

---

## Naming Conventions

### General Rules

- Use **snake_case** (lowercase with underscores) for all signal and variable names
- Use **UPPER_CASE_WITH_UNDERSCORES** for parameters, localparams, and instance names
- Names should be descriptive but concise

### Signal Prefixes

| Prefix | Meaning | Example |
|--------|---------|---------|
| `wr_` | Write clock domain | `wr_clk`, `wr_en`, `wr_data`, `wr_ptr` |
| `rd_` | Read clock domain | `rd_clk`, `rd_en`, `rd_data`, `rd_ptr` |

### Signal Suffixes

| Suffix | Meaning | Example |
|--------|---------|---------|
| `_i` | Internal signal | `full_i`, `rd_en_i`, `wr_data_i` |
| `_r` or `_reg` | Registered version | `wr_allow_r`, `full_reg`, `data_in_reg` |
| `_d1` | Delayed by 1 clock cycle | `rd_en_d1`, `rd_en_i_d1` |
| `_s1`, `_s2` | Synchronizer pipeline stages | `wr_ptr_s1`, `wr_ptr_s2` |
| `_sync` | Synchronized (cross-domain) signal | `wr_ptr_sync`, `rd_ptr_sync` |
| `_gray` | Gray-coded value | `wr_ptr_gray`, `rd_ptr_gray` |
| `_dec` | Decoded value | `wr_ptr_dec`, `rd_ptr_dec` |
| `_cnt` | Counter | `wr_rst_cnt`, `rd_rst_cnt` |

### Common Signal Names

| Signal | Purpose |
|--------|---------|
| `rst` | Active-high reset |
| `clk` | Clock (or `wr_clk`/`rd_clk` for dual-clock) |
| `full` | FIFO full flag |
| `empty` | FIFO empty flag |
| `has_data` | Data available flag (opposite of empty) |
| `occup` | Occupancy count |
| `space` | Available space count |

### Instance Names

Use **UPPER_CASE** for module instance names:

```verilog
async_fifo_fwft #(...) FIFO_INST (...);
sync_reg #(...) SYNC_WR (...);
```

Common instance naming patterns:
- `DUT` - Device Under Test (in testbenches)
- `FIFO_INST` - FIFO instance
- `SYNC_WR`, `SYNC_RR` - Synchronizer instances (WR=write, RR=read)

---

## Data Types and Declarations

### Wire vs Reg

- Use `wire` for combinational logic and connections
- Use `reg` for sequential logic (outputs of always blocks)

```verilog
wire [ADDR_WIDTH:0] wr_ptr_gray;    // Combinational
reg [ADDR_WIDTH:0] wr_ptr;          // Sequential
```

### Declaration Grouping

Group related declarations together, separated by blank lines:

```verilog
// Pointers
reg [ADDR_WIDTH:0] wr_ptr;
reg [ADDR_WIDTH:0] rd_ptr;

// Occupancy calculations
wire [ADDR_WIDTH:0] occup;
wire [ADDR_WIDTH+1:0] space;

// Gray-coded pointers
wire [ADDR_WIDTH:0] wr_ptr_gray;
wire [ADDR_WIDTH:0] rd_ptr_gray;
```

### Bit-Width Specifications

Always use explicit bit-widths in literal values:

```verilog
// Preferred
wr_rst_cnt <= 3'd7;
wr_rst <= 1'b1;
full_reg <= 1'b0;

// For zero initialization in resets, shorthand is acceptable
wr_ptr <= 'b0;
```

### RAM Declaration

Use synthesis attributes for RAM inference:

```verilog
localparam RAM_TYPE = (ADDR_WIDTH > 6) ? "BLOCK" : "DISTRIBUTED";
(* RAM_STYLE = RAM_TYPE *) reg [DATA_WIDTH-1:0] ram[DEPTH-1:0];
```

Alternative array indexing style (both are acceptable):
```verilog
reg [DATA_WIDTH-1:0] ram[DEPTH-1:0];   // [high:low]
reg [DATA_WIDTH-1:0] ram[0:DEPTH-1];   // [low:high]
```

---

## Constants and Parameters

### Parameter Defaults

Always provide default values for parameters:

```verilog
parameter DATA_WIDTH = 8,
parameter ADDR_WIDTH = 12,
parameter RESERVE = 12'd0
```

### Localparam for Derived Constants

Use `localparam` for values calculated from parameters:

```verilog
localparam DEPTH = 2**ADDR_WIDTH;
localparam RAM_TYPE = (ADDR_WIDTH > 6) ? "BLOCK" : "DISTRIBUTED";
localparam READ_WIDTH = WRITE_WIDTH*(2**WIDTH_RATIO_LOG2);
```

---

## Sequential Logic

### Always Block Style

Use `always @(posedge clk)` for synchronous logic:

```verilog
always @(posedge wr_clk) begin
  if (wr_rst) begin
    wr_ptr <= 'b0;
  end else if (wr_en && !full_i) begin
    wr_ptr <= wr_ptr + 1'b1;
  end
end
```

### Asynchronous Reset (When Required)

For modules requiring asynchronous reset:

```verilog
always @(posedge rd_clk or posedge rst) begin
  if (rst) begin
    rd_rst_cnt <= 3'd7;
    rd_rst <= 1'b1;
  end else begin
    // ...
  end
end
```

### Reset Handling Pattern

Use a reset counter pattern for controlled reset release:

```verilog
always @(posedge wr_clk) begin
  if (rst_sw) begin
    wr_rst_cnt <= 3'd7;
    wr_rst <= 1'b1;
  end else begin
    if (|wr_rst_cnt) begin
      wr_rst_cnt <= wr_rst_cnt - 1'b1;
      wr_rst <= 1'b1;
    end else begin
      wr_rst <= 1'b0;
    end
  end
end
```

### Non-Blocking Assignments

Always use non-blocking assignments (`<=`) in sequential blocks:

```verilog
always @(posedge clk) begin
  rd_data <= ram[rd_ptr[ADDR_WIDTH-1:0]];
end
```

---

## Combinational Logic

### Assign Statements

Use `assign` for simple combinational logic:

```verilog
assign wr_ptr_gray = binary2gray(wr_ptr);
assign empty = (rd_ptr == wr_ptr_sync) ? 1'b1 : rd_rst;
assign occup = (wr_ptr - rd_ptr_sync);
```

### Internal Signal Naming

Create named internal signals for complex conditions:

```verilog
wire wr_en_i = wr_en & ~full_i;
wire rd_en_i = rd_en && !empty;
```

### Ternary Operators

Use ternary operators for simple conditional assignments:

```verilog
assign full_i = ((wr_ptr[ADDR_WIDTH-1:0] == rd_ptr_sync[ADDR_WIDTH-1:0])
                 && (wr_ptr[ADDR_WIDTH] != rd_ptr_sync[ADDR_WIDTH])) ? 1'b1 : 1'b0;
```

For multi-line ternary expressions, align the `&&` or condition continuation.

---

## Module Instantiation

### Parameter Override Style

```verilog
async_fifo #(
      .DATA_WIDTH(DATA_WIDTH)
    , .ADDR_WIDTH(ADDR_WIDTH)
    , .RESERVE(RESERVE)
) FIFO_INST (
```

### Port Connection Style

Use the **leading comma style** with named connections:

```verilog
) FIFO_INST (
    .rst(rst)

    , .wr_clk(wr_clk)
    , .wr_en(wr_en)
    , .wr_data(wr_data)
    , .full(full)

    , .rd_clk(rd_clk)
    , .rd_en(rd_en_i)
    , .rd_data(rd_data_i)
    , .empty(empty_i)
    , .has_data(has_data_i)
);
```

### Alignment

- Align parameter assignments
- Group ports by clock domain
- Separate port groups with blank lines

---

## Functions

### Function Declaration

```verilog
function[ADDR_WIDTH:0] binary2gray;
    input[ADDR_WIDTH:0] input_value;
    integer i;
    begin
        binary2gray[ADDR_WIDTH] = input_value[ADDR_WIDTH];
        for (i=0; i<ADDR_WIDTH; i = i+1)
            binary2gray[i] = input_value[i] ^ input_value[i + 1];
    end
endfunction
```

### Function Naming

Use **snake_case** with descriptive names:
- `binary2gray`
- `gray2binary`

---

## Synthesis Directives

### RAM Style Attributes

```verilog
(* RAM_STYLE = RAM_TYPE *) reg [DATA_WIDTH-1:0] ram[DEPTH-1:0];
```

### Lint Pragmas

Use Verilator-style pragmas to suppress known warnings:

```verilog
/* verilator lint_off WIDTH */
assign full = (space <= RESERVE) ? 1'b1 : full_reg | wr_rst;
/* verilator lint_on WIDTH */
```

---

## Testbench Conventions

### File Structure

```systemverilog
`timescale 1ps/1ps
`include "vunit_defines.svh"

module <module_name>_tb;

// Signal declarations
// ...

// Clock generation
// ...

// DUT instantiation
// ...

// Stimulus/checking logic
// ...

`TEST_SUITE begin
  `TEST_CASE("<test-name>") begin
    // Test code
  end
end

`WATCHDOG(10000us);

endmodule
```

### Signal Types

Use `logic` for testbench signals that are both driven and sampled:

```systemverilog
logic rst, wr_clk = 1'b0, rd_clk = 1'b0;
logic [7:0] wr_data;
wire  [7:0] rd_data;
```

### Clock Generation

```systemverilog
always begin
  #10000;
  rd_clk <= !rd_clk;
end
```

### DUT Instantiation

Name the device under test `DUT`:

```systemverilog
async_fifo_fwft #(
      .DATA_WIDTH( 8 )
    , .ADDR_WIDTH( 4 )
    , .RESERVE( 3 )
) DUT (
    .rst      ( rst     )
    // ...
);
```

### Verification Queues

Use SystemVerilog dynamic arrays for data checking:

```systemverilog
logic [7:0] data_queue[$];
data_queue.push_back(data_rec);
data_rec_out = data_queue.pop_front();
```

### Debug Output

Use `$display` for test progress and debug messages:

```systemverilog
$display( "Input data was %d ", wr_data );
$display( "Output data was %d, %s", rd_data, data_rec_out == rd_data ? "MATCH" : "NO MATCH!!!!!!!" );
```

### Waveform Dumping

```systemverilog
$dumpfile("test_case_1.vcd");
$dumpvars();
```

### Assertions

Use VUnit macros for checking:

```systemverilog
`CHECK_EQUAL( data_rec_out, rd_data );
```

---

## Formatting and Whitespace

### Indentation

- Use **2 spaces** for indentation (no tabs)
- Indent contents of `begin`/`end` blocks
- Indent contents of `module`/`endmodule`

### Line Length

Keep lines reasonably short (approximately 80-100 characters). Break long lines at logical points:

```verilog
assign full_i = ((wr_ptr[ADDR_WIDTH-1:0] == rd_ptr_sync[ADDR_WIDTH-1:0])
                 && (wr_ptr[ADDR_WIDTH] != rd_ptr_sync[ADDR_WIDTH])) ? 1'b1 : 1'b0;
```

### Blank Lines

- Use blank lines to separate logical sections
- Separate always blocks with blank lines
- Group related declarations

### Operators

- Use spaces around binary operators: `a + b`, `x == y`
- No space after unary operators: `!full`, `~data_in_reg`, `|wr_rst_cnt`
- Parentheses for clarity in complex expressions

### Begin/End Placement

Place `begin` on the same line as the condition, `end` on its own line:

```verilog
if (wr_rst) begin
  wr_ptr <= 'b0;
end else if (wr_en && !full_i) begin
  wr_ptr <= wr_ptr + 1'b1;
end
```

---

## Summary of Key Conventions

| Aspect | Convention |
|--------|------------|
| File names | snake_case, match module name |
| Parameters | UPPER_CASE with defaults |
| Signals | snake_case with descriptive prefixes/suffixes |
| Instances | UPPER_CASE |
| Port style | Leading comma |
| Indentation | 2 spaces |
| Reset values | `'b0` shorthand or explicit widths |
| Sequential logic | Non-blocking (`<=`) |
| Combinational logic | `assign` statements |

---

## CMake Build System

This project uses CMake with custom functions for HDL source management and VUnit test integration.

### Directory Structure

The project uses a hierarchical CMake structure with `CMakeText.txt` files at each level:

```
project/
├── src/
│   ├── CMakeText.txt           # Top-level: add_subdirectory(cores)
│   └── cores/
│       ├── CMakeText.txt       # Cores index: add_subdirectory(async_fifo)
│       └── <core_name>/
│           ├── CMakeText.txt   # Core-level: includes rtl/ and test/
│           ├── rtl/
│           │   └── CMakeLists.txt    # RTL source definitions
│           └── test/
│               ├── CMakeLists.txt    # Test subdirectory includes
│               └── <test_name>/
│                   └── CMakeLists.txt # Individual test definitions
```

### CMake File Naming Convention

| File Name | Purpose |
|-----------|---------|
| `CMakeText.txt` | Directory includes only (`add_subdirectory()` calls) |
| `CMakeLists.txt` | Source/test definitions (`add_hdl_source()` or `add_vunit_test()`) |

### Top-Level CMake Files

Each level uses `add_subdirectory()` to include child directories:

```cmake
# src/CMakeText.txt
add_subdirectory(cores)

# src/cores/CMakeText.txt
add_subdirectory(async_fifo)

# src/cores/async_fifo/CMakeText.txt
add_subdirectory(rtl)
add_subdirectory(test)
```

### RTL Source Registration (`add_hdl_source`)

Use the `add_hdl_source()` function to register RTL modules:

```cmake
add_hdl_source( <source_file>.v
  DEPENDS
    <dependency_module_1>
    <dependency_module_2> )
```

**Parameters:**
- First argument: Source file name (with `.v` extension)
- `DEPENDS`: Keyword followed by list of module dependencies (one per line)

**Example:**

```cmake
add_hdl_source( async_fifo.v
  DEPENDS
    sync_reg )

add_hdl_source( async_fifo_fwft.v
  DEPENDS
    async_fifo )

add_hdl_source( async_fifo_asymm_concat_fwft.v
  DEPENDS
    async_fifo_fwft)
```

**Conventions:**
- The module name (target name) is derived from the file name without extension
- Dependencies reference other module names, not file names
- List dependencies that the module instantiates internally
- Indent dependency names with 4 spaces

### Test Directory Structure

The test `CMakeLists.txt` includes subdirectories for each test:

```cmake
add_subdirectory(clock_rates)
add_subdirectory(write_past)
add_subdirectory(write_past_fwft)
```

### VUnit Test Registration (`add_vunit_test`)

Use the `add_vunit_test()` function to register testbenches:

```cmake
add_vunit_test( <testbench_file>.sv
  DEPENDS <rtl_module>
  VCDS
    <vcd_name_1>
    <vcd_name_2>
  VIEW_SIGNALS
    DUT.<signal_1>
    DUT.<signal_2>
)
```

**Parameters:**
- First argument: Testbench file name (with `.sv` extension)
- `DEPENDS`: The RTL module being tested
- `VCDS`: List of VCD dump file names (without `.vcd` extension)
- `VIEW_SIGNALS`: Hierarchical signal names for waveform viewing

**Example:**

```cmake
add_vunit_test( async_fifo_clkrates_tb.sv
  DEPENDS async_fifo_fwft
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

**Conventions:**
- Test directory name should be descriptive of the test purpose
- Testbench file name follows pattern: `<module>_<test_type>_tb.sv`
- VCD names typically match test case names in the testbench
- VIEW_SIGNALS uses hierarchical paths starting with `DUT.`
- Include key interface signals: clocks, resets, enables, data, flags

### CMake Formatting Rules

- Use 2-space indentation for continuation lines
- Place each dependency/signal on its own line
- No trailing spaces
- One blank line between `add_hdl_source()` or `add_vunit_test()` calls
- Close parenthesis on the last argument line (not on its own line)
