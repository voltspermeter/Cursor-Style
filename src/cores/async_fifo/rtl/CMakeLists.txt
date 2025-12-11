#------------------------------------------------------------------------------
#
# CMakeLists.txt - RTL source registration for async_fifo modules
#
#------------------------------------------------------------------------------

# Base async_fifo module
add_hdl_source(${CMAKE_CURRENT_SOURCE_DIR}/async_fifo.v
    DEPENDS sync_reg
)

# Async FIFO with flags
add_hdl_source(${CMAKE_CURRENT_SOURCE_DIR}/async_fifo_flags.v
    DEPENDS sync_reg
)

# First Word Fall Through variant
add_hdl_source(${CMAKE_CURRENT_SOURCE_DIR}/async_fifo_fwft.v
    DEPENDS async_fifo
)

# FWFT variant with flags
add_hdl_source(${CMAKE_CURRENT_SOURCE_DIR}/async_fifo_flags_fwft.v
    DEPENDS async_fifo_flags
)

# Asymmetric FIFO - narrow write, wide read
add_hdl_source(${CMAKE_CURRENT_SOURCE_DIR}/async_fifo_asymm_concat_fwft.v
    DEPENDS async_fifo_fwft
)

# Asymmetric FIFO - wide write, narrow read
add_hdl_source(${CMAKE_CURRENT_SOURCE_DIR}/async_fifo_asymm_split_fwft.v
    DEPENDS async_fifo_fwft
)
