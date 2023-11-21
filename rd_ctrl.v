module rd_ctrl#(
    parameter               P_WR_LENGTH         =   4096    ,
                            P_USER_DATA_WIDTH   =   16      ,
                            P_AXI_DATA_WIDTH    =   128     ,
                            P_AXI_ADDR_WIDTH    =   32      
)(
    input                           i_user_clk                      ,
    input                           i_rst                           ,

    /*-------- DDR Port --------*/
    input                           i_ddr_init                      ,
    
    /*-------- USER Port --------*/
    input                           i_user_req                      ,
    input [P_AXI_ADDR_WIDTH-1:0]    i_user_baddr                    ,
    input [P_AXI_ADDR_WIDTH-1:0]    i_user_faddr                    ,
    output                          o_user_busy                     ,   // 1

    /*-------- AXI Port --------*/
    output                          o_axi_u2a_rden                  ,   // 1
    output [P_AXI_ADDR_WIDTH-1:0]   o_axi_u2a_addr                  ,   // 1
    output [7:0]                    o_axi_u2a_length                ,   // 1
    input                           i_buffer_ready                  
);

/*--------------------------------------------------------------------------------------------------------*\

    here we got something to say:

        user send a req to this module ,then we collect cmd to send to AXI_master.
        but we have to know the state of buffer, if buffer has enough space,
        then the collected-cmd can be sent, so here we have a handshake with the next module.

        besides, if this module is collect cmd or wait for buffer to ready, 
        it means it is busy, so the req when it is busy will be ignore 
        so we have a output : o_busy it is kind or handshake but user should care ,
        it means user should wait no busy, then send req, so here we dont do handshake with user.

\*--------------------------------------------------------------------------------------------------------*/

localparam                          P_BURST_LEN = P_WR_LENGTH/(P_AXI_DATA_WIDTH/8);

// sync RST
reg                                 ri_rst                          ;
reg                                 ri_rst_1d                       ;
reg                                 r_user_rst                      ;
always@(posedge i_user_clk)
begin
    ri_rst     <= i_rst;
    ri_rst_1d  <= ri_rst;
    r_user_rst <= ri_rst_1d;
end

// delay to sync ddr_init
reg                                 ri_ddr_init                     ;
reg                                 r_ddr_init                      ;
always@(posedge i_user_clk or posedge r_user_rst)
begin
    if (r_user_rst) begin
        ri_ddr_init    <= 'd0;
        r_ddr_init     <= 'd0;
    end else begin
        ri_ddr_init    <= i_ddr_init;
        r_ddr_init     <= ri_ddr_init;
    end
end

// delay to sync req
reg                                 ri_user_req                     ;
reg                                 ri_user_req_1d                  ;
always@(posedge i_user_clk or posedge r_user_rst)
begin
    if (r_user_rst) begin
        ri_user_req    <= 'd0;
        ri_user_req_1d <= 'd0;
    end else begin
        ri_user_req    <= i_user_req;
        ri_user_req_1d <= ri_user_req;
    end
end

// check req_pos
wire                                w_user_req_pos                  ;
reg                                 r_user_req_pos                  ;
assign                              w_user_req_pos = ri_user_req & !ri_user_req_1d;
always@(posedge i_user_clk or posedge r_user_rst)
begin
    if (r_user_rst)
        r_user_req_pos <= 'd0;
    else if (r_ddr_init)
        r_user_req_pos <= w_user_req_pos;
    else
        r_user_req_pos <= 'd0;
end

// if we got r_user_req_pos = 1 then collect CMD
// use a fsm
localparam                          P_ST_IDLE   =   0               ,
                                    P_ST_REQ    =   1               ,
                                    P_ST_END    =   2               ;

reg [7:0]                           r_st_current                    ;
reg [7:0]                           r_st_next                       ;
always@(posedge i_user_clk or posedge r_user_rst)
begin
    if (r_user_rst)
        r_st_current <= P_ST_IDLE;
    else
        r_st_current <= r_st_next;
end

always@(*)
begin
    case(r_st_current)
        P_ST_IDLE   :   r_st_next <= r_user_req_pos ?   P_ST_REQ    :   P_ST_IDLE   ;
        P_ST_REQ    :   r_st_next <= o_axi_u2a_rden && i_buffer_ready               ?   P_ST_END    :   P_ST_REQ    ;
        P_ST_END    :   r_st_next <= P_ST_IDLE      ;
        default     :   r_st_next <= P_ST_IDLE      ;
    endcase
end

reg                                 ro_axi_u2a_rden                 ;
assign                              o_axi_u2a_rden = ro_axi_u2a_rden;
always@(posedge i_user_clk or posedge r_user_rst)
begin
    if (r_user_rst)
        ro_axi_u2a_rden <= 'd0;
    else if (o_axi_u2a_rden && i_buffer_ready)
        ro_axi_u2a_rden <= 'd0;
    else if (r_st_current == P_ST_IDLE && r_st_next == P_ST_REQ)
        ro_axi_u2a_rden <= 'd1;
    else
        ro_axi_u2a_rden <= ro_axi_u2a_rden;
end

// ctrl BUSY
assign                              o_user_busy = r_st_current != P_ST_IDLE;

// [P_AXI_ADDR_WIDTH-1:0]   o_axi_u2a_addr  
// [7:0]                    o_axi_u2a_length
reg [P_AXI_ADDR_WIDTH-1:0]          ro_axi_u2a_addr                 ;
assign                              o_axi_u2a_addr = ro_axi_u2a_addr;
always@(posedge i_user_clk or posedge r_user_rst)
begin
    if (r_user_rst)
        ro_axi_u2a_addr <= i_user_baddr;
    else if (o_axi_u2a_rden && i_buffer_ready && ro_axi_u2a_addr + P_WR_LENGTH >= i_user_faddr)
        ro_axi_u2a_addr <= i_user_baddr;
    else if (o_axi_u2a_rden && i_buffer_ready)
        ro_axi_u2a_addr <= ro_axi_u2a_addr + P_WR_LENGTH;
    else
        ro_axi_u2a_addr <= ro_axi_u2a_addr;
end

assign                              o_axi_u2a_length = P_BURST_LEN - 1;


endmodule
