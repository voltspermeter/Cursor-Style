add_hdl_source( async_fifo.v
  DEPENDS
    sync_reg )

add_hdl_source( async_fifo_flags.v
  DEPENDS
    sync_reg )

add_hdl_source( async_fifo_fwft.v
  DEPENDS
    async_fifo )

add_hdl_source( async_fifo_flags_fwft.v
  DEPENDS
    async_fifo_flags )

add_hdl_source( async_fifo_asymm_concat_fwft.v
  DEPENDS
    async_fifo_fwft)

add_hdl_source( async_fifo_asymm_split_fwft.v
  DEPENDS
    async_fifo_fwft)
