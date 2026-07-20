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

  localparam OKAY =   2'b00;
  localparam SLVERR = 2'b01;

  ////////////////////////////////////////////////////////////////////////////////////////////////////
// First, determine how many bytes are in one word.
// Example: DATA_WIDTH = 32 bits.
// 32/8 = 4, so each word consists of 4 bytes.

// Next, compute how many bits are needed to represent the byte offset
// within a word. Since 4 bytes = 2^2 bytes,
// $clog2(4) = 2.

localparam int WORD_SHIFT = $clog2( DATA_WIDTH / 8 );

// WORD_SHIFT tells us how many bits to shift a BYTE ADDRESS to obtain
// the corresponding WORD ADDRESS.
//
// Example (32-bit word):
// Byte address : 00000100 (decimal 4)
// Word address = byte_address >> 2
//              = 00000001 (word index 1)
//
// The lower 2 address bits select the byte within the 32-bit word:
// Byte address 0 -> Word 0, Byte 0
// Byte address 1 -> Word 0, Byte 1
// Byte address 2 -> Word 0, Byte 2
// Byte address 3 -> Word 0, Byte 3
// Byte address 4 -> Word 1, Byte 0



//to sum up : word shift tell you the offset of the word meaning you increment your word address 
//every how many bytes
////////////////////////////////////////////////////////////////////////////////////////////////////

 ///////////////////////////////////////////
//          Boundary checkes             //
////////////////////////////////////////// 

//1- 4KB Boundary Check (returns 1 if true and 0 if false )
function automatic check_4KB( input logic [ ADDR_WIDTH - 1 : 0 ] addr ,input logic [ SIZE_WIDTH - 1 : 0 ] size ,input logic [ LEN_WIDTH - 1 : 0 ] len );// here we are checking if the burst size could be fitted in the page or no 
//Declaring local variables
    logic [ ADDR_WIDTH - 1 : 0 ] number_of_bytes;
    logic [ ADDR_WIDTH - 1 : 0 ] burst_length;
    logic [ ADDR_WIDTH - 1 : 0 ] total_transfer_size;
    logic [ ADDR_WIDTH - 1 : 0 ] current_page_offset;
    logic [ ADDR_WIDTH - 1 : 0 ] last_byte_address;



//Calculating the bytes per beat(transfer) 2^(size) (knew this rule from the table in page 10)
  number_of_bytes = 1 << size ;

//Calculating the total number of beats per burst
  burst_length = size + 1 ;

//Calculating the total transfered bytes per burst
  total_transfer_size = burst_length * number_of_bytes;

//4KB is 4 x 2^10 which is 4096 bytes so we need to check if the last  byte address is within 4096 or no
// 4096 in hexadecimal is 12'h1000
// every address consist of two parts 1) base address (the upper part of the address)(which tell you which 4KB block we are in)
//side note: now our memory is diveded into 4 kB blocks (name them pages)
// 2) the offset(the lower part of the address) (which tell us where are we in that 4KB block)
// since we care only about the offset as we want to make sure we are bounded in the 4KB and not above it
//we need to extract the offset part from the full address using an offset mask
//since the offset is 4096 this mean we need 12 bits 
//so to get the offset of the page we are in  we will mask 32'h00000_0FFF now we will get the last 12 bits as intended
current_page_offset = addr & 32'h0000_0ff; //where are we inside the page

//to get the address of the last byte we will add the current_page_offset to the total transfered bytes per burst
last_byte_address = current_page_offset + total_transfer_size; 

//now we can make the check to see if we return 1 or 0 
if( last_byte_address > 4096 )
  check_4KB = 0 ;
else check_4KB = 1;

endfunction


//2-Memory Range Check (returns 1 if true and 0 if false )
function automatic memory_range (input logic [ ADDR_WIDTH - 1 : 0 ] addr ,input logic [ SIZE_WIDTH - 1 : 0 ] size ,input logic [ LEN_WIDTH - 1 : 0 ] len);// here we are checking if the entire busrst could be fitted inside the memoery or not (inside the whole memory not just a page)
//local variables
  logic [ ADDR_WIDTH - 1 : 0 ] addr_in_words;
//Converting the address to be word address instead of byte address  
addr_in_words = addr>>WORD_SHIFT; //as given in page (addr is the starting address of the burst) but now converted in words

//since len repesent the length of the burst (meaning a burst consist of number of beats + 1 )
//addr_in_words + len mean the first address of the last beat in the burst
//also addr_in_words+2 mean the address starting address of the third beat
//if you are asking shouldnt we add the size of the last beat since maybe there wont be a place in the memory for it so the memory range is not enough
// it is because the beat size is 1 word so it is already included 
//how is that ?
// data size default is 32 --> this mean 32/8 =4 so each word is 4 bytes
//also it says bytes per beat = 2^size
//size default is 2 and 2^2 = 4 
// and as we said before 4 bytes is one word thats why beat size is 1 word 


  if(   (  ( addr_in_words + len )  < MEM_DEPTH   )  ) 
    memory_range = 1;
  else memory_range = 0;

endfunction 




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
