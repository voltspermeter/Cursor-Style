#!/usr/bin/env python3
"""
Check VCD files for X states after reset.
Analyzes each test's VCD file to find signals that enter X state after reset completes.
"""

import subprocess
import os
import re
import sys

# Test list
TESTS = [
    "async_fifo_clkrates_tb",
    "async_fifo_writepast_tb", 
    "async_fifo_fwft_writepast_tb",
    "async_fifo_reset_sync_tb",
    "async_fifo_ptr_wraparound_tb",
    "async_fifo_empty_timing_tb",
    "async_fifo_full_timing_tb",
    "async_fifo_read_empty_tb",
]

def parse_vcd(filename):
    """Parse VCD file and extract signal values over time."""
    if not os.path.exists(filename):
        return None, None
    
    signals = {}  # id -> signal name
    values = {}   # id -> [(time, value), ...]
    
    with open(filename, 'r') as f:
        content = f.read()
    
    # Parse header for signal definitions
    # Look for $var wire N ID name $end patterns
    var_pattern = r'\$var\s+\w+\s+\d+\s+(\S+)\s+(\S+).*?\$end'
    for match in re.finditer(var_pattern, content):
        sig_id = match.group(1)
        sig_name = match.group(2)
        signals[sig_id] = sig_name
        values[sig_id] = []
    
    # Parse value changes
    # Format: #time followed by value changes
    current_time = 0
    in_dumpvars = False
    
    for line in content.split('\n'):
        line = line.strip()
        
        if line.startswith('#'):
            try:
                current_time = int(line[1:])
            except:
                pass
        elif line.startswith('$dumpvars'):
            in_dumpvars = True
        elif line.startswith('$end') and in_dumpvars:
            in_dumpvars = False
        elif line and not line.startswith('$'):
            # Value change: b<binary> <id> or 0/1/x/z<id>
            if line.startswith('b') or line.startswith('B'):
                parts = line.split()
                if len(parts) >= 2:
                    value = parts[0][1:]  # Remove 'b'
                    sig_id = parts[1]
                    if sig_id in values:
                        values[sig_id].append((current_time, value))
            elif len(line) >= 2:
                value = line[0]
                sig_id = line[1:]
                if sig_id in values:
                    values[sig_id].append((current_time, value))
    
    return signals, values

def find_x_after_reset(signals, values, reset_release_time=500000):
    """Find signals that have X values after reset release time."""
    x_signals = []
    
    for sig_id, changes in values.items():
        sig_name = signals.get(sig_id, sig_id)
        
        for time, value in changes:
            if time >= reset_release_time:
                if 'x' in value.lower():
                    x_signals.append((sig_name, time, value))
                    break  # Only report first X occurrence per signal
    
    return x_signals

def run_test_and_check(test_name, build_dir):
    """Run a single test and check its VCD for X states."""
    print(f"\n{'='*60}")
    print(f"Testing: {test_name}")
    print('='*60)
    
    # Run the test
    vvp_file = os.path.join(build_dir, f"{test_name}.vvp")
    if not os.path.exists(vvp_file):
        # Compile first
        result = subprocess.run(
            ["make", f"test_{test_name}_compile"],
            cwd=build_dir,
            capture_output=True,
            text=True
        )
        if result.returncode != 0:
            print(f"  COMPILE ERROR: {result.stderr}")
            return None
    
    # Run simulation
    result = subprocess.run(
        ["vvp", vvp_file],
        cwd=build_dir,
        capture_output=True,
        text=True
    )
    
    # Check VCD file
    vcd_file = os.path.join(build_dir, "test_case_1.vcd")
    if not os.path.exists(vcd_file):
        print(f"  WARNING: No VCD file generated")
        return None
    
    signals, values = parse_vcd(vcd_file)
    if signals is None:
        print(f"  ERROR: Could not parse VCD")
        return None
    
    # Find X states after reset (assume reset releases within 500ns = 500000ps)
    x_signals = find_x_after_reset(signals, values, reset_release_time=500000)
    
    print(f"  Total signals: {len(signals)}")
    print(f"  X states after reset: {len(x_signals)}")
    
    if x_signals:
        print(f"\n  Signals with X state after reset:")
        for sig, time, value in x_signals[:20]:  # Limit to first 20
            print(f"    - {sig} @ {time}ps: {value}")
        if len(x_signals) > 20:
            print(f"    ... and {len(x_signals) - 20} more")
    
    return x_signals

def main():
    build_dir = os.path.dirname(os.path.abspath(__file__))
    
    print("="*60)
    print("VCD X-State Analysis After Reset")
    print("="*60)
    
    all_results = {}
    total_x_signals = 0
    
    for test in TESTS:
        x_signals = run_test_and_check(test, build_dir)
        all_results[test] = x_signals
        if x_signals:
            total_x_signals += len(x_signals)
    
    # Summary
    print("\n" + "="*60)
    print("SUMMARY")
    print("="*60)
    
    for test, x_signals in all_results.items():
        if x_signals is None:
            status = "ERROR"
        elif len(x_signals) == 0:
            status = "PASS (no X states)"
        else:
            status = f"WARN ({len(x_signals)} X states)"
        print(f"  {test}: {status}")
    
    print(f"\nTotal X signals found: {total_x_signals}")
    
    return 0 if total_x_signals == 0 else 1

if __name__ == "__main__":
    sys.exit(main())
