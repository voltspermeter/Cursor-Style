add_vunit_test(${CMAKE_CURRENT_SOURCE_DIR}/async_fifo_width_variation_tb.sv
    DEPENDS async_fifo
    VCDS test_case_1
    VIEW_SIGNALS
        DUT_W1.full
        DUT_W1.empty
        DUT_W8.full
        DUT_W8.empty
        DUT_W32.full
        DUT_W32.empty
        DUT_W64.full
        DUT_W64.empty
)
