# CMake HDL Build Infrastructure

This directory contains CMake modules for building and simulating HDL designs using Icarus Verilog.

## Directory Structure

```
_cmake/
├── README.md              # This file
├── HDLHelpers.cmake       # Core HDL source management functions
├── IcarusVerilog.cmake    # Icarus Verilog compilation functions
├── VUnitHelpers.cmake     # VUnit testbench support functions
└── vunit/
    └── vunit_defines.svh  # VUnit compatibility macros for Icarus
```

## Quick Start

### Prerequisites

- CMake 3.16 or higher
- Icarus Verilog (`iverilog` and `vvp` in PATH)

### Build Instructions

```bash
# Configure
mkdir build && cd build
cmake ..

# Compile all test benches
make build_all_tests

# Run a specific test
make test_async_fifo_clkrates_tb

# Run all tests (recommended - continues past failures)
ctest --output-on-failure

# Alternative: Run all tests via make (stops on first failure)
make run_all_tests

# Alternative: Run all tests via script (continues past failures)
make run_all_tests_all

# Verbose CTest output
ctest -V
```

### Recommended Workflow

```bash
# From a clean state
./setup.sh                    # Install deps, configure, build, test

# Or manually:
mkdir build && cd build
cmake ..
make build_all_tests          # Compile all tests first
ctest --output-on-failure     # Run all tests
```

## CMake Functions

### HDLHelpers.cmake

#### `add_hdl_source(<source_file> [DEPENDS <dep1> <dep2> ...])`

Register an HDL source file as a module.

```cmake
add_hdl_source(async_fifo.v
    DEPENDS sync_reg
)
```

**Arguments:**
- `source_file` - Path to Verilog/SystemVerilog source file
- `DEPENDS` - List of module dependencies (modules instantiated internally)

**Notes:**
- Module name is derived from filename without extension
- Dependencies are tracked for automatic source collection

#### `get_hdl_module_source(<module_name> <output_var>)`

Get the source file path for a registered module.

```cmake
get_hdl_module_source(async_fifo ASYNC_FIFO_SOURCE)
message(STATUS "Source: ${ASYNC_FIFO_SOURCE}")
```

#### `get_hdl_module_deps(<module_name> <output_var>)`

Get direct dependencies of a module.

```cmake
get_hdl_module_deps(async_fifo_fwft DEPS)
# DEPS = "async_fifo"
```

#### `get_hdl_module_all_deps(<module_name> <output_var>)`

Get all dependencies (recursive) of a module.

```cmake
get_hdl_module_all_deps(async_fifo_fwft ALL_DEPS)
# ALL_DEPS = "async_fifo;sync_reg"
```

#### `get_hdl_module_all_sources(<module_name> <output_var>)`

Get all source files needed to compile a module (including dependencies).

```cmake
get_hdl_module_all_sources(async_fifo_fwft ALL_SOURCES)
# Returns sources in dependency order
```

#### `print_hdl_modules()`

Print all registered modules and dependencies (for debugging).

### IcarusVerilog.cmake

#### `add_iverilog_library(<name> <sources...>)`

Create a compilation target for HDL sources.

```cmake
add_iverilog_library(my_design
    ${CMAKE_CURRENT_SOURCE_DIR}/top.v
    ${CMAKE_CURRENT_SOURCE_DIR}/sub.v
)
```

#### `add_hdl_module_target(<module_name>)`

Create a compilation target for a registered HDL module.

```cmake
add_hdl_module_target(async_fifo_fwft)
# Creates target: hdl_async_fifo_fwft
```

#### `add_iverilog_simulation(<name> <top_module> <sources...>)`

Create compilation and simulation targets.

```cmake
add_iverilog_simulation(my_sim top_module
    ${SOURCES}
    PLUS_ARGS +vcd=dump.vcd
    TIMEOUT 60
)
# Creates targets: my_sim_compile, my_sim_run, my_sim
```

#### `create_all_hdl_targets()`

Create compilation targets for all registered HDL modules.

### VUnitHelpers.cmake

#### `add_vunit_test(<testbench_file> DEPENDS <module> [VCDS <vcd>...] [VIEW_SIGNALS <sig>...])`

Register a VUnit testbench.

```cmake
add_vunit_test(async_fifo_tb.sv
    DEPENDS async_fifo
    VCDS test_case_1
    VIEW_SIGNALS
        DUT.rst
        DUT.clk
        DUT.data
)
```

**Arguments:**
- `testbench_file` - SystemVerilog testbench file
- `DEPENDS` - RTL module being tested
- `VCDS` - VCD file names to generate
- `VIEW_SIGNALS` - Signals for waveform viewer

#### `create_vunit_test_target(<test_name>)`

Create simulation targets for a registered test.

```cmake
create_vunit_test_target(async_fifo_tb)
# Creates targets: test_async_fifo_tb_compile, test_async_fifo_tb_run, test_async_fifo_tb
```

#### `create_all_vunit_test_targets()`

Create targets for all registered tests.

#### `add_test_suite(<suite_name>)`

Create a target that runs all tests.

```cmake
add_test_suite(run_all_tests)
```

#### `generate_dependency_list(<output_file>)`

Generate a text file listing all modules and dependencies.

## VUnit Compatibility

The `vunit/vunit_defines.svh` file provides VUnit-compatible macros for Icarus Verilog:

### Available Macros

```systemverilog
`TEST_SUITE begin
    `TEST_CASE("test name") begin
        // Test code
        `CHECK_EQUAL(expected, actual);
        `CHECK_TRUE(condition);
        `CHECK_FALSE(condition);
    end
end

`WATCHDOG(10000us);  // Timeout
```

### Macro Reference

| Macro | Description |
|-------|-------------|
| `` `TEST_SUITE `` | Defines a test suite (maps to `initial` block) |
| `` `TEST_CASE(name) `` | Defines a test case |
| `` `CHECK_EQUAL(exp, act) `` | Assert equality |
| `` `CHECK_TRUE(cond) `` | Assert condition is true |
| `` `CHECK_FALSE(cond) `` | Assert condition is false |
| `` `WATCHDOG(timeout) `` | Set simulation timeout |

## Build Targets

After configuration, the following targets are available:

### HDL Module Targets

| Target | Description |
|--------|-------------|
| `hdl_<module>` | Compile specific HDL module |
| `hdl_async_fifo` | Compile async_fifo module |
| `hdl_async_fifo_fwft` | Compile async_fifo_fwft module |

### Test Targets

| Target | Description |
|--------|-------------|
| `test_<name>` | Run specific test (alias for _run) |
| `test_<name>_compile` | Compile test only |
| `test_<name>_run` | Run test |
| `run_all_tests` | Run all tests |

### Example Targets

```bash
make hdl_async_fifo_fwft           # Compile FWFT module
make test_async_fifo_clkrates_tb   # Run clock rates test
make run_all_tests                  # Run all tests
```

## Configuration Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `IVERILOG_FLAGS` | `-g2012` | Compiler flags |
| `IVERILOG_INCLUDE_DIRS` | `` | Include directories |
| `VUNIT_INCLUDE_DIR` | `_cmake/vunit` | VUnit include path |
| `SYNC_REG_SOURCE` | `` | External sync_reg.v path |

### Setting Variables

```bash
cmake -DIVERILOG_FLAGS="-g2012 -Wall" ..
cmake -DSYNC_REG_SOURCE=/path/to/sync_reg.v ..
```

## Generated Files

After building, the following files are generated in the build directory:

| File | Description |
|------|-------------|
| `<module>.vvp` | Compiled simulation executable |
| `<test>.vvp` | Compiled test executable |
| `dependencies.txt` | Module/test dependency list |
| `*.vcd` | Waveform dump files |

## Extending the Build System

### Adding New Modules

1. Register the module in a CMakeLists.txt:

```cmake
add_hdl_source(${CMAKE_CURRENT_SOURCE_DIR}/new_module.v
    DEPENDS dependency1 dependency2
)
```

2. Re-run CMake to register the module.

### Adding New Tests

1. Create a testbench file following VUnit conventions
2. Create a CMakeLists.txt:

```cmake
add_vunit_test(${CMAKE_CURRENT_SOURCE_DIR}/new_test_tb.sv
    DEPENDS module_under_test
    VCDS test_case_1
)
```

3. Add `add_subdirectory()` in parent CMakeLists.txt
4. Re-run CMake

## Troubleshooting

### iverilog not found

Ensure Icarus Verilog is installed and in PATH:

```bash
which iverilog
iverilog -V
```

### Module not found errors

Check that all dependencies are registered before the module that uses them.

### VUnit macros not recognized

Ensure `VUNIT_INCLUDE_DIR` points to the directory containing `vunit_defines.svh`.

## Example Usage

Complete example of building and running a test:

```bash
# Configure project
cd /workspace
mkdir build && cd build
cmake ..

# Build and run a specific test
make test_async_fifo_clkrates_tb

# View results
cat async_fifo_clkrates_tb.log  # If logging enabled
gtkwave test_case_1.vcd         # View waveforms

# Run all tests with CTest
ctest -V

# Clean and rebuild
make clean
make
```
