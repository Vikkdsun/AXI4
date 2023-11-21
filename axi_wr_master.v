module axi_wr_master#(
    parameter               P_AXI_DATA_WIDTH    =   128     ,
                            P_AXI_ADDR_WIDTH    =   32      
)(
    input                               i_user_clk          ,
    input                               i_axi_clk           ,
    input                               i_rst               ,

    /*-------- from user_ctrl --------*/
    input                              i_u2a_en             ,
    input [P_AXI_DATA_WIDTH - 1:0]     i_u2a_data           ,
    input [P_AXI_ADDR_WIDTH - 1:0]     i_u2a_addr           ,
    input [7:0]                        i_u2a_length         ,
    input                              i_u2a_valid          ,
    input                              i_u2a_last           ,

    /*-------- to axi --------*/
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

// async 2 rst
reg                             ri_user_rst                 ;
reg                             r_rst_user                  ;
reg                             ri_axi_rst                  ;
reg                             r_rst_axi                   ;
always@(posedge i_user_clk)
begin
    ri_user_rst <= i_rst;
    r_rst_user  <= ri_user_rst;
end

always@(posedge i_axi_clk)
begin
    ri_axi_rst <= i_rst;
    r_rst_axi  <= ri_axi_rst;
end

// use asynchronous FIFO 
// #1: CMD_FIFO
reg [39:0]                      r_cmd_din                   ;
always@(posedge i_user_clk or posedge r_rst_user)
begin
    if (r_rst_user)
        r_cmd_din <= 'd0;
    else if (i_u2a_en)
        r_cmd_din <= {i_u2a_length, i_u2a_addr};
    else
        r_cmd_din <= r_cmd_din;
end

reg                             r_cmd_wren                  ;
always@(posedge i_user_clk or posedge r_rst_user)
begin
    if (r_rst_user)
        r_cmd_wren <= 'd0;
    else if (i_u2a_en)
        r_cmd_wren <= 'd1;
    else
        r_cmd_wren <= 'd0;
end

reg                             r_cmd_rden                  ;
wire [39:0]                     w_cmd_dout                  ;
wire                            w_cmd_full                  ;
wire                            w_cmd_empty                 ;
assign                          o_axi_aw_addr = w_cmd_dout[31:0]    ;
assign                          o_axi_aw_length = w_cmd_dout[39:32] ;
always@(posedge i_axi_clk or posedge r_rst_axi)
begin
    if (r_rst_axi)
        r_cmd_rden <= 'd0;
    else if (r_st_current == P_ST_IDLE && r_st_next == P_ST_AW)
        r_cmd_rden <= 'd1;
    else
        r_cmd_rden <= 'd0;
end

FIFO_CMD_40X512 FIFO_CMD_NORMAL (           // NORMAL BRAM
  .rst      (r_rst_user ),       
  .wr_clk   (i_user_clk ), 
  .rd_clk   (i_axi_clk  ), 
  .din      (r_cmd_din  ),       
  .wr_en    (r_cmd_wren ),   
  .rd_en    (r_cmd_rden ),   
  .dout     (w_cmd_dout ),     
  .full     (w_cmd_full ),     
  .empty    (w_cmd_empty),
  .wr_rst_busy(), 
  .rd_rst_busy()  
);

// #2: DATA_FIFO
reg [143:0]                     r_data_din                  ;
always@(posedge i_user_clk or posedge r_rst_user)
begin
    if (r_rst_user)
        r_data_din <= 'd0;
    else if (i_u2a_valid)  
        r_data_din <= {15'h0, i_u2a_data, i_u2a_last};
    else
        r_data_din <= r_data_din;
end

reg                             r_data_wren                 ;
always@(posedge i_user_clk or posedge r_rst_user)
begin
    if (r_rst_user)
        r_data_wren <= 'd0;
    else if (i_u2a_valid)
        r_data_wren <= 'd1;
    else
        r_data_wren <= 'd0;
end

wire [143:0]                    w_data_dout                 ;
reg                             r_data_rden                 ;
wire                            w_data_full                 ;
wire                            w_data_empty                ;
assign                          o_axi_w_data = w_data_dout[128:1]   ;
assign                          o_axi_w_last = w_data_dout[0]       ;
always@(posedge i_axi_clk or posedge r_rst_axi)
begin
    if (r_rst_axi)
        r_data_rden <= 'd0;
    else if (r_st_current == P_ST_AW && r_st_next == P_ST_W)
        r_data_rden <= 'd1;
    else if (o_axi_w_valid && i_axi_w_ready && !o_axi_w_last)
        r_data_rden <= 'd0;
    else
        r_data_rden <= 'd0;
end


FIFO_DATA_144x512 FIFO_DATA_FIRST (          // FIRST-MODE BRAM
  .rst      (r_rst_user     ),       
  .wr_clk   (i_user_clk     ), 
  .rd_clk   (i_axi_clk      ), 
  .din      (r_data_din     ),       
  .wr_en    (r_data_wren    ),   
  .rd_en    (r_data_rden    ),   
  .dout     (w_data_dout    ),     
  .full     (w_data_full    ),     
  .empty    (w_data_empty   ),
  .wr_rst_busy(), 
  .rd_rst_busy()  
);



// use lsm
localparam                      P_ST_IDLE   =   0           ,
                                P_ST_AW     =   1           ,
                                P_ST_W      =   2           ,
                                P_ST_END    =   3           ;

reg [7:0]                       r_st_current                ;
reg [7:0]                       r_st_next                   ;
always@(posedge i_axi_clk or posedge r_rst_axi)
begin
    if (r_rst_axi)
        r_st_current <= P_ST_IDLE;
    else 
        r_st_current <= r_st_next;
end

always@(*)
begin
    case(r_st_current)
        P_ST_IDLE   :   r_st_next <= !w_cmd_empty   ?   P_ST_AW :   P_ST_IDLE       ;
        P_ST_AW     :   r_st_next <= o_axi_aw_valid && i_axi_aw_ready               ?   P_ST_W      :   P_ST_AW ;
        P_ST_W      :   r_st_next <= o_axi_w_valid && i_axi_w_ready && o_axi_w_last ?   P_ST_END    :   P_ST_W  ;
        P_ST_END    :   r_st_next <= P_ST_IDLE      ;
        default     :   r_st_next <= P_ST_IDLE      ;
    endcase
end

// ctrl 2 valid
reg                             ro_axi_aw_valid             ;
reg                             ro_axi_w_valid              ;
assign                          o_axi_aw_valid = ro_axi_aw_valid;
assign                          o_axi_w_valid  = ro_axi_w_valid ;
always@(posedge i_axi_clk or posedge r_rst_axi)
begin
    if (r_rst_axi)      
        ro_axi_aw_valid <= 'd0;
    else if (o_axi_aw_valid && i_axi_aw_ready)  
        ro_axi_aw_valid <= 'd0;
    else if (r_cmd_rden)
        ro_axi_aw_valid <= 'd1;
    else
        ro_axi_aw_valid <= ro_axi_aw_valid;
end

always@(posedge i_axi_clk or posedge r_rst_axi)
begin
    if (r_rst_axi)
        ro_axi_w_valid <= 'd0;
    else if (o_axi_w_valid && i_axi_w_ready && o_axi_w_last)
        ro_axi_w_valid <= 'd0;
    else if (r_st_current == P_ST_AW && r_st_next == P_ST_W)
        ro_axi_w_valid <= 'd1;
    else
        ro_axi_w_valid <= ro_axi_w_valid;
end

// ctrl READY
assign                          o_axi_bready = 'd1          ; 

always @(posedge axi_clk) begin
	o_axi_awid 		<= 4'h0;
	o_axi_awburst 	<= 2'b01;
	o_axi_awlock	<= 1'b0;
	o_axi_awcache 	<= 4'h0;
	o_axi_awprot 	<= 3'h0;
	o_axi_awqos 	<= 4'h0;
	o_axi_wstrb     <= {AXI_DATA_WIDTH/8{1'b1}};
	o_axi_awsize 	<= 3'h4;
end

endmodule
