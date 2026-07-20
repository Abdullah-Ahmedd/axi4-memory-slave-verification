module axi_memory
#(
 parameter DATA_WIDTH = 32,
 parameter MEM_DEPTH = 1024,
 parameter MEM_ADDR_WIDTH = $clog2( MEM_DEPTH )  
)  
(
//Declaring inputs
	input logic ACLK,
	input logic ARESETn,
	input logic MEM_en,
	input logic MEM_we,
	input logic [ DATA_WIDTH - 1 : 0 ] MEM_wdata,
	input logic [ MEM_DEPTH - 1 : 0 ] MEM_addr,
//Declaring outputs
	output logic [ DATA_WIDTH - 1 : 0 ] MEM_rdata
);
//Declaring the internal memory 
logic [ DATA_WIDTH - 1 : 0 ] MEM [ 0: MEM_DEPTH - 1 ];

	always@( posedge ACLK )
		begin
			if( !ARESETn )
				begin
					MEM_rdata <= 0;
				end
			else 
				begin
					if( MEM_en )
						begin
							if( MEM_we )
								MEM[ MEM_addr ] <= MEM_wdata;
							else MEM_rdata <= MEM[ MEM_addr ];
						end
				end
		end

endmodule 