add_vunit_test(${CMAKE_CURRENT_SOURCE_DIR}/async_fifo_asymm_ratios_tb.sv
    DEPENDS async_fifo_asymm_concat_fwft async_fifo_asymm_split_fwft
    VCDS test_case_1
    VIEW_SIGNALS
        DUT_CONCAT_2.full
        DUT_CONCAT_2.empty
        DUT_CONCAT_4.full
        DUT_CONCAT_4.empty
        DUT_SPLIT_2.full
        DUT_SPLIT_2.empty
        DUT_SPLIT_4.full
        DUT_SPLIT_4.empty
)
