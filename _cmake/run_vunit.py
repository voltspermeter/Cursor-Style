#!/usr/bin/env python3
"""
VUnit Test Runner for CMake Integration

This script provides a bridge between CMake and VUnit for running
HDL testbenches with proper test discovery and result reporting.

Usage:
    python run_vunit.py [--list] [--test TEST_NAME] [--output-dir DIR]
"""

import sys
import os
import argparse
from pathlib import Path

# Add VUnit to path if needed
try:
    from vunit import VUnit
except ImportError:
    print("ERROR: VUnit not installed. Run: pip install vunit_hdl")
    sys.exit(1)


def create_vunit_instance(output_dir):
    """Create a VUnit instance configured for Icarus Verilog."""
    # Set output path
    os.environ['VUNIT_OUTPUT_PATH'] = str(output_dir)
    
    # Create VUnit instance with Icarus Verilog
    vu = VUnit.from_argv(
        compile_builtins=False,
        argv=['--output-path', str(output_dir)]
    )
    
    return vu


def main():
    parser = argparse.ArgumentParser(description='VUnit Test Runner')
    parser.add_argument('--list', action='store_true', help='List available tests')
    parser.add_argument('--test', type=str, help='Run specific test')
    parser.add_argument('--output-dir', type=str, default='vunit_out', help='Output directory')
    parser.add_argument('--sources', nargs='+', help='Source files to compile')
    parser.add_argument('--top', type=str, help='Top module name')
    parser.add_argument('--include-dirs', nargs='+', default=[], help='Include directories')
    
    args, remaining = parser.parse_known_args()
    
    if not args.sources:
        print("ERROR: No source files specified")
        sys.exit(1)
    
    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    
    # Create VUnit instance
    try:
        vu = VUnit.from_argv(
            compile_builtins=False,
            argv=['--output-path', str(output_dir)] + remaining
        )
    except SystemExit as e:
        # VUnit may exit for --help, --list, etc.
        sys.exit(e.code if e.code else 0)
    
    # Add source library
    lib = vu.add_library("lib")
    
    # Add source files
    for src in args.sources:
        src_path = Path(src)
        if src_path.exists():
            lib.add_source_files(str(src_path))
        else:
            print(f"WARNING: Source file not found: {src}")
    
    # Add include directories
    for inc_dir in args.include_dirs:
        vu.add_compile_option("icarus.compile_args", [f"-I{inc_dir}"])
    
    # Run tests
    try:
        vu.main()
    except SystemExit as e:
        sys.exit(e.code if e.code else 0)


if __name__ == '__main__':
    main()
