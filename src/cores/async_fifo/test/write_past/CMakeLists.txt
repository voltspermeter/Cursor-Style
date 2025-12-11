#------------------------------------------------------------------------------
#
# CMakeLists.txt - Write-past-full testbench (standard FIFO)
#
# Tests async_fifo write-past-full protection behavior.
#
#------------------------------------------------------------------------------

add_vunit_test(${CMAKE_CURRENT_SOURCE_DIR}/async_fifo_writepast_tb.sv
    DEPENDS async_fifo
    VCDS test_case_1
    VIEW_SIGNALS
        DUT.rst
        DUT.wr_clk
        DUT.wr_en
        DUT.rd_clk
        DUT.full
        DUT.empty
        DUT.has_data
        DUT.rd_en
        DUT.wr_data
        DUT.rd_data
)
