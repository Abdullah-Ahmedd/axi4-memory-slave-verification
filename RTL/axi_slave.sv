`include "axi_if.sv"
module axi_slave 
#(
parameter DATA_WIDTH = 32,
parameter ADDR_WIDTH = 16,
parameter LEN_WIDTH = 8,
parameter SIZE_WIDTH = 3,
 parameter MEM_DEPTH = 1024,
 parameter MEM_ADDR_WIDTH = $clog2( MEM_DEPTH )  
)
(
//Declaring the axi main ports using interface
  axi_if.slave.mp AXI,

//Declaring the axi_slave ==> axi_memory using normal ports 
//did this for the porject to be a mix of everything
	output logic MEM_en,
	output logic MEM_we,
	output logic [ DATA_WIDTH - 1 : 0 ] MEM_wdata,
	output logic [ MEM_DEPTH - 1 : 0 ] MEM_addr,
	input logic [ DATA_WIDTH - 1 : 0 ] MEM_rdata
);
///////////////////////////////////////////
//      Declaring internal signals       //
//////////////////////////////////////////

  localparam OKAY = 2'b00;
  localparam SLVERR =2'b01;
 




//////////////////////////////////////////////////////////////////////////////////////////////
//                                      WRITE FSM                                           //
//////////////////////////////////////////////////////////////////////////////////////////////
typedef enum logic [ 1 : 0 ]
{W_idle , W_address , W_data , BRESP }write_states;
write_states W_current_state ;
write_states W_next_state ;


//////////////////////////////////////////////////////////////////////////////////////////////
//                                      READ FSM                                            //
//////////////////////////////////////////////////////////////////////////////////////////////
typedef enum logic [ 1 : 0 ]
{R_idle , R_address , R_data }read_states;

read_states R_current_state ;
read_states R_next_state ;



endmodule
