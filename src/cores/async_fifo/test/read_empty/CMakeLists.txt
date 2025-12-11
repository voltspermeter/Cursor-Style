add_vunit_test(${CMAKE_CURRENT_SOURCE_DIR}/async_fifo_read_empty_tb.sv
    DEPENDS async_fifo
    VCDS test_case_1
    VIEW_SIGNALS
        DUT.rst
        DUT.wr_clk
        DUT.rd_clk
        DUT.wr_en
        DUT.rd_en
        DUT.empty
        DUT.has_data
        DUT.rd_ptr
        DUT.rd_data
)
