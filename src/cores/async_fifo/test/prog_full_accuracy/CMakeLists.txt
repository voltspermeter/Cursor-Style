add_vunit_test(${CMAKE_CURRENT_SOURCE_DIR}/async_fifo_prog_full_accuracy_tb.sv
    DEPENDS async_fifo_flags
    VCDS test_case_1
    VIEW_SIGNALS
        DUT_R0.full
        DUT_R0.prog_full
        DUT_R4.full
        DUT_R4.prog_full
        DUT_R8.full
        DUT_R8.prog_full
)
