module wr_master#(
    parameter               P_WR_LENGTH         =   4096    ,
                            P_USER_DATA_WIDTH   =   16      ,
                            P_AXI_DATA_WIDTH    =   128     ,
                            P_AXI_ADDR_WIDTH    =   32      
)(
    input                           i_user_clk              ,
    input                           i_axi_clk               ,
    input                           i_rst                   ,

    /*-------- USER Port --------*/
    input [P_AXI_DATA_WIDTH-1:0]    i_axi_u2a_data          ,   // 1
    input                           i_axi_u2a_last          ,   // 1
    input                           i_axi_u2a_valid         ,   // 1

    input                           i_axi_wr_en             ,   // 1
    input [P_AXI_ADDR_WIDTH-1:0]    i_axi_wr_addr           ,   // 1
    input [7:0]                     i_axi_wr_length         ,   // 1

    /*-------- AXI Port --------*/
    // write CMD
    output [3:0] 				 	o_axi_awid              ,   // 1
    output                          o_axi_aw_valid          ,   // 1
    output [P_AXI_ADDR_WIDTH - 1:0] o_axi_aw_addr           ,   // 1
    output [7:0]                    o_axi_aw_length         ,   // 1
    output [2:0] 				 	o_axi_awsize            ,   // 1
    output [1:0] 				 	o_axi_awburst           ,   // 1
    input                           i_axi_aw_ready          ,

    output 	  	 				 	o_axi_awlock            ,   // 1 
    output [3:0] 				 	o_axi_awcache           ,   // 1
    output [2:0] 				 	o_axi_awprot            ,   // 1
    output [3:0] 				 	o_axi_awqos             ,   // 1
    // write DATA   
    output                          o_axi_w_valid           ,   // 1
    output [P_AXI_DATA_WIDTH - 1:0] o_axi_w_data            ,   // 1
    output                          o_axi_w_last            ,   // 1
    input                           i_axi_w_ready           ,
    output [P_AXI_DATA_WIDTH/8-1:0] o_axi_wstrb             ,   // 1
    // write back   
    input [3:0]	         	        i_axi_bid               ,
    input [1:0]	         	        i_axi_bresp             ,
    input   	   			        i_axi_bvalid            ,   
    output      			        o_axi_bready                // 1
);

assign                              o_axi_bready = 1'd1     ;

// sync RST
reg                                 ri_user_rst             ;
reg                                 ri_user_rst_1d          ;
reg                                 r_user_rst              ;

reg                                 ri_axi_rst              ;
reg                                 ri_axi_rst_1d           ;
reg                                 r_axi_rst               ;

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

// use a FIFO_CMD
reg [39:0]                          r_cmd_din               ;
reg                                 r_cmd_wren              ;
reg                                 r_cmd_rden              ;
wire [39:0]                         w_cmd_dout              ;
wire                                w_cmd_wrfull            ;
wire                                w_cmd_rdempty           ;
always@(posedge i_user_clk or posedge r_user_rst)
begin
    if (r_user_rst)
        r_cmd_din <= 'd0;
    else if (i_axi_wr_en)
        r_cmd_din <= {i_axi_wr_addr, i_axi_wr_length};
    else
        r_cmd_din <= r_cmd_din;
end

always@(posedge i_user_clk or posedge r_user_rst)
begin
    if (r_user_rst)
        r_cmd_wren <= 'd0;
    else if (i_axi_wr_en)
        r_cmd_wren <= 'd1;
    else
        r_cmd_wren <= 'd0;
end


always@(posedge i_axi_clk or posedge r_axi_rst)
begin
    if (r_axi_rst)
        r_cmd_rden <= 'd0;
    else if (r_st_current == P_ST_IDLE && r_st_next == P_ST_AW)
        r_cmd_rden <= 'd1;
    else
        r_cmd_rden <= 'd0;
end

FIFO_CMD_40X512 FIFO_CMD_FIRST (           // FIRST BRAM
  .rst      (r_user_rst     ),       
  .wr_clk   (i_user_clk     ), 
  .rd_clk   (i_axi_clk      ), 
  .din      (r_cmd_din      ),       
  .wr_en    (r_cmd_wren     ),   
  .rd_en    (r_cmd_rden     ),   
  .dout     (w_cmd_dout     ),     
  .full     (w_cmd_wrfull   ),     
  .empty    (w_cmd_rdempty  ),
  .wr_rst_busy(), 
  .rd_rst_busy()  
);


// use a FSM
localparam                          P_ST_IDLE   =   0       ,
                                    P_ST_AW     =   1       ,
                                    P_ST_W      =   2       ,
                                    P_ST_END    =   3       ;

reg [7:0]                           r_st_current            ;
reg [7:0]                           r_st_next               ;
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
        P_ST_IDLE   :   r_st_next <= !w_cmd_rdempty         ?   P_ST_AW     :   P_ST_IDLE   ;
        P_ST_AW     :   r_st_next <= o_axi_aw_valid && i_axi_aw_ready       ?   P_ST_W      :   P_ST_AW ;
        P_ST_W      :   r_st_next <= o_axi_w_valid && o_axi_w_last && i_axi_w_ready         ?   P_ST_END    :   P_ST_W  ;
        P_ST_END    :   r_st_next <= P_ST_IDLE              ;
        default     :   r_st_next <= P_ST_IDLE              ;
    endcase
end

// ctrl o_axi_aw_valid
reg                                 ro_axi_aw_valid         ;
assign                              o_axi_aw_valid = ro_axi_aw_valid;
always@(posedge i_axi_clk or posedge r_axi_rst)
begin
    if (r_axi_rst)
        ro_axi_aw_valid <= 'd0;
    else if (o_axi_aw_valid && i_axi_aw_ready)
        ro_axi_aw_valid <= 'd0;
    else if (r_cmd_rden)
        ro_axi_aw_valid <= 'd1;
    else
        ro_axi_aw_valid <= ro_axi_aw_valid;
end

// [P_AXI_ADDR_WIDTH - 1:0] o_axi_aw_addr
reg [P_AXI_ADDR_WIDTH - 1:0]        ro_axi_aw_addr          ;
assign                              o_axi_aw_addr = ro_axi_aw_addr;
always@(posedge i_axi_clk or posedge r_axi_rst)
begin
    if (r_axi_rst)
        ro_axi_aw_addr <= 'd0;
    else 
        ro_axi_aw_addr <= w_cmd_dout[39:8];
end

reg [7:0]                           ro_axi_aw_length        ;
assign                              o_axi_aw_length = ro_axi_aw_length;
always@(posedge i_axi_clk or posedge r_axi_rst)
begin
    if (r_axi_rst)
        ro_axi_aw_length <= 'd0;
    else
        ro_axi_aw_length <= w_cmd_dout[7:0];
end

// use FIFO_DATA
reg [143:0]                         r_data_din              ;
reg                                 r_data_wren             ;
wire                                w_data_rden             ;
wire [143:0]                        w_data_dout             ;
wire                                w_data_wrfull           ;
wire                                w_data_rdempty          ;

/**** we dont know if there will be a TIMEING PROBLEM. ****/
assign                              w_data_rden = (r_st_current == P_ST_AW && r_st_next == P_ST_W) || (o_axi_w_valid && !o_axi_w_last && i_axi_w_ready);
/**** we dont know if there will be a TIMEING PROBLEM. ****/
/**** it seems like it will not be a problem ****/

always@(posedge i_user_clk or posedge r_user_rst)
begin
    if (r_user_rst)
        r_data_din <= 'd0;
    else if (i_axi_u2a_valid)
        r_data_din <= {15'h0, i_axi_u2a_last, i_axi_u2a_data};
    else
        r_data_din <= r_data_din;
end

always@(posedge i_user_clk or posedge r_user_rst)
begin
    if (r_user_rst)
        r_data_wren <= 'd0;
    else if (i_axi_u2a_valid)
        r_data_wren <= 'd1;
    else
        r_data_wren <= 'd0;
end


//                          o_axi_w_valid
// [P_AXI_DATA_WIDTH - 1:0] o_axi_w_data 
//                          o_axi_w_last 
reg                                 ro_axi_w_valid          ;
assign                              o_axi_w_valid = ro_axi_w_valid;
always@(posedge i_axi_clk or posedge r_axi_rst)
begin
    if (r_axi_rst)
        ro_axi_w_valid <= 'd0;
    else if (o_axi_w_valid && o_axi_w_last && i_axi_w_ready)
        ro_axi_w_valid <= 'd0;
    else if (r_st_current == P_ST_AW && r_st_next == P_ST_W)
        ro_axi_w_valid <= 'd1;
    else    
        ro_axi_w_valid <= ro_axi_w_valid;
end 

reg [P_AXI_DATA_WIDTH - 1:0]        ro_axi_w_data           ;
assign                              o_axi_w_data = ro_axi_w_data;
always@(posedge i_axi_clk or posedge r_axi_rst)
begin
    if (r_axi_rst)
        ro_axi_w_data <= 'd0;
    else
        ro_axi_w_data <= w_data_dout[127:0];
end

reg                                 ro_axi_w_last           ;
assign                              o_axi_w_last = ro_axi_w_last;
always@(posedge i_axi_clk or posedge r_axi_rst)
begin
    if (r_axi_rst)
        ro_axi_w_last <= 'd0;
    else    
        ro_axi_w_last <= w_data_dout[128];
end

FIFO_DATA_144x512 FIFO_DATA_FIRST (          // FIRST-MODE BRAM
  .rst      (r_user_rst     ),       
  .wr_clk   (i_user_clk     ), 
  .rd_clk   (i_axi_clk      ), 
  .din      (r_data_din     ),       
  .wr_en    (r_data_wren    ),   
  .rd_en    (w_data_rden    ),   
  .dout     (w_data_dout    ),     
  .full     (w_data_wrfull  ),     
  .empty    (w_data_rdempty ),
  .wr_rst_busy(), 
  .rd_rst_busy()  
);

// others
reg [3:0]                       ro_axi_awid     ;	
reg [1:0]                       ro_axi_awburst  ;
reg                             ro_axi_awlock   ;
reg [3:0]                       ro_axi_awcache  ;
reg [2:0]                       ro_axi_awprot   ;
reg [3:0]                       ro_axi_awqos    ;
reg [P_AXI_DATA_WIDTH/8-1:0]    ro_axi_wstrb    ;
reg [2:0]                       ro_axi_awsize   ;
assign                          o_axi_awid    = ro_axi_awid   ;
assign                          o_axi_awburst = ro_axi_awburst;
assign                          o_axi_awlock  = ro_axi_awlock ;
assign                          o_axi_awcache = ro_axi_awcache;
assign                          o_axi_awprot  = ro_axi_awprot ;
assign                          o_axi_awqos   = ro_axi_awqos  ;
assign                          o_axi_wstrb   = ro_axi_wstrb  ;
assign                          o_axi_awsize  = ro_axi_awsize ;

always @(posedge i_axi_clk) begin
	ro_axi_awid 		<= 4'h0;
	ro_axi_awburst 	<= 2'b01;
	ro_axi_awlock	<= 1'b0;
	ro_axi_awcache 	<= 4'h0;
	ro_axi_awprot 	<= 3'h0;
	ro_axi_awqos 	<= 4'h0;
	ro_axi_wstrb     <= {P_AXI_DATA_WIDTH/8{1'b1}};
	ro_axi_awsize 	<= 3'h4;
end

endmodule
