add_vunit_test(${CMAKE_CURRENT_SOURCE_DIR}/async_fifo_full_timing_tb.sv
    DEPENDS async_fifo
    VCDS test_case_1
    VIEW_SIGNALS
        DUT.rst
        DUT.wr_clk
        DUT.rd_clk
        DUT.wr_en
        DUT.rd_en
        DUT.full
        DUT.empty
        DUT.wr_ptr
        DUT.rd_ptr
        DUT.rd_ptr_sync
)
