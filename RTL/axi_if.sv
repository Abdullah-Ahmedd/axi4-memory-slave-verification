//////////////////////////////////////////////////////////////////////////////////////
//         Will include only the axi ports here                                     //
//         meaning the ports connected between the memory                           //    
//         and axi will be done using normal ports not                              //
//         using an inteface                                                        //
/////////////////////////////////////////////////////////////////////////////////////

interface axi_if
#(
parameter DATA_WIDTH = 32,
parameter ADDR_WIDTH = 16,
parameter LEN_WIDTH = 8,
parameter SIZE_WIDTH = 3
) 
(
  input logic ACLK,
  input logic ARRESETn
);
///////////////////////////////////////////
//          Signal declarations         //
//////////////////////////////////////////



  //1- Write address channel 
    logic [ ADDR_WIDTH - 1 : 0 ] AWADDR;
    logic [ LEN_WIDTH - 1 : 0 ] AWLEN;
    logic [ SIZE_WIDTH - 1 : 0 ] AWSIZE;
    logic AWVALID;
    logic AWREADY;



  //2- Write data channel
    logic [ DATA_WIDTH - 1 : 0 ] WDATA ;
    logic WLAST;
    logic WVALID;
    logic WREADY;


  // 3-Write responce channel
    logic [ 1 : 0 ] BRESP;
    logic BVALID;
    logic BREADY;



  //4-Read address channel
    logic [ ADDR_WIDTH - 1 : 0 ] ARADDR;
    logic [ LEN_WIDTH - 1 : 0 ] ARLEN;
    logic [ SIZE_WIDTH - 1 : 0 ] ARSIZE;
    logic ARVALID;
    logic ARREADY;    



 //5-Read data channel
  logic [ DATA_WIDTH - 1 : 0 ] RDATA;
  logic [ 1 : 0 ] RRESP;
  logic RLAST;
  logic RVALID;
  logic RREADY;






///////////////////////////////////////////
//               MODPORTS               //
//////////////////////////////////////////



//1- DUT MODPORT
modport slave_mp
(
  //clock and reset
    input ACLK,
    input ARRESETn,

  //1- Write address channel 
    input AWADDR,
    input AWLEN,
    input AWSIZE,
    input AWVALID,
    output AWREADY,



  //2- Write data channel
    input WDATA ,
    input WLAST,
    input WVALID,
    output WREADY,


  // 3-Write responce channel
    output BRESP,
    output BVALID,
    input BREADY,



  //4-Read address channel
    input ARADDR,
    input ARLEN,
    input ARSIZE,
    input ARVALID,
    output ARREADY,    



 //5-Read data channel
  output RDATA,
  output RRESP,
  output RLAST,
  output RVALID,
  input RREADY



);



//2- TB MODPORT
modport slave_tb_mp
(
  //clock and reset
    input ACLK,
    input ARRESETn,

  //1- Write address channel 
    output AWADDR,
    output AWLEN,
    output AWSIZE,
    output AWVALID,
    input AWREADY,



  //2- Write data channel
    output WDATA ,
    output WLAST,
    output WVALID,
    input WREADY,


  // 3-Write responce channel
    input BRESP,
    input BVALID,
    output BREADY,



  //4-Read address channel
    output ARADDR,
    output ARLEN,
    output ARSIZE,
    output ARVALID,
    input ARREADY,    



 //5-Read data channel
  input RDATA,
  input RRESP,
  input RLAST,
  input RVALID,
  output RREADY



);



//2- TB MODPORT
modport monitor_mp
(
  //clock and reset
    input ACLK,
    input ARRESETn,

  //1- Write address channel 
    input AWADDR,
    input AWLEN,
    input AWSIZE,
    input AWVALID,
    input AWREADY,



  //2- Write data channel
    input WDATA ,
    input WLAST,
    input WVALID,
    input WREADY,


  // 3-Write responce channel
    input BRESP,
    input BVALID,
    input BREADY,



  //4-Read address channel
    input ARADDR,
    input ARLEN,
    input ARSIZE,
    input ARVALID,
    input ARREADY,    



 //5-Read data channel
  input RDATA,
  input RRESP,
  input RLAST,
  input RVALID,
  input RREADY



);

 



endinterface
