module axi_rd_channel#(
    parameter               P_WR_LENGTH         =   4096    ,
                            P_USER_DATA_WIDTH   =   16      ,
                            P_AXI_DATA_WIDTH    =   128     ,
                            P_AXI_ADDR_WIDTH    =   32      
)(
    input                                   i_user_clk                          ,
    input                                   i_axi_clk                           ,
    input                                   i_rst                               ,

    /*-------- AXI port --------*/
    output  		 					    o_axi_arvalid                       ,   // 1
	input    		 					    i_axi_arready                       , 
	output [P_AXI_ADDR_WIDTH-1:0] 		    o_axi_araddr                        ,   // 1
	output [ 7:0] 					        o_axi_arlen                         ,   // 1
	output [ 2:0] 					        o_axi_arsize                        ,   // 1
	output [ 1:0] 					        o_axi_arburst                       ,   // 1	
	output [ 3:0] 					        o_axi_arid                          ,   // 1 
	output  	  	 					    o_axi_arlock                        ,   // 1
	output [ 3:0] 					        o_axi_arcache                       ,   // 1
	output [ 2:0] 					        o_axi_arprot                        ,   // 1
	output [ 3:0] 					        o_axi_arqos                         ,   // 1

	input [ 3:0] 				            i_axi_rid                           ,   
	input [P_AXI_DATA_WIDTH-1:0]	        i_axi_rdata                         ,
	input [ 1:0] 				            i_axi_resp                          ,
	input      					            i_axi_rvalid                        ,
	input   						        i_axi_rlast                         ,
	output   						        o_axi_rready                        ,   // 1

    /*-------- USER port ---------*/
    output [P_USER_DATA_WIDTH - 1:0]        o_user_data                         ,   // 1
    output                                  o_user_valid                        ,   // 1
    output                                  o_user_last                         ,   // 1

    input                                   i_ddr_init                          ,   // ddr port

    input [P_AXI_ADDR_WIDTH - 1:0]          i_user_baddr                        ,
    input [P_AXI_ADDR_WIDTH - 1:0]          i_user_faddr                        ,
    input                                   i_user_valid                        ,   // it is be like a req not valid    ###!!!
    output                                  o_user_busy                             // because of maybe the fifo_cmd almost full so the input req will wait then send user it is busy
);


wire                          w_axi_u2a_rden    ;
wire [P_AXI_ADDR_WIDTH-1:0]   w_axi_u2a_addr    ;
wire [7:0]                    w_axi_u2a_length  ;
wire                          w_buffer_ready    ;


rd_ctrl#(
    .P_WR_LENGTH         (   P_WR_LENGTH        )  ,
    .P_USER_DATA_WIDTH   (   P_USER_DATA_WIDTH  )  ,
    .P_AXI_DATA_WIDTH    (   P_AXI_DATA_WIDTH   )  ,
    .P_AXI_ADDR_WIDTH    (   P_AXI_ADDR_WIDTH   )  
)
rd_ctrl_u0
(
    .i_user_clk                      (i_user_clk),
    .i_rst                           (i_rst),

    /*-------- DDR Port --------*/
    .i_ddr_init                      (i_ddr_init),
    
    /*-------- USER Port --------*/
    .i_user_req                      (i_user_valid),
    .i_user_baddr                    (i_user_baddr),
    .i_user_faddr                    (i_user_faddr),
    .o_user_busy                     (o_user_busy ),   // 1

    /*-------- AXI Port --------*/
    .o_axi_u2a_rden                  (w_axi_u2a_rden  ),   // 1
    .o_axi_u2a_addr                  (w_axi_u2a_addr  ),   // 1
    .o_axi_u2a_length                (w_axi_u2a_length),   // 1
    .i_buffer_ready                  (w_buffer_ready  )
);



rd_master#(
    .P_WR_LENGTH         (   P_WR_LENGTH        )    ,
    .P_USER_DATA_WIDTH   (   P_USER_DATA_WIDTH  )    ,
    .P_AXI_DATA_WIDTH    (   P_AXI_DATA_WIDTH   )    ,
    .P_AXI_ADDR_WIDTH    (   P_AXI_ADDR_WIDTH   )    
)
rd_master_u0
(
    .i_user_clk                      (i_user_clk),
    .i_axi_clk                       (i_axi_clk),
    .i_rst                           (i_rst),

    /*-------- USER Port --------*/
    .i_axi_u2a_rden                  (w_axi_u2a_rden  ), 
    .i_axi_u2a_addr                  (w_axi_u2a_addr  ), 
    .i_axi_u2a_length                (w_axi_u2a_length), 
    .o_buffer_ready                  (w_buffer_ready  ),   // 1

    .o_user_data                     (o_user_data ),   // 1
    .o_user_valid                    (o_user_valid),   // 1
    .o_user_last                     (o_user_last ),   // 1

    /*-------- AXI Port --------*/
    .o_axi_arvalid                   (o_axi_arvalid),   // 1
	.i_axi_arready                   (i_axi_arready), 
	.o_axi_araddr                    (o_axi_araddr ),   // 1
	.o_axi_arlen                     (o_axi_arlen  ),   // 1
	.o_axi_arsize                    (o_axi_arsize ),   // 1
	.o_axi_arburst                   (o_axi_arburst),   // 1
	.o_axi_arid                      (o_axi_arid   ),   // 1
	.o_axi_arlock                    (o_axi_arlock ),   // 1
	.o_axi_arcache                   (o_axi_arcache),   // 1
	.o_axi_arprot                    (o_axi_arprot ),   // 1
	.o_axi_arqos                     (o_axi_arqos  ),   // 1

	.i_axi_rid                       (i_axi_rid   ),
	.i_axi_rdata                     (i_axi_rdata ),
	.i_axi_resp                      (i_axi_resp  ),
	.i_axi_rvalid                    (i_axi_rvalid),
	.i_axi_rlast                     (i_axi_rlast ),
	.o_axi_rready                    (o_axi_rready)    // 1
);



endmodule
