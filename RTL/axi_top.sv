`include "axi_if.sv"
`include "axi_memory.sv"
`include "axi_slave.sv"
module axi_top
#(
parameter DATA_WIDTH = 32,
parameter ADDR_WIDTH = 16,
parameter LEN_WIDTH = 8,
parameter SIZE_WIDTH = 3,
 parameter MEM_DEPTH = 1024,
 parameter MEM_ADDR_WIDTH = $clog2( MEM_DEPTH )  
)
(
axi_if.slave_mp intr
);
//Declaring internal signals
logic ACLK_internal;
logic ARESETn_internal;
logic MEM_en_internal;
logic MEM_we_internal;
logic [ DATA_WIDTH - 1 : 0 ] MEM_wdata_internal;
logic [ MEM_DEPTH - 1 : 0 ] MEM_addr_internal;
logic [ DATA_WIDTH - 1 : 0 ] MEM_rdata_internal;


axi_memory 
#(
.DATA_WIDTH ( DATA_WIDTH ),
.MEM_DEPTH  ( MEM_DEPTH ) 
)
MEMORY
(
.ACLK( intr.ACLK ),
.ARESETn( intr.ARESETn ),
.MEM_en( MEM_en_internal ),
.MEM_we( MEM_we_internal ),
.MEM_wdata( MEM_wdata_internal ),
.MEM_addr( MEM_addr_internal ),
.MEM_rdata( MEM_rdata_internal )
);

axi_slave 
#(
.DATA_WIDTH  ( DATA_WIDTH ),
.ADDR_WIDTH ( ADDR_WIDTH ),
.LEN_WIDTH ( LEN_WIDTH ),
.SIZE_WIDTH ( SIZE_WIDTH ),
.MEM_DEPTH ( MEM_DEPTH )
)
slave
(
.axi( intr ),
.MEM_en( MEM_en_internal ),
.MEM_we( MEM_we_internal ),
.MEM_wdata( MEM_wdata_internal ),
.MEM_addr( MEM_addr_internal ),
.MEM_rdata( MEM_rdata_internal )
);

endmodule 