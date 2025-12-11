add_vunit_test(${CMAKE_CURRENT_SOURCE_DIR}/async_fifo_depth_variation_tb.sv
    DEPENDS async_fifo
    VCDS test_case_1
    VIEW_SIGNALS
        DUT_D4.full
        DUT_D4.empty
        DUT_D16.full
        DUT_D16.empty
        DUT_D64.full
        DUT_D64.empty
)
