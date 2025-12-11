#!/usr/bin/env python3
"""
Detailed VCD X-state analysis - check both initial state and post-reset state.
"""

import subprocess
import os
import re
import sys

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

def analyze_vcd_detailed(filename):
    """Detailed analysis of VCD for X states."""
    if not os.path.exists(filename):
        return None
    
    with open(filename, 'r') as f:
        content = f.read()
    
    # Parse signal definitions
    signals = {}
    scope_stack = []
    
    for line in content.split('\n'):
        line = line.strip()
        if line.startswith('$scope'):
            parts = line.split()
            if len(parts) >= 3:
                scope_stack.append(parts[2])
        elif line.startswith('$upscope'):
            if scope_stack:
                scope_stack.pop()
        elif line.startswith('$var'):
            match = re.match(r'\$var\s+\w+\s+(\d+)\s+(\S+)\s+(\S+)', line)
            if match:
                width = int(match.group(1))
                sig_id = match.group(2)
                sig_name = match.group(3)
                full_name = '.'.join(scope_stack + [sig_name]) if scope_stack else sig_name
                signals[sig_id] = {'name': full_name, 'width': width, 'values': []}
    
    # Parse value changes
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
            if line.startswith('b') or line.startswith('B'):
                parts = line.split()
                if len(parts) >= 2:
                    value = parts[0][1:]
                    sig_id = parts[1]
                    if sig_id in signals:
                        signals[sig_id]['values'].append((current_time, value))
            elif len(line) >= 2:
                value = line[0]
                sig_id = line[1:]
                if sig_id in signals:
                    signals[sig_id]['values'].append((current_time, value))
    
    return signals

def check_test(test_name, build_dir):
    """Run test and analyze VCD."""
    print(f"\n{'='*70}")
    print(f"Testing: {test_name}")
    print('='*70)
    
    # Run simulation
    vvp_file = os.path.join(build_dir, f"{test_name}.vvp")
    result = subprocess.run(
        ["vvp", vvp_file],
        cwd=build_dir,
        capture_output=True,
        text=True
    )
    
    vcd_file = os.path.join(build_dir, "test_case_1.vcd")
    signals = analyze_vcd_detailed(vcd_file)
    
    if not signals:
        print("  ERROR: Could not analyze VCD")
        return {'error': True}
    
    # Analyze X states
    x_at_init = []      # X at time 0
    x_cleared = []      # X that gets cleared
    x_persistent = []   # X that persists beyond reset
    
    # Time thresholds (in ps)
    RESET_RELEASE = 300000   # 300ns - assume reset is released by this time
    POST_RESET = 500000      # 500ns - well after reset
    
    for sig_id, sig_info in signals.items():
        name = sig_info['name']
        values = sig_info['values']
        
        if not values:
            continue
        
        # Skip testbench-only signals
        if 'DUT' not in name and 'async_fifo' not in name.lower():
            continue
        
        # Check for X at init
        init_val = values[0][1] if values else ''
        has_x_init = 'x' in init_val.lower() if init_val else False
        
        # Find last value before reset release
        last_before_reset = None
        for time, val in values:
            if time <= RESET_RELEASE:
                last_before_reset = val
            else:
                break
        
        # Find first value after reset
        first_after_reset = None
        for time, val in values:
            if time > POST_RESET:
                first_after_reset = val
                break
        
        # Find any X after reset release
        has_x_post = False
        x_post_time = None
        for time, val in values:
            if time > RESET_RELEASE and 'x' in val.lower():
                has_x_post = True
                x_post_time = time
                break
        
        if has_x_init:
            x_at_init.append(name)
        
        if has_x_init and first_after_reset and 'x' not in first_after_reset.lower():
            x_cleared.append(name)
        
        if has_x_post:
            x_persistent.append((name, x_post_time))
    
    print(f"\n  DUT Signals analyzed: {sum(1 for s in signals.values() if 'DUT' in s['name'])}")
    print(f"  Signals with X at init (t=0): {len(x_at_init)}")
    print(f"  Signals with X cleared by reset: {len(x_cleared)}")
    print(f"  Signals with X AFTER reset release (>{RESET_RELEASE}ps): {len(x_persistent)}")
    
    if x_persistent:
        print(f"\n  *** WARNING: X states persisting after reset ***")
        for name, time in x_persistent[:10]:
            print(f"    - {name} @ {time}ps")
    else:
        print(f"\n  ✓ No X states after reset release")
    
    return {
        'x_at_init': len(x_at_init),
        'x_cleared': len(x_cleared),
        'x_persistent': x_persistent
    }

def main():
    build_dir = os.path.dirname(os.path.abspath(__file__))
    
    print("="*70)
    print("Detailed VCD X-State Analysis")
    print("="*70)
    print(f"\nChecking that all signals are properly initialized after reset")
    print(f"(X states at t=0 are OK if cleared by reset)")
    
    results = {}
    total_persistent = 0
    
    for test in TESTS:
        results[test] = check_test(test, build_dir)
        if 'x_persistent' in results[test]:
            total_persistent += len(results[test]['x_persistent'])
    
    # Final summary
    print("\n" + "="*70)
    print("FINAL SUMMARY")
    print("="*70)
    
    all_pass = True
    for test, result in results.items():
        if 'error' in result:
            print(f"  {test}: ERROR")
            all_pass = False
        elif result['x_persistent']:
            print(f"  {test}: FAIL ({len(result['x_persistent'])} persistent X)")
            all_pass = False
        else:
            print(f"  {test}: PASS")
    
    print(f"\nTotal persistent X states: {total_persistent}")
    
    if all_pass:
        print("\n✓ ALL TESTS PASS - No X states after reset")
        return 0
    else:
        print("\n✗ SOME TESTS HAVE PERSISTENT X STATES")
        return 1

if __name__ == "__main__":
    sys.exit(main())
