module axi_top#(
    parameter               P_WR_LENGTH         =   4096    ,
                            P_USER_DATA_WIDTH   =   16      ,
                            P_AXI_DATA_WIDTH    =   128     ,
                            P_AXI_ADDR_WIDTH    =   32      
)(
    input                               i_user_rdclk        ,
    input                               i_user_wrclk        ,
    input                               i_axi_clk           ,
    input                               i_rst               ,

    input                               i_ddr_init          ,

    input [P_AXI_ADDR_WIDTH - 1:0]      i_wuser_baddr       ,   // got one clk but its in the begin of DATA_VALID
    input [P_AXI_ADDR_WIDTH - 1:0]      i_wuser_faddr       ,   // got one clk but its in the begin of DATA_VALID

    input [P_AXI_ADDR_WIDTH - 1:0]      i_ruser_baddr       ,
    input [P_AXI_ADDR_WIDTH - 1:0]      i_ruser_faddr       ,

    /*---- wr ----*/
    input [P_USER_DATA_WIDTH - 1:0]     i_user_data         ,
    input                               i_user_valid        ,

    // write CMD
    output [3:0] 				 	    o_axi_awid          ,   // 1
    output                              o_axi_aw_valid      ,   // 1
    output [P_AXI_ADDR_WIDTH - 1:0]     o_axi_aw_addr       ,   // 1
    output [7:0]                        o_axi_aw_length     ,   // 1
    output [2:0] 				 	    o_axi_awsize        ,   // 1
    output [1:0] 				 	    o_axi_awburst       ,   // 1
    input                               i_axi_aw_ready      ,

    output 	  	 				 	    o_axi_awlock        ,   // 1 
    output [3:0] 				 	    o_axi_awcache       ,   // 1
    output [2:0] 				 	    o_axi_awprot        ,   // 1
    output [3:0] 				 	    o_axi_awqos         ,   // 1
    // write DATA           
    output                              o_axi_w_valid       ,   // 1
    output [P_AXI_DATA_WIDTH - 1:0]     o_axi_w_data        ,   // 1
    output                              o_axi_w_last        ,   // 1
    input                               i_axi_w_ready       ,
    output [P_AXI_DATA_WIDTH/8-1:0]     o_axi_wstrb         ,   // 1
    // write back           
    input [3:0]	         	            i_axi_bid           ,
    input [1:0]	         	            i_axi_bresp         ,
    input   	   			            i_axi_bvalid        ,   
    output      			            o_axi_bready        ,   // 1

    /*---- rd ----*/
    output [P_USER_DATA_WIDTH - 1:0]    o_user_data         ,   // 1
    output                              o_user_valid        ,   // 1
    output                              o_user_last         ,   // 1
    
    input                               i_user_req          ,   // it is be like a req not valid    ###!!!
    output                              o_user_busy         , 

    output  		 				    o_axi_arvalid       ,   // 1
	input    		 				    i_axi_arready       , 
	output [P_AXI_ADDR_WIDTH-1:0] 	    o_axi_araddr        ,   // 1
	output [ 7:0] 					    o_axi_arlen         ,   // 1
	output [ 2:0] 					    o_axi_arsize        ,   // 1
	output [ 1:0] 					    o_axi_arburst       ,   // 1
	output [ 3:0] 					    o_axi_arid          ,   // 1
	output  	  	 				    o_axi_arlock        ,   // 1
	output [ 3:0] 					    o_axi_arcache       ,   // 1
	output [ 2:0] 					    o_axi_arprot        ,   // 1
	output [ 3:0] 					    o_axi_arqos         ,   // 1

	input [ 3:0] 				        i_axi_rid           ,
	input [P_AXI_DATA_WIDTH-1:0]	    i_axi_rdata         ,
	input [ 1:0] 				        i_axi_resp          ,
	input      					        i_axi_rvalid        ,
	input   						    i_axi_rlast         ,
	output   						    o_axi_rready            // 1

);

axi_rd_channel#(
    .P_WR_LENGTH         (  P_WR_LENGTH        )  ,
    .P_USER_DATA_WIDTH   (  P_USER_DATA_WIDTH  )  ,
    .P_AXI_DATA_WIDTH    (  P_AXI_DATA_WIDTH   )  ,
    .P_AXI_ADDR_WIDTH    (  P_AXI_ADDR_WIDTH   )  
)
axi_rd_channel_u0
(
    .i_user_clk          (i_user_rdclk  ),
    .i_axi_clk           (i_axi_clk     ),
    .i_rst               (i_rst         ),

    /*-------- AXI port --------*/
    .o_axi_arvalid       (o_axi_arvalid),   // 1
	.i_axi_arready       (i_axi_arready), 
	.o_axi_araddr        (o_axi_araddr ),   // 1
	.o_axi_arlen         (o_axi_arlen  ),   // 1
	.o_axi_arsize        (o_axi_arsize ),   // 1
	.o_axi_arburst       (o_axi_arburst),   // 1	
	.o_axi_arid          (o_axi_arid   ),   // 1 
	.o_axi_arlock        (o_axi_arlock ),   // 1
	.o_axi_arcache       (o_axi_arcache),   // 1
	.o_axi_arprot        (o_axi_arprot ),   // 1
	.o_axi_arqos         (o_axi_arqos  ),   // 1

	.i_axi_rid           (i_axi_rid   ),   
	.i_axi_rdata         (i_axi_rdata ),
	.i_axi_resp          (i_axi_resp  ),
	.i_axi_rvalid        (i_axi_rvalid),
	.i_axi_rlast         (i_axi_rlast ),
	.o_axi_rready        (o_axi_rready),   // 1

    /*-------- USER port ---------*/
    .o_user_data         (o_user_data ),   // 1
    .o_user_valid        (o_user_valid),   // 1
    .o_user_last         (o_user_last ),   // 1

    .i_ddr_init          (i_ddr_init  ),   // ddr port

    .i_user_baddr        (i_ruser_baddr),
    .i_user_faddr        (i_ruser_faddr),
    .i_user_valid        (i_user_req  ),   // it is be like a req not valid    ###!!!
    .o_user_busy         (o_user_busy )    // because of maybe the fifo_cmd almost full so the input req will wait then send user it is busy
);


axi_wr_channel#(
    .P_WR_LENGTH         (  P_WR_LENGTH        )  ,
    .P_USER_DATA_WIDTH   (  P_USER_DATA_WIDTH  )  ,
    .P_AXI_DATA_WIDTH    (  P_AXI_DATA_WIDTH   )  ,
    .P_AXI_ADDR_WIDTH    (  P_AXI_ADDR_WIDTH   )  
)
axi_wr_channel_u0
(
    .i_user_clk          (i_user_wrclk  ),
    .i_axi_clk           (i_axi_clk     ),
    .i_rst               (i_rst         ),
    
    .i_ddr_init          (i_ddr_init  ),

    .i_user_data         (i_user_data ),
    .i_user_baddr        (i_wuser_baddr),   // got one clk but its in the begin of DATA_VALID
    .i_user_faddr        (i_wuser_faddr),   // got one clk but its in the begin of DATA_VALID
    .i_user_valid        (i_user_valid),

    // write CMD
    .o_axi_awid          (o_axi_awid     ),   // 1
    .o_axi_aw_valid      (o_axi_aw_valid ),   // 1
    .o_axi_aw_addr       (o_axi_aw_addr  ),   // 1
    .o_axi_aw_length     (o_axi_aw_length),   // 1
    .o_axi_awsize        (o_axi_awsize   ),   // 1
    .o_axi_awburst       (o_axi_awburst  ),   // 1
    .i_axi_aw_ready      (i_axi_aw_ready ),
    
    .o_axi_awlock        (o_axi_awlock ),   // 1
	.o_axi_awcache       (o_axi_awcache),   // 1
	.o_axi_awprot        (o_axi_awprot ),   // 1
	.o_axi_awqos         (o_axi_awqos  ),   // 1

    // write DATA
    .o_axi_w_valid       (o_axi_w_valid),   // 1
    .o_axi_w_data        (o_axi_w_data ),   // 1
    .o_axi_w_last        (o_axi_w_last ),   // 1
    .i_axi_w_ready       (i_axi_w_ready),
    .o_axi_wstrb         (o_axi_wstrb  ),   // 1

    // write back
    .i_axi_bid           (i_axi_bid   ),
	.i_axi_bresp         (i_axi_bresp ),
	.i_axi_bvalid        (i_axi_bvalid),
	.o_axi_bready        (o_axi_bready)    // 1 
);


endmodule
