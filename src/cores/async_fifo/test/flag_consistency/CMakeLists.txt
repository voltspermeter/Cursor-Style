add_vunit_test(${CMAKE_CURRENT_SOURCE_DIR}/async_fifo_flag_consistency_tb.sv
    DEPENDS async_fifo_flags
    VCDS test_case_1
    VIEW_SIGNALS
        DUT.full
        DUT.prog_full
        DUT.empty
        DUT.has_data
        DUT.wr_ptr
        DUT.rd_ptr
)
