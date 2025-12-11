add_vunit_test(${CMAKE_CURRENT_SOURCE_DIR}/async_fifo_reset_sync_tb.sv
    DEPENDS async_fifo
    VCDS test_case_1
    VIEW_SIGNALS
        DUT.rst
        DUT.wr_clk
        DUT.rd_clk
        DUT.wr_rst
        DUT.rd_rst
        DUT.wr_rst_cnt
        DUT.rd_rst_cnt
        DUT.wr_ptr
        DUT.rd_ptr
        DUT.full
        DUT.empty
)
