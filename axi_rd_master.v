module axi_rd_master#(
    parameter               P_USER_DATA_WIDTH   =   16      ,
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

    /*-------- USER port --------*/
    output                                  o_axi_ready                         ,   // 1
    input [7:0]                             i_u2a_length                        ,
    input [P_AXI_ADDR_WIDTH - 1:0]          i_u2a_addr                          ,
    input                                   i_u2a_valid                         ,

    output [P_USER_DATA_WIDTH - 1:0]        o_user_data                         ,   // 1
    output                                  o_user_valid                        ,   // 1
    output                                  o_user_last                             // 1
);

assign                          o_axi_rready = 1'd1                 ;

always @(posedge axi_clk) begin
	o_axi_arid 		<= 4'd0;
	o_axi_arburst 	<= 2'b01;
	o_axi_arlock	<= 1'b0;
	o_axi_arcache 	<= 4'h0;
	o_axi_arprot 	<= 3'h0;
	o_axi_arqos 	<= 4'h0;
	o_axi_arsize 	<= 3'h4;
end

// sync
reg                             ri_rst_user                         ;
reg                             r_user_rst                          ;

reg                             ri_axi_rst                          ;
reg                             r_axi_rst                           ;

always@(posedge i_user_clk)
begin
    ri_rst_user <= i_clk;
    r_user_rst  <= ri_rst_user;
end

always@(posedge i_axi_clk)
begin
    ri_axi_rst <= i_rst     ;
    r_axi_rst  <= ri_axi_rst;
end

// CMD FIFO
reg                             r_cmd_wren                          ;
wire                            w_cmd_wren = o_axi_ready & i_u2a_valid;
always@(posedge i_user_clk or posedge r_user_rst)
begin
    if (r_user_rst)
        r_cmd_wren <= 'd0;
    else if (w_cmd_wren)
        r_cmd_wren <= 'd1;
    else
        r_cmd_wren <= 'd0;
end

reg [39:0]                      r_cmd_din                           ;
always@(posedge i_user_clk or posedge r_user_rst)
begin
    if (r_user_rst)
        r_cmd_din <= 'd0;
    else if (w_cmd_wren)
        r_cmd_din <= {i_u2a_length, i_u2a_addr};
    else
        r_cmd_din <= 'd0;
end

wire                            w_cmd_rden                          ;
wire [39:0]                     w_cmd_dout                          ;
wire                            w_cmd_full                          ;
wire                            w_cmd_empty                         ;
wire [3:0]                      w_cmd_rdcount                       ;
wire [3:0]                      w_cmd_wrcount                       ;
assign                          w_cmd_rden = r_st_current == P_ST_IDLE && r_st_next == P_ST_ARD;

assign                          o_axi_ready = r_user_rst ? 1'd0 : w_cmd_wrcount < 12 && ~w_cmd_full;

FIFO_COUNT_CMD_40X16 FIFO_COUNT_CMD_40X16_u0 (           // normal 
  .rst              (r_user_rst     ),                     
  .wr_clk           (i_user_clk     ),               
  .rd_clk           (i_axi_clk      ),               
  .din              (r_cmd_din      ),                     
  .wr_en            (r_cmd_wren     ),                 
  .rd_en            (w_cmd_rden     ),                 
  .dout             (w_cmd_dout     ),                   
  .full             (w_cmd_full     ),                   
  .empty            (w_cmd_empty    ),                 
  .rd_data_count    (w_cmd_rdcount  ), 
  .wr_data_count    (w_cmd_wrcount  ), 
  .wr_rst_busy      (),     
  .rd_rst_busy      ()      
);

// use fsm
localparam                      P_ST_IDLE   =   0                   ,
                                P_ST_ARD    =   1                   ,
                                P_ST_RD     =   2                   ,
                                P_ST_END    =   3                   ;

reg [7:0]                       r_st_current                        ;
reg [7:0]                       r_st_next                           ;

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
        P_ST_IDLE   :   r_st_next <= !w_cmd_empty && w_rd_ready ?   P_ST_ARD    :   P_ST_IDLE   ;
        P_ST_ARD    :   r_st_next <= o_axi_arvalid && i_axi_arready             ?   P_ST_RD     :   P_ST_ARD    ;
        P_ST_RD     :   r_st_next <= i_axi_rvalid && i_axi_rlast                ?   P_ST_END    :   P_ST_RD     ;
        P_ST_END    :   r_st_next <= P_ST_IDLE                  ;
        default     :   r_st_next <= P_ST_IDLE                  ;
    endcase
end


// DATA FIFO
reg [143:0]                     r_data_din                          ;
reg                             r_data_wren                         ;
always@(posedge i_axi_clk or posedge r_axi_rst)
begin
    if (r_axi_rst)
        r_data_din <= 'd0;
    else if (i_axi_rvalid)
        r_data_din <= {15'd0, i_axi_rlast, i_axi_rdata};
    else
        r_data_din <= r_data_din;
end

always@(posedge i_axi_clk or posedge r_axi_rst)
begin
    if (r_axi_rst)
        r_data_wren <= 'd0;
    else if (i_axi_rvalid)  
        r_data_wren <= 'd1;
    else
        r_data_wren <= 'd0;
end


wire [8:0]                      w_data_rdcount                      ;
wire [8:0]                      w_data_wrcount                      ;
wire [143:0]                    w_data_dout                         ;
wire                            w_data_full                         ;
wire                            w_data_empty                        ;

wire                            w_rd_ready                          ;
assign                          w_rd_ready = r_axi_rst ? 1'd0 : w_data_wrcount <= 128;

wire                            w_data_rden                         ;
assign                          w_data_rden = !w_data_empty && !r_data_rdcnt;

FIFO_COUNT_DATA_144X512 FIFO_COUNT_DATA_144X512_u0 (            // first 
  .rst              (r_axi_rst      ),                     
  .wr_clk           (i_axi_clk      ),               
  .rd_clk           (i_user_clk     ),               
  .din              (r_data_din     ),                     
  .wr_en            (r_data_wren    ),                 
  .rd_en            (w_data_rden    ),                 
  .dout             (w_data_dout    ),                   
  .full             (w_data_full    ),                   
  .empty            (w_data_empty   ),                 
  .rd_data_count    (w_data_rdcount ), 
  .wr_data_count    (w_data_wrcount ), 
  .wr_rst_busy      (),     
  .rd_rst_busy      ()      
);

// ctrl o_axi_avalid
reg                             ro_axi_arvalid                      ;
assign                          o_axi_arvalid = ro_axi_arvalid      ;
always@(posedge i_axi_clk or posedge r_axi_rst)
begin
    if (r_axi_rst)
        ro_axi_arvalid <= 'd0;
    else if (o_axi_arvalid && i_axi_arready)
        ro_axi_arvalid <= 'd0;
    else if (w_cmd_rden)
        ro_axi_arvalid <= 'd1;
    else
        ro_axi_arvalid <= 'd0;
end

// o_axi_araddr
assign                          o_axi_araddr = w_cmd_dout[P_AXI_ADDR_WIDTH - 1:0];
// o_axi_arlen
assign                          o_axi_arlen = w_cmd_dout[39:32]     ;

// shift cnt
reg [15:0]                      r_data_rdcnt                        ;
always@(posedge i_user_clk or posedge r_user_rst)
begin
    if (r_user_rst)
        r_data_rdcnt <= 'd0;
    else if (r_data_rdcnt == P_AXI_DATA_WIDTH/P_USER_DATA_WIDTH &&(w_data_rden || r_shift_valid))
        r_data_rdcnt <= 'd0;
    else if (w_data_rden || r_shift_valid)
        r_data_rdcnt <= r_data_rdcnt + 1;
    else    
        r_data_rdcnt <= r_data_rdcnt;
end

reg                             r_shift_valid                       ;
always@(posedge i_user_clk or posedge r_user_rst)
begin
    if (r_user_rst)
        r_shift_valid <= 'd0;
    else if (r_data_rdcnt == P_AXI_DATA_WIDTH/P_USER_DATA_WIDTH)
        r_shift_valid <= 'd0;
    else if (w_data_rden)
        r_shift_valid <= 'd1;
    else
        r_shift_valid <= r_shift_valid;
end

// o_user_data
wire [127:0]                    w_data                              ;
wire                            w_last                              ;
assign                          w_data = w_data_dout[127:0]         ;
assign                          w_last = w_data_dout[128]           ;
reg [127:0]                     r_shift_data                        ;

assign                          o_user_data = r_shift_data[15:0]    ;

always@(posedge i_user_clk or posedge r_user_rst)
begin
    if (r_user_rst)
        r_shift_data <= 'd0;
    else if (w_data_rden)
        r_shift_data <= w_data;
    else if (r_shift_valid)
        r_shift_data <= r_shift_data >> P_USER_DATA_WIDTH;
    else
        r_shift_data <= r_shift_data;
end

// o_user_last
reg                             ro_user_last                        ;
always@(posedge i_user_clk or posedge r_user_rst)
begin
    if (r_user_rst)
        ro_user_last <= 'd0;
    else if (w_last == 1 && r_shift_valid && r_data_rdcnt == P_AXI_DATA_WIDTH/P_USER_DATA_WIDTH)
        ro_user_last <= 'd1;
    else
        ro_user_last <= 'd0;
end

// o_user_valid
assign                          o_user_valid = r_shift_valid        ;





endmodule
