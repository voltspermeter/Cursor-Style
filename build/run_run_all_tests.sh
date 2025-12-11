#!/bin/bash
# Auto-generated test runner script
# Runs all tests and reports summary

cd "/workspace/build"

PASSED=0
FAILED=0
FAILED_TESTS=""

echo "Running: async_fifo_clkrates_tb"
if /usr/bin/vvp /workspace/build/async_fifo_clkrates_tb.vvp; then
    ((PASSED++))
else
    ((FAILED++))
    FAILED_TESTS="$FAILED_TESTS async_fifo_clkrates_tb"
fi

echo "Running: async_fifo_writepast_tb"
if /usr/bin/vvp /workspace/build/async_fifo_writepast_tb.vvp; then
    ((PASSED++))
else
    ((FAILED++))
    FAILED_TESTS="$FAILED_TESTS async_fifo_writepast_tb"
fi

echo "Running: async_fifo_fwft_writepast_tb"
if /usr/bin/vvp /workspace/build/async_fifo_fwft_writepast_tb.vvp; then
    ((PASSED++))
else
    ((FAILED++))
    FAILED_TESTS="$FAILED_TESTS async_fifo_fwft_writepast_tb"
fi

echo "Running: async_fifo_reset_sync_tb"
if /usr/bin/vvp /workspace/build/async_fifo_reset_sync_tb.vvp; then
    ((PASSED++))
else
    ((FAILED++))
    FAILED_TESTS="$FAILED_TESTS async_fifo_reset_sync_tb"
fi

echo "Running: async_fifo_ptr_wraparound_tb"
if /usr/bin/vvp /workspace/build/async_fifo_ptr_wraparound_tb.vvp; then
    ((PASSED++))
else
    ((FAILED++))
    FAILED_TESTS="$FAILED_TESTS async_fifo_ptr_wraparound_tb"
fi

echo "Running: async_fifo_empty_timing_tb"
if /usr/bin/vvp /workspace/build/async_fifo_empty_timing_tb.vvp; then
    ((PASSED++))
else
    ((FAILED++))
    FAILED_TESTS="$FAILED_TESTS async_fifo_empty_timing_tb"
fi

echo "Running: async_fifo_full_timing_tb"
if /usr/bin/vvp /workspace/build/async_fifo_full_timing_tb.vvp; then
    ((PASSED++))
else
    ((FAILED++))
    FAILED_TESTS="$FAILED_TESTS async_fifo_full_timing_tb"
fi

echo "Running: async_fifo_read_empty_tb"
if /usr/bin/vvp /workspace/build/async_fifo_read_empty_tb.vvp; then
    ((PASSED++))
else
    ((FAILED++))
    FAILED_TESTS="$FAILED_TESTS async_fifo_read_empty_tb"
fi

echo "Running: async_fifo_data_patterns_tb"
if /usr/bin/vvp /workspace/build/async_fifo_data_patterns_tb.vvp; then
    ((PASSED++))
else
    ((FAILED++))
    FAILED_TESTS="$FAILED_TESTS async_fifo_data_patterns_tb"
fi

echo "Running: async_fifo_back_to_back_tb"
if /usr/bin/vvp /workspace/build/async_fifo_back_to_back_tb.vvp; then
    ((PASSED++))
else
    ((FAILED++))
    FAILED_TESTS="$FAILED_TESTS async_fifo_back_to_back_tb"
fi

echo "Running: async_fifo_simultaneous_tb"
if /usr/bin/vvp /workspace/build/async_fifo_simultaneous_tb.vvp; then
    ((PASSED++))
else
    ((FAILED++))
    FAILED_TESTS="$FAILED_TESTS async_fifo_simultaneous_tb"
fi

echo "Running: async_fifo_single_entry_tb"
if /usr/bin/vvp /workspace/build/async_fifo_single_entry_tb.vvp; then
    ((PASSED++))
else
    ((FAILED++))
    FAILED_TESTS="$FAILED_TESTS async_fifo_single_entry_tb"
fi

echo "Running: async_fifo_near_full_tb"
if /usr/bin/vvp /workspace/build/async_fifo_near_full_tb.vvp; then
    ((PASSED++))
else
    ((FAILED++))
    FAILED_TESTS="$FAILED_TESTS async_fifo_near_full_tb"
fi

echo "Running: async_fifo_near_empty_tb"
if /usr/bin/vvp /workspace/build/async_fifo_near_empty_tb.vvp; then
    ((PASSED++))
else
    ((FAILED++))
    FAILED_TESTS="$FAILED_TESTS async_fifo_near_empty_tb"
fi

echo "Running: async_fifo_depth_variation_tb"
if /usr/bin/vvp /workspace/build/async_fifo_depth_variation_tb.vvp; then
    ((PASSED++))
else
    ((FAILED++))
    FAILED_TESTS="$FAILED_TESTS async_fifo_depth_variation_tb"
fi

echo "Running: async_fifo_width_variation_tb"
if /usr/bin/vvp /workspace/build/async_fifo_width_variation_tb.vvp; then
    ((PASSED++))
else
    ((FAILED++))
    FAILED_TESTS="$FAILED_TESTS async_fifo_width_variation_tb"
fi

echo "Running: async_fifo_random_traffic_tb"
if /usr/bin/vvp /workspace/build/async_fifo_random_traffic_tb.vvp; then
    ((PASSED++))
else
    ((FAILED++))
    FAILED_TESTS="$FAILED_TESTS async_fifo_random_traffic_tb"
fi

echo "Running: async_fifo_clock_jitter_tb"
if /usr/bin/vvp /workspace/build/async_fifo_clock_jitter_tb.vvp; then
    ((PASSED++))
else
    ((FAILED++))
    FAILED_TESTS="$FAILED_TESTS async_fifo_clock_jitter_tb"
fi

echo "Running: async_fifo_clock_switching_tb"
if /usr/bin/vvp /workspace/build/async_fifo_clock_switching_tb.vvp; then
    ((PASSED++))
else
    ((FAILED++))
    FAILED_TESTS="$FAILED_TESTS async_fifo_clock_switching_tb"
fi

echo "Running: async_fifo_prog_full_accuracy_tb"
if /usr/bin/vvp /workspace/build/async_fifo_prog_full_accuracy_tb.vvp; then
    ((PASSED++))
else
    ((FAILED++))
    FAILED_TESTS="$FAILED_TESTS async_fifo_prog_full_accuracy_tb"
fi

echo "Running: async_fifo_flag_consistency_tb"
if /usr/bin/vvp /workspace/build/async_fifo_flag_consistency_tb.vvp; then
    ((PASSED++))
else
    ((FAILED++))
    FAILED_TESTS="$FAILED_TESTS async_fifo_flag_consistency_tb"
fi

echo "Running: async_fifo_asymm_boundary_tb"
if /usr/bin/vvp /workspace/build/async_fifo_asymm_boundary_tb.vvp; then
    ((PASSED++))
else
    ((FAILED++))
    FAILED_TESTS="$FAILED_TESTS async_fifo_asymm_boundary_tb"
fi

echo "Running: async_fifo_asymm_ratios_tb"
if /usr/bin/vvp /workspace/build/async_fifo_asymm_ratios_tb.vvp; then
    ((PASSED++))
else
    ((FAILED++))
    FAILED_TESTS="$FAILED_TESTS async_fifo_asymm_ratios_tb"
fi

echo ""
echo "============================================"
echo "  TEST SUMMARY"
echo "============================================"
echo "  Passed: $PASSED"
echo "  Failed: $FAILED"
echo "  Total:  $((PASSED + FAILED))"
if [ $FAILED -gt 0 ]; then
    echo ""
    echo "  Failed tests:$FAILED_TESTS"
fi
echo "============================================"
exit $FAILED
