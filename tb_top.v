`timescale 1ns/1ps

module tb_top();

reg wr_clk, rd_clk, axi_clk, rst, arst;

localparam              P_WR_LENGTH         =   4096    ,
                        P_USER_DATA_WIDTH   =   16      ,
                        P_AXI_DATA_WIDTH    =   128     ,
                        P_AXI_ADDR_WIDTH    =   32      ;

initial
begin
    rst = 1;
    #1000;
    rst = 0;
end

always
begin
    wr_clk = 0;
    #10;
    wr_clk = 1;
    #10;
end

always
begin
    rd_clk = 0;
    #5;
    rd_clk = 1;
    #5;
end

always
begin
    axi_clk = 0;
    #5;
    axi_clk = 1;
    #5;
end

reg rst_1d, rst_2d;
always@(posedge axi_clk)
begin
    rst_1d <= rst;
    rst_2d <= rst_1d;
    arst   <= ~rst_2d;
end


wire [P_USER_DATA_WIDTH-1:0]        w_user_data             ;
wire                                w_user_valid            ;
wire                                w_user_rdreq            ;
wire                                w_user_busy             ;

wire                                w_ddr_init = 'd1        ;

wire                                rsta_busy               ;
wire                                rstb_busy               ;

wire [3:0] 				 	        w_axi_awid              ;
wire                                w_axi_aw_valid          ;
wire [P_AXI_ADDR_WIDTH - 1:0]       w_axi_aw_addr           ;
wire [7:0]                          w_axi_aw_length         ;
wire [2:0] 				 	        w_axi_awsize            ;
wire [1:0] 				 	        w_axi_awburst           ;
wire                                w_axi_aw_ready          ;

wire 	  	 				 	    w_axi_awlock            ;
wire [3:0] 				 	        w_axi_awcache           ;
wire [2:0] 				 	        w_axi_awprot            ;
wire [3:0] 				 	        w_axi_awqos             ;

wire                                w_axi_w_valid           ;
wire [P_AXI_DATA_WIDTH - 1:0]       w_axi_w_data            ;
wire                                w_axi_w_last            ;
wire                                w_axi_w_ready           ;
wire [P_AXI_DATA_WIDTH/8-1:0]       w_axi_wstrb             ;

wire [3:0]	         	            w_axi_bid               ;
wire [1:0]	         	            w_axi_bresp             ;
wire   	   			                w_axi_bvalid            ;
wire       			                w_axi_bready            ;

wire [P_USER_DATA_WIDTH - 1:0]      o_user_data             ;
wire                                o_user_valid            ;
wire                                o_user_last             ;

wire  		 				        w_axi_arvalid           ;
wire   		 				        w_axi_arready           ;
wire [P_AXI_ADDR_WIDTH-1:0] 	    w_axi_araddr            ;
wire [ 7:0] 					    w_axi_arlen             ;
wire [ 2:0] 					    w_axi_arsize            ;
wire [ 1:0] 					    w_axi_arburst           ;
wire [ 3:0] 					    w_axi_arid              ;
wire  	  	 				        w_axi_arlock            ;
wire [ 3:0] 					    w_axi_arcache           ;
wire [ 2:0] 					    w_axi_arprot            ;
wire [ 3:0] 					    w_axi_arqos             ;

wire [ 3:0] 				        w_axi_rid               ;
wire [P_AXI_DATA_WIDTH-1:0]	        w_axi_rdata             ;
wire [ 1:0] 				        w_axi_resp              ;
wire      					        w_axi_rvalid            ;
wire   						        w_axi_rlast             ;
wire    						    w_axi_rready            ;

user_gen_module#(
    .P_WR_LENGTH         (P_WR_LENGTH      )  ,
    .P_USER_DATA_WIDTH   (P_USER_DATA_WIDTH)  ,
    .P_AXI_DATA_WIDTH    (P_AXI_DATA_WIDTH )  ,
    .P_AXI_ADDR_WIDTH    (P_AXI_ADDR_WIDTH )  
)
user_gen_module_u0
(
    .i_user_rdclk            (rd_clk),
    .i_user_wrclk            (wr_clk),
    .i_rst                   (rst   ),

    .o_user_data             (w_user_data ),
    .o_user_valid            (w_user_valid),

    .o_user_rdreq            (w_user_rdreq)
);

axi_top#(
    .P_WR_LENGTH         (P_WR_LENGTH      )  ,
    .P_USER_DATA_WIDTH   (P_USER_DATA_WIDTH)  ,
    .P_AXI_DATA_WIDTH    (P_AXI_DATA_WIDTH )  ,
    .P_AXI_ADDR_WIDTH    (P_AXI_ADDR_WIDTH )  
)
axi_top_u0
(
    .i_user_rdclk        (rd_clk            ),
    .i_user_wrclk        (wr_clk            ),
    .i_axi_clk           (axi_clk           ),
    .i_rst               (rst               ),
    
    .i_ddr_init          (w_ddr_init        ),
    
    .i_wuser_baddr       ('h0               ),   // got one clk but its in the begin of DATA_VALID
    .i_wuser_faddr       (32'h00014000      ),   // got one clk but its in the begin of DATA_VALID
    
    .i_ruser_baddr       ('h0               ),
    .i_ruser_faddr       (32'h00014000      ),

    /*---- wr ----*/
    .i_user_data         (w_user_data       ),
    .i_user_valid        (w_user_valid      ),

    // write CMD
    .o_axi_awid          (w_axi_awid        ),   // 1
    .o_axi_aw_valid      (w_axi_aw_valid    ),   // 1
    .o_axi_aw_addr       (w_axi_aw_addr     ),   // 1
    .o_axi_aw_length     (w_axi_aw_length   ),   // 1
    .o_axi_awsize        (w_axi_awsize      ),   // 1
    .o_axi_awburst       (w_axi_awburst     ),   // 1
    .i_axi_aw_ready      (w_axi_aw_ready    ),

    .o_axi_awlock        (w_axi_awlock      ),   // 1 
    .o_axi_awcache       (w_axi_awcache     ),   // 1
    .o_axi_awprot        (w_axi_awprot      ),   // 1
    .o_axi_awqos         (w_axi_awqos       ),   // 1
    // write DATA           
    .o_axi_w_valid       (w_axi_w_valid     ),   // 1
    .o_axi_w_data        (w_axi_w_data      ),   // 1
    .o_axi_w_last        (w_axi_w_last      ),   // 1
    .i_axi_w_ready       (w_axi_w_ready     ),
    .o_axi_wstrb         (w_axi_wstrb       ),   // 1
    // write back           
    .i_axi_bid           (w_axi_bid         ),
    .i_axi_bresp         (w_axi_bresp       ),
    .i_axi_bvalid        (w_axi_bvalid      ),   
    .o_axi_bready        (w_axi_bready      ),   // 1

    /*---- rd ----*/
    .o_user_data         (o_user_data       ),   // 1
    .o_user_valid        (o_user_valid      ),   // 1
    .o_user_last         (o_user_last       ),   // 1
    
    .i_user_req          (w_user_rdreq      ),   // it is be like a req not valid    ###!!!
    .o_user_busy         (w_user_busy       ), 

    .o_axi_arvalid       (w_axi_arvalid     ),   // 1
	.i_axi_arready       (w_axi_arready     ), 
	.o_axi_araddr        (w_axi_araddr      ),   // 1
	.o_axi_arlen         (w_axi_arlen       ),   // 1
	.o_axi_arsize        (w_axi_arsize      ),   // 1
	.o_axi_arburst       (w_axi_arburst     ),   // 1
	.o_axi_arid          (w_axi_arid        ),   // 1
	.o_axi_arlock        (w_axi_arlock      ),   // 1
	.o_axi_arcache       (w_axi_arcache     ),   // 1
	.o_axi_arprot        (w_axi_arprot      ),   // 1
	.o_axi_arqos         (w_axi_arqos       ),   // 1

	.i_axi_rid           (w_axi_rid         ),
	.i_axi_rdata         (w_axi_rdata       ),
	.i_axi_resp          (w_axi_resp        ),
	.i_axi_rvalid        (w_axi_rvalid      ),
	.i_axi_rlast         (w_axi_rlast       ),
	.o_axi_rready        (w_axi_rready      )    // 1

);

BRAM_AXI_TEST BRAM_AXI_TEST_u0 (
  .rsta_busy        (rsta_busy      ),          // output wire rsta_busy
  .rstb_busy        (rstb_busy      ),          // output wire rstb_busy
  .s_aclk           (axi_clk        ),                // input wire s_aclk
  .s_aresetn        (arst           ),          // input wire s_aresetn
  .s_axi_awid       (w_axi_awid     ),        // input wire [3 : 0] s_axi_awid
  .s_axi_awaddr     (w_axi_aw_addr  ),    // input wire [31 : 0] s_axi_awaddr
  .s_axi_awlen      (w_axi_aw_length),      // input wire [7 : 0] s_axi_awlen
  .s_axi_awsize     (w_axi_awsize   ),    // input wire [2 : 0] s_axi_awsize
  .s_axi_awburst    (w_axi_awburst  ),  // input wire [1 : 0] s_axi_awburst
  .s_axi_awvalid    (w_axi_aw_valid ),  // input wire s_axi_awvalid
  .s_axi_awready    (w_axi_aw_ready ),  // output wire s_axi_awready
  .s_axi_wdata      (w_axi_w_data   ),      // input wire [127 : 0] s_axi_wdata
  .s_axi_wstrb      (w_axi_wstrb    ),      // input wire [15 : 0] s_axi_wstrb
  .s_axi_wlast      (w_axi_w_last   ),      // input wire s_axi_wlast
  .s_axi_wvalid     (w_axi_w_valid  ),    // input wire s_axi_wvalid
  .s_axi_wready     (w_axi_w_ready  ),    // output wire s_axi_wready
  .s_axi_bid        (w_axi_bid      ),          // output wire [3 : 0] s_axi_bid
  .s_axi_bresp      (w_axi_bresp    ),      // output wire [1 : 0] s_axi_bresp
  .s_axi_bvalid     (w_axi_bvalid   ),    // output wire s_axi_bvalid
  .s_axi_bready     (w_axi_bready   ),    // input wire s_axi_bready
  .s_axi_arid       (w_axi_arid     ),        // input wire [3 : 0] s_axi_arid
  .s_axi_araddr     (w_axi_araddr   ),    // input wire [31 : 0] s_axi_araddr
  .s_axi_arlen      (w_axi_arlen    ),      // input wire [7 : 0] s_axi_arlen
  .s_axi_arsize     (w_axi_arsize   ),    // input wire [2 : 0] s_axi_arsize
  .s_axi_arburst    (w_axi_arburst  ),  // input wire [1 : 0] s_axi_arburst
  .s_axi_arvalid    (w_axi_arvalid  ),  // input wire s_axi_arvalid
  .s_axi_arready    (w_axi_arready  ),  // output wire s_axi_arready
  .s_axi_rid        (w_axi_rid      ),          // output wire [3 : 0] s_axi_rid
  .s_axi_rdata      (w_axi_rdata    ),      // output wire [127 : 0] s_axi_rdata
  .s_axi_rresp      (w_axi_resp     ),      // output wire [1 : 0] s_axi_rresp
  .s_axi_rlast      (w_axi_rlast    ),      // output wire s_axi_rlast
  .s_axi_rvalid     (w_axi_rvalid   ),    // output wire s_axi_rvalid
  .s_axi_rready     (w_axi_rready   )    // input wire s_axi_rready
);


endmodule
