add_vunit_test(${CMAKE_CURRENT_SOURCE_DIR}/async_fifo_asymm_boundary_tb.sv
    DEPENDS async_fifo_asymm_concat_fwft async_fifo_asymm_split_fwft
    VCDS test_case_1
    VIEW_SIGNALS
        DUT_CONCAT.full
        DUT_CONCAT.empty
        DUT_CONCAT.has_data
        DUT_SPLIT.full
        DUT_SPLIT.empty
        DUT_SPLIT.has_data
)
