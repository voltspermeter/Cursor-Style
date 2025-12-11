add_vunit_test(${CMAKE_CURRENT_SOURCE_DIR}/async_fifo_single_entry_tb.sv
    DEPENDS async_fifo_fwft
    VCDS test_case_1
    VIEW_SIGNALS
        DUT.rst
        DUT.wr_clk
        DUT.rd_clk
        DUT.wr_en
        DUT.rd_en
        DUT.wr_data
        DUT.rd_data
        DUT.full
        DUT.empty
        DUT.has_data
)
