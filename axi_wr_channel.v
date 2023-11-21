module axi_wr_channel#(
    parameter               P_WR_LENGTH         =   4096    ,
                            P_USER_DATA_WIDTH   =   16      ,
                            P_AXI_DATA_WIDTH    =   128     ,
                            P_AXI_ADDR_WIDTH    =   32      
)(
    input                               i_user_clk          ,
    input                               i_axi_clk           ,
    input                               i_rst               ,
    
    input                               i_ddr_init          ,

    input [P_USER_DATA_WIDTH - 1:0]     i_user_data         ,
    input [P_AXI_ADDR_WIDTH - 1:0]      i_user_baddr        ,   // got one clk but its in the begin of DATA_VALID
    input [P_AXI_ADDR_WIDTH - 1:0]      i_user_faddr        ,   // got one clk but its in the begin of DATA_VALID
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
    output [P_AXI_DATA_WIDTH/8-1:0] 	o_axi_wstrb         ,   // 1

    // write back
    input [3:0]	         	            i_axi_bid           ,
	input [1:0]	         	            i_axi_bresp         ,
	input   	   			         	i_axi_bvalid        ,
	output      			         	o_axi_bready            // 1 
);

wire [P_AXI_DATA_WIDTH-1:0]   w_axi_u2a_data        ;
wire                          w_axi_u2a_last        ;
wire                          w_axi_u2a_valid       ;

wire                          w_axi_wr_en           ;
wire [P_AXI_ADDR_WIDTH-1:0]   w_axi_wr_addr         ;
wire [7:0]                    w_axi_wr_length       ;

wr_ctrl#(
    .P_WR_LENGTH         (  P_WR_LENGTH        )  ,
    .P_USER_DATA_WIDTH   (  P_USER_DATA_WIDTH  )  ,
    .P_AXI_DATA_WIDTH    (  P_AXI_DATA_WIDTH   )  ,
    .P_AXI_ADDR_WIDTH    (  P_AXI_ADDR_WIDTH   )  
)
wr_ctrl_u0
(
    .i_user_clk              (i_user_clk),
    .i_user_rst              (i_rst),

    /*-------- DDR Port --------*/
    .i_ddr_init              (i_ddr_init),

    /*-------- USER Port --------*/
    .i_user_valid            (i_user_valid),
    .i_user_baddr            (i_user_baddr),
    .i_user_faddr            (i_user_faddr),
    .i_user_data             (i_user_data ),

    /*-------- AXI Port --------*/
    .o_axi_u2a_data          (w_axi_u2a_data ),   // 1
    .o_axi_u2a_last          (w_axi_u2a_last ),   // 1
    .o_axi_u2a_valid         (w_axi_u2a_valid),   // 1

    .o_axi_wr_en             (w_axi_wr_en    ),   // 1
    .o_axi_wr_addr           (w_axi_wr_addr  ),   // 1
    .o_axi_wr_length         (w_axi_wr_length)    // 1
);

wr_master#(
    .P_WR_LENGTH         (  P_WR_LENGTH        )  ,
    .P_USER_DATA_WIDTH   (  P_USER_DATA_WIDTH  )  ,
    .P_AXI_DATA_WIDTH    (  P_AXI_DATA_WIDTH   )  ,
    .P_AXI_ADDR_WIDTH    (  P_AXI_ADDR_WIDTH   )  
)
wr_master_u0
(
    .i_user_clk              (i_user_clk),
    .i_axi_clk               (i_axi_clk ),
    .i_rst                   (i_rst     ),

    /*-------- USER Port --------*/
    .i_axi_u2a_data          (w_axi_u2a_data ),   // 1
    .i_axi_u2a_last          (w_axi_u2a_last ),   // 1
    .i_axi_u2a_valid         (w_axi_u2a_valid),   // 1

    .i_axi_wr_en             (w_axi_wr_en    ),   // 1
    .i_axi_wr_addr           (w_axi_wr_addr  ),   // 1
    .i_axi_wr_length         (w_axi_wr_length),   // 1

    /*-------- AXI Port --------*/
    // write CMD
    .o_axi_awid              (o_axi_awid     ),   // 1
    .o_axi_aw_valid          (o_axi_aw_valid ),   // 1
    .o_axi_aw_addr           (o_axi_aw_addr  ),   // 1
    .o_axi_aw_length         (o_axi_aw_length),   // 1
    .o_axi_awsize            (o_axi_awsize   ),   // 1
    .o_axi_awburst           (o_axi_awburst  ),   // 1
    .i_axi_aw_ready          (i_axi_aw_ready ),

    .o_axi_awlock            (o_axi_awlock ),   // 1 
    .o_axi_awcache           (o_axi_awcache),   // 1
    .o_axi_awprot            (o_axi_awprot ),   // 1
    .o_axi_awqos             (o_axi_awqos  ),   // 1
    // write DATA   
    .o_axi_w_valid           (o_axi_w_valid),   // 1
    .o_axi_w_data            (o_axi_w_data ),   // 1
    .o_axi_w_last            (o_axi_w_last ),   // 1
    .i_axi_w_ready           (i_axi_w_ready),
    .o_axi_wstrb             (o_axi_wstrb  ),   // 1
    // write back   
    .i_axi_bid               (i_axi_bid   ),
    .i_axi_bresp             (i_axi_bresp ),
    .i_axi_bvalid            (i_axi_bvalid),   
    .o_axi_bready            (o_axi_bready)    // 1
);






endmodule
