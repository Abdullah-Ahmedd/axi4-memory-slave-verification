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
  axi_if.slave_mp axi,

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
function automatic memory_range (input logic [ ADDR_WIDTH - 1 : 0 ] addr ,input logic [ LEN_WIDTH - 1 : 0 ] len);// here we are checking if the entire busrst could be fitted inside the memoery or not (inside the whole memory not just a page)
//local variables
  logic [ ADDR_WIDTH - 1 : 0 ] addr_in_words;
//Converting the address to be word address instead of byte address  
addr_in_words = addr >> WORD_SHIFT; //as given in page (addr is the starting address of the burst) but now converted in words

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
//enum for the states
  typedef enum logic [ 1 : 0 ]
    {W_idle , W_address , W_data , W_BRESP }write_states;
    write_states W_current_state ;
    write_states W_next_state ;
//internal registers
logic W_legal; //will and the return of both checking functions to make sure everything is okay 
logic [ ADDR_WIDTH - 1 : 0 ] W_current_address; //address
logic [ SIZE_WIDTH - 1 : 0 ] W_size_captured; //size



assign axi.AWREADY =1'b1; //"The slave sets AWREADY high when ready to accept the address. In our design it is set at one by default to improve timing efficiency."

//1---> state transition (Sequential always block)
always@(  posedge axi.ACLK  or  negedge axi.ARESETn )
  begin
    if( !axi.ARESETn )
        W_current_state <= W_idle;
    else 
        W_current_state <= W_next_state; 

  end

//2---> next state logic (Combinational always block)
always@( * )
  begin
 
    case( W_current_state )
      W_idle:
        begin
          if( axi.AWVALID )
            W_next_state = W_address;
          else W_next_state = W_idle;
        end
      W_address:
        begin
          if( axi.WVALID ) 
            W_next_state = W_data;
          else
            W_next_state = W_address;
        end
      W_data:
        begin
          if( axi.WVALID && axi.WREADY && axi.WLAST )
            W_next_state = W_BRESP;
          else W_next_state = W_data;
        end
      W_BRESP:
        begin
          if( axi.BREADY )
            W_next_state = W_idle;
          else W_next_state = W_BRESP;
        end
      default: W_next_state = W_idle;
    endcase
  end

//3---> output logic (Combinational always block)
always@( * )
begin
//Write Default values
axi.WREADY = 0;
axi.BRESP = OKAY ;
axi.BVALID = 0 ; 

  case( W_current_state )
    W_idle:
      begin
        axi.WREADY = 0;
        axi.BVALID = 0;
      end
    W_address:
      begin
        axi.WREADY = 0;
        axi.BVALID = 0;        
      end
    W_data:
      begin
        axi.WREADY = 1;
        axi.BVALID = 0;         
      end
    W_BRESP:
      begin
        axi.WREADY = 0;
        axi.BVALID = 1;
        if( W_legal )
             axi.BRESP = OKAY;
        else axi.BRESP = SLVERR;
      end
    default:
      begin
        axi.WREADY = 0;
        axi.BVALID = 0;  

      end
  endcase
end

//4---> Registered values ie. store for later (Sequential always block)
always@( posedge axi.ACLK  or  negedge axi.ARESETn )
  begin
    if( !axi.ARESETn )
      begin
        W_legal <= 0;
        W_current_address <= 0;
        W_size_captured <= 0;
      end
    else
      begin
    case( W_current_state )
      W_idle:
        begin
          if( axi.AWVALID )
            begin
              W_current_address <= axi.AWADDR ;
              W_size_captured <= axi.AWSIZE ;
              W_legal <= check_4KB(axi.AWADDR, axi.AWSIZE, axi.AWLEN) && memory_range(axi.AWADDR, axi.AWLEN);
            end
        end
      W_address:
        begin
          
        end
      W_data:
        begin
            if( axi.WVALID && axi.WREADY && !axi.WLAST )
              begin
                W_current_address <= W_current_address + ( 1 << W_size_captured );
              end
        end
      W_BRESP:
        begin

        end
    endcase
      end

  end



//////////////////////////////////////////////////////////////////////////////////////////////
//                                      READ FSM                                            //
//////////////////////////////////////////////////////////////////////////////////////////////
typedef enum logic [ 1 : 0 ]
{R_idle , R_address , R_data }read_states;

read_states R_current_state ;
read_states R_next_state ;

//internal registers
logic R_legal; 
logic [ LEN_WIDTH - 1 : 0 ] R_beats_remained; 
logic [ ADDR_WIDTH - 1 : 0 ] R_current_address;
logic [ SIZE_WIDTH - 1 : 0 ] R_size_captured;

//1---> state transition (Sequential always block)
always@(  posedge axi.ACLK  or  negedge axi.ARESETn )
  begin
    if( !axi.ARESETn )
        R_current_state <= R_idle;
    else 
        R_current_state <= R_next_state; 

  end

 //2---> next state logic (Combinational always block)
always@( * )
  begin
 
    case( R_current_state )
      R_idle:
        begin
          if( axi.ARVALID )
            R_next_state = R_address;
          else R_next_state = R_idle;
        end
      R_address:
        begin
            R_next_state = R_data;
        end
      R_data:
        begin
          if( axi.RVALID && axi.RREADY && axi.RLAST )
            R_next_state = R_idle;
          else R_next_state = R_data;
        end
      default: R_next_state = R_idle;   
    endcase

  end 

//3---> output logic (Combinational always block)
always@( * )
begin
//Write Default values
axi.ARREADY = 0 ;
axi.RDATA = 0 ;
axi.RRESP = OKAY;
axi.RLAST = 0 ;
axi.RVALID = 0 ;


  case( R_current_state )
    R_idle:
      begin
        axi.ARREADY = 1 ;
      end
    R_address:
      begin
        axi.ARREADY = 0 ;
      end
    R_data:
      begin
      axi.ARREADY = 0 ;
      axi.RVALID = 1 ;      
        if( !R_legal )
          begin
            axi.RRESP = SLVERR;
            if( R_beats_remained == 0 )
              axi.RLAST = 1 ;
            else 
              axi.RLAST = 0;
            axi.RDATA = 0;
          end
        else 
          begin
            axi.RRESP = OKAY;
              if( R_beats_remained == 0 )
                axi.RLAST = 1 ;
              else axi.RLAST = 0;
            axi.RDATA = MEM_rdata;            
          end        
      end
    default:
      begin
        axi.ARREADY = 0 ;
      end
  endcase
end


//4---> Registered values ie. store for later (Sequential always block)
always@( posedge axi.ACLK  or  negedge axi.ARESETn )
  begin
    if( !axi.ARESETn )
      begin
        R_legal <= 0;
        R_current_address <= 0;
        R_size_captured <= 0;
        R_beats_remained <= 0; 
      end
    else
      begin
    case( R_current_state )
      R_idle:
        begin
          if( axi.ARVALID )
            begin
              R_current_address <= axi.ARADDR ;
              R_size_captured <= axi.ARSIZE ;
              R_beats_remained <= axi.ARLEN;
              R_legal <= check_4KB(axi.ARADDR, axi.ARSIZE, axi.ARLEN) && memory_range(axi.ARADDR, axi.ARLEN);
            end
        end
      R_address:
        begin

        end
      R_data:
        begin
            if( axi.RVALID && axi.RREADY && !axi.RLAST )
              begin
                R_current_address <= R_current_address + ( 1 << R_size_captured ) ;
                R_beats_remained <= R_beats_remained - 1 ;
              end
        end
      default:
        begin

        end
    endcase
      end

  end

////////////////////////////////////////////////////////////////////////////////////////////////////
//                                   MEMORY ARBITRATION                                           //
////////////////////////////////////////////////////////////////////////////////////////////////////

always@( * )
  begin
    //Default values 
    MEM_en = 0;
    MEM_we = 0;
    MEM_wdata = 0;
    MEM_addr = 0;

    if(W_current_state == W_data && axi.WVALID && W_legal )
      begin
        MEM_we = 1;
        MEM_en = 1;
        MEM_addr = ( W_current_address >> WORD_SHIFT ); 
        MEM_wdata = axi.WDATA;
      end
    else if ( (R_current_state == R_address || R_current_state == R_data) && R_legal )
      begin
        MEM_we = 0;
        MEM_en = 1;
        if (R_current_state == R_address)
          MEM_addr = R_current_address >> WORD_SHIFT;
        else
          MEM_addr = (R_current_address + (axi.RVALID && axi.RREADY ? (1 << R_size_captured) : 0)) >> WORD_SHIFT;
      end
    
  end
endmodule