module rd_master#(
    parameter               P_WR_LENGTH         =   4096    ,
                            P_USER_DATA_WIDTH   =   16      ,
                            P_AXI_DATA_WIDTH    =   128     ,
                            P_AXI_ADDR_WIDTH    =   32      
)(
    input                           i_user_clk                      ,
    input                           i_axi_clk                       ,
    input                           i_rst                           ,

    /*-------- USER Port --------*/
    input                           i_axi_u2a_rden                  , 
    input [P_AXI_ADDR_WIDTH-1:0]    i_axi_u2a_addr                  , 
    input [7:0]                     i_axi_u2a_length                , 
    output                          o_buffer_ready                  ,   // 1

    output [P_USER_DATA_WIDTH-1:0]  o_user_data                     ,   // 1
    output                          o_user_valid                    ,   // 1
    output                          o_user_last                     ,   // 1

    /*-------- AXI Port --------*/
    output  		 				o_axi_arvalid                   ,   // 1
	input    		 				i_axi_arready                   , 
	output [P_AXI_ADDR_WIDTH-1:0] 	o_axi_araddr                    ,   // 1
	output [ 7:0] 					o_axi_arlen                     ,   // 1
	output [ 2:0] 					o_axi_arsize                    ,   // 1
	output [ 1:0] 					o_axi_arburst                   ,   // 1
	output [ 3:0] 					o_axi_arid                      ,   // 1
	output  	  	 				o_axi_arlock                    ,   // 1
	output [ 3:0] 					o_axi_arcache                   ,   // 1
	output [ 2:0] 					o_axi_arprot                    ,   // 1
	output [ 3:0] 					o_axi_arqos                     ,   // 1

	input [ 3:0] 				    i_axi_rid                       ,
	input [P_AXI_DATA_WIDTH-1:0]	i_axi_rdata                     ,
	input [ 1:0] 				    i_axi_resp                      ,
	input      					    i_axi_rvalid                    ,
	input   						i_axi_rlast                     ,
	output   						o_axi_rready                        // 1
);

localparam                          P_SHIFT_MAX = P_AXI_DATA_WIDTH/P_USER_DATA_WIDTH;

assign                              o_axi_rready = 1'd1             ;

reg [3:0]                       ro_axi_arid     ;	
reg [1:0]                       ro_axi_arburst  ;
reg                             ro_axi_arlock   ;
reg [3:0]                       ro_axi_arcache  ;
reg [2:0]                       ro_axi_arprot   ;
reg [3:0]                       ro_axi_arqos    ;
reg [2:0]                       ro_axi_arsize   ;
assign                          o_axi_arid    = ro_axi_arid   ;
assign                          o_axi_arburst = ro_axi_arburst;
assign                          o_axi_arlock  = ro_axi_arlock ;
assign                          o_axi_arcache = ro_axi_arcache;
assign                          o_axi_arprot  = ro_axi_arprot ;
assign                          o_axi_arqos   = ro_axi_arqos  ;
assign                          o_axi_arsize  = ro_axi_arsize ;

always @(posedge i_axi_clk) begin
	ro_axi_arid   	<= 4'd0;
	ro_axi_arburst 	<= 2'b01;
	ro_axi_arlock 	<= 1'b0;
	ro_axi_arcache 	<= 4'h0;
	ro_axi_arprot 	<= 3'h0;
	ro_axi_arqos  	<= 4'h0;
	ro_axi_arsize 	<= 3'h4;
end

// sync RST
reg                                 ri_user_rst                     ;
reg                                 ri_user_rst_1d                  ;
reg                                 r_user_rst                      ;

reg                                 ri_axi_rst                      ;
reg                                 ri_axi_rst_1d                   ;
reg                                 r_axi_rst                       ;

always@(posedge i_user_clk)
begin
    ri_user_rst    <= i_rst;
    ri_user_rst_1d <= ri_user_rst;
    r_user_rst     <= ri_user_rst_1d;
end

always@(posedge i_axi_clk)
begin
    ri_axi_rst    <= i_rst;
    ri_axi_rst_1d <= ri_axi_rst;
    r_axi_rst     <= ri_axi_rst_1d;
end

// o_buffer_ready
assign                              o_buffer_ready = r_user_rst ?   'd0 :   w_cmd_wrcount<12 && !w_cmd_wrfull;

// use a CMD_FIFO and a DATA_FIFO
reg [39:0]                          r_cmd_din                       ;
always@(posedge i_user_clk or posedge r_user_rst)
begin
    if (r_user_rst)
        r_cmd_din <= 'd0;
    else if (i_axi_u2a_rden && o_buffer_ready)
        r_cmd_din <= {i_axi_u2a_addr, i_axi_u2a_length};
    else
        r_cmd_din <= r_cmd_din;
end

reg                                 r_cmd_wren                      ;
always@(posedge i_user_clk or posedge r_user_rst)
begin
    if (r_user_rst)
        r_cmd_wren <= 'd0;
    else if (i_axi_u2a_rden && o_buffer_ready)
        r_cmd_wren <= 'd1;
    else    
        r_cmd_wren <= 'd0;
end

wire                                w_cmd_rden                      ;
assign                              w_cmd_rden = r_st_current == P_ST_IDLE && r_st_next == P_ST_ARD;

wire [39:0]                         w_cmd_dout                      ;

wire                                w_cmd_wrfull                    ;
wire                                w_cmd_rdempty                   ;
wire [3:0]                          w_cmd_rdcount                   ;
wire [3:0]                          w_cmd_wrcount                   ;

FIFO_COUNT_CMD_40X16 FIFO_COUNT_CMD_40X16_u0 (           // FIRST
  .rst              (r_user_rst     ),                     
  .wr_clk           (i_user_clk     ),               
  .rd_clk           (i_axi_clk      ),               
  .din              (r_cmd_din      ),                     
  .wr_en            (r_cmd_wren     ),                 
  .rd_en            (w_cmd_rden     ),                 
  .dout             (w_cmd_dout     ),                   
  .full             (w_cmd_wrfull   ),                   
  .empty            (w_cmd_rdempty  ),                 
  .rd_data_count    (w_cmd_rdcount  ), 
  .wr_data_count    (w_cmd_wrcount  ), 
  .wr_rst_busy      (),     
  .rd_rst_busy      ()      
);



reg [143:0]                         r_data_din                      ;
always@(posedge i_axi_clk or posedge r_axi_rst)
begin
    if (r_axi_rst)
        r_data_din <= 'd0;
    else if (i_axi_rvalid && o_axi_rready)
        r_data_din <= {15'h0, i_axi_rlast, i_axi_rdata};
    else
        r_data_din <= r_data_din;
end

reg                                 r_data_wren                     ;
always@(posedge i_axi_clk or posedge r_axi_rst)
begin
    if (r_axi_rst)
        r_data_wren <= 'd0;
    else if (i_axi_rvalid && o_axi_rready)
        r_data_wren <= 'd1;
    else
        r_data_wren <= 'd0;
end

wire                                w_data_rden                     ;
assign                              w_data_rden = !w_data_rdempty && !r_shift_cnt;
wire                                w_data_wrfull                   ;
wire                                w_data_rdempty                  ;
wire [8:0]                          w_data_rdcount                  ;
wire [8:0]                          w_data_wrcount                  ;
wire [143:0]                        w_data_dout                     ;


reg [7:0]                           r_shift_cnt                     ;
always@(posedge i_user_clk or posedge r_user_rst)
begin
    if (r_user_rst)
        r_shift_cnt <= 'd0;
    else if (r_shift_cnt == P_SHIFT_MAX-1 && (w_data_rden || r_shift_valid))
        r_shift_cnt <= 'd0;
    else if (w_data_rden || r_shift_valid)
        r_shift_cnt <= r_shift_cnt + 1;
    else
        r_shift_cnt <= r_shift_cnt;
end

reg                                 r_shift_valid                   ;
always@(posedge i_user_clk or posedge r_user_rst)
begin
    if (r_user_rst)
        r_shift_valid <= 'd0;
    else if (r_shift_cnt == P_SHIFT_MAX-1)
        r_shift_valid <= 'd0;
    else if (w_data_rden)
        r_shift_valid <= 'd1;
    else
        r_shift_valid <= r_shift_valid;
end

FIFO_COUNT_DATA_144X512 FIFO_COUNT_DATA_144X512_u0 (            // first 
  .rst              (r_axi_rst      ),                     
  .wr_clk           (i_axi_clk      ),               
  .rd_clk           (i_user_clk     ),               
  .din              (r_data_din     ),                     
  .wr_en            (r_data_wren    ),                 
  .rd_en            (w_data_rden    ),                 
  .dout             (w_data_dout    ),                   
  .full             (w_data_wrfull  ),                   
  .empty            (w_data_rdempty ),                 
  .rd_data_count    (w_data_rdcount ), 
  .wr_data_count    (w_data_wrcount ), 
  .wr_rst_busy      (),     
  .rd_rst_busy      ()      
);

reg                                 r_dout_last                     ;
always@(posedge i_user_clk or posedge r_user_rst)
begin
    if (r_user_rst)
        r_dout_last <= 'd0;
    else if (w_data_rden)
        r_dout_last <= w_data_dout[128];
    else
        r_dout_last <= r_dout_last;
end


// use a signal to make sure the DATA_FIFO wont be full 
wire                                w_data_fifo_ready               ;
/**** the ready will be used with cmd_empty which used in AXI_CLK (and FSM is used in AXI_CLK) ****/
assign                              w_data_fifo_ready = r_axi_rst   ?   'd0 :   w_data_wrcount<=128;

// use FSM
localparam                          P_ST_IDLE   =   0               ,
                                    P_ST_ARD    =   1               ,
                                    P_ST_RD     =   2               ,
                                    P_ST_END    =   3               ;

reg [7:0]                           r_st_current                    ;
reg [7:0]                           r_st_next                       ;

always@(posedge i_axi_clk or posedge r_axi_rst)
begin
    if (r_axi_rst)
        r_st_current <= P_ST_IDLE;
    else 
        r_st_current <= r_st_next;
end

always@(*)
begin
    case(r_st_current)
        P_ST_IDLE   :   r_st_next <= !w_cmd_rdempty && w_data_fifo_ready    ?   P_ST_ARD    :   P_ST_IDLE   ;
        P_ST_ARD    :   r_st_next <= o_axi_arvalid && i_axi_arready         ?   P_ST_RD     :   P_ST_ARD    ;
        P_ST_RD     :   r_st_next <= i_axi_rvalid && i_axi_rlast && o_axi_rready            ?   P_ST_END    :   P_ST_RD ;
        P_ST_END    :   r_st_next <= P_ST_IDLE                              ;
        default     :   r_st_next <= P_ST_IDLE                              ;
    endcase 
end

// o_axi_arvalid
reg                                 ro_axi_arvalid                  ;
assign                              o_axi_arvalid = ro_axi_arvalid  ;
always@(posedge i_axi_clk or posedge r_axi_rst)
begin
    if (r_axi_rst)
        ro_axi_arvalid <= 'd0;
    else if (o_axi_arvalid && i_axi_arready)
        ro_axi_arvalid <= 'd0;
    else if (w_cmd_rden)
        ro_axi_arvalid <= 'd1;
    else
        ro_axi_arvalid <= ro_axi_arvalid;
end

// [P_AXI_ADDR_WIDTH-1:0] 	o_axi_araddr
// [ 7:0] 					o_axi_arlen 
reg [P_AXI_ADDR_WIDTH-1:0] 	        ro_axi_araddr                   ;
reg [ 7:0] 					        ro_axi_arlen                    ;
assign                              o_axi_araddr = ro_axi_araddr    ;
assign                              o_axi_arlen  = ro_axi_arlen     ;
always@(posedge i_axi_clk or posedge r_axi_rst)
begin
    if (r_axi_rst)
        ro_axi_araddr <= 'd0;
    else if (w_cmd_rden)
        ro_axi_araddr <= w_cmd_dout[39:8];
    else        
        ro_axi_araddr <= ro_axi_araddr;
end

always@(posedge i_axi_clk or posedge r_axi_rst)
begin
    if (r_axi_rst)
        ro_axi_arlen <= 'd0;
    else if (w_cmd_rden)
        ro_axi_arlen <= w_cmd_dout[7:0];
    else
        ro_axi_arlen <= ro_axi_arlen;
end

// [P_USER_DATA_WIDTH-1:0]  o_user_data  
//                          o_user_valid 
//                          o_user_last  
reg [P_USER_DATA_WIDTH-1:0]         ro_user_data                    ;
assign                              o_user_data = ro_user_data      ;
reg [P_AXI_DATA_WIDTH-1:0]          r_shift_data                    ;
always@(posedge i_user_clk or posedge r_user_rst)
begin
    if (r_user_rst)
        r_shift_data <= 'd0;
    else if (w_data_rden)
        r_shift_data <= w_data_dout[127:0];
    else if (r_shift_valid)
        r_shift_data <= r_shift_data >> P_USER_DATA_WIDTH;
    else
        r_shift_data <= r_shift_data;
end

reg                                 r_valid_pre                     ;
always@(posedge i_user_clk or posedge r_user_rst)
begin
    if (r_user_rst)
        r_valid_pre <= 'd0;
    else if (w_data_rden || r_shift_valid)
        r_valid_pre <= 'd1;
    else 
        r_valid_pre <= 'd0;
end

reg                                 r_last_pre                      ;
always@(posedge i_user_clk or posedge r_user_rst)
begin
    if (r_user_rst)
        r_last_pre <= 'd0;
    else if (r_shift_valid && r_dout_last && r_shift_cnt == P_SHIFT_MAX-1)
        r_last_pre <= 'd1;
    else
        r_last_pre <= 'd0;
end

always@(posedge i_user_clk or posedge r_user_rst)
begin
    if (r_user_rst)
        ro_user_data <= 'd0;
    else if (r_valid_pre)
        ro_user_data <= r_shift_data[P_USER_DATA_WIDTH-1:0];
    else    
        ro_user_data <= ro_user_data;
end

reg                                 ro_user_valid                   ;
assign                              o_user_valid = ro_user_valid    ;
always@(posedge i_user_clk or posedge r_user_rst)
begin
    if (r_user_rst)     
        ro_user_valid <= 'd0;
    else if (r_valid_pre)      
        ro_user_valid <= 'd1;
    else
        ro_user_valid <= 'd0;
end

reg                                 ro_user_last                    ;
assign                              o_user_last = ro_user_last      ;
always@(posedge i_user_clk or posedge r_user_rst)
begin
    if (r_user_rst)
        ro_user_last <= 'd0;
    else if (r_valid_pre)
        ro_user_last <= r_last_pre;
    else
        ro_user_last <= 'd0;
end




endmodule
