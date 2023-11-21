module axi_rd_ctrl#(
    parameter               P_WR_LENGTH         =   4096    ,
                            P_USER_DATA_WIDTH   =   16      ,
                            P_AXI_DATA_WIDTH    =   128     ,
                            P_AXI_ADDR_WIDTH    =   32      
)(
    input                               i_clk                   ,
    input                               i_rst                   ,

    input                               i_ddr_init              ,

    input [P_AXI_ADDR_WIDTH - 1:0]      i_user_baddr            ,
    input [P_AXI_ADDR_WIDTH - 1:0]      i_user_faddr            ,
    input                               i_user_valid            ,   // it is be like a req not valid    ###!!!
    output                              o_user_busy             ,   // because of maybe the fifo_cmd almost full so the input req will wait then send user it is busy

    input                               i_axi_ready             ,   // wait for fifo not almost full
    output [7:0]                        o_u2a_length            ,
    output [P_AXI_ADDR_WIDTH - 1:0]     o_u2a_addr              ,
    output                              o_u2a_valid             
);

localparam                              P_BURST_LEN = P_WR_LENGTH/(P_AXI_DATA_WIDTH/8) - 1;

// optim rst
reg                                     ri_rst                              ;
reg                                     r_rst                               ;
always@(posedge i_clk)
begin
    ri_rst <= i_rst ;
    r_rst  <= ri_rst;
end

// sync ddr_init
reg                                     ri_ddr_init                         ;
reg                                     r_ddr_init                          ;
always@(posedge i_clk or posedge r_rst)
begin
    if (r_rst) begin
        ri_ddr_init <= 'd0;
        r_ddr_init  <= 'd0;
    end else begin
        ri_ddr_init <= i_ddr_init;
        r_ddr_init  <= ri_ddr_init;
    end
end

// delay
reg                                     ri_user_valid                       ;
reg                                     ri_user_valid_1d                    ;
always@(posedge i_clk or posedge r_rst)
begin
    if (r_rst) begin
        ri_user_valid    <= 'd0;
        ri_user_valid_1d <= 'd0;
    end else begin
        ri_user_valid    <= i_user_valid ;
        ri_user_valid_1d <= ri_user_valid;
    end
end

wire                                    w_user_req_pos = !ri_user_valid_1d & ri_user_valid;
reg                                     r_user_req_pos                      ;
always@(posedge i_clk or posedge r_rst)
begin
    if (r_rst)
        r_user_req_pos <= 'd0;
    else if (r_ddr_init)
        r_user_req_pos <= w_user_req_pos;
    else
        r_user_req_pos <= 'd0;
end

// use fsm
localparam                              P_ST_IDLE   =   0                   ,
                                        P_ST_REQ    =   1                   ,
                                        P_ST_END    =   2                   ;

reg [7:0]                               r_st_current                        ;
reg [7:0]                               r_st_next                           ;

always@(posedge i_clk or posedge r_rst)
begin
    if (r_rst)
        r_st_current <= P_ST_IDLE;
    else    
        r_st_current <= r_st_next;
end

always@(*)
begin
    case(r_st_current)
        P_ST_IDLE   :   r_st_next <= r_user_req_pos ?   P_ST_REQ    :   P_ST_IDLE   ;
        P_ST_REQ    :   r_st_next <= i_axi_ready && o_u2a_valid     ?   P_ST_END    :   P_ST_REQ;
        P_ST_END    :   r_st_next <= P_ST_IDLE      ;
        default     :   r_st_next <= P_ST_IDLE      ;
    endcase
end

// out_to_master_valid
reg                                     ro_u2a_valid                        ;
assign                                  o_u2a_valid = ro_u2a_valid          ;
always@(posedge i_clk or posedge r_rst)
begin
    if (r_rst)
        ro_u2a_valid <= 'd0;
    else if (i_axi_ready && o_u2a_valid)
        ro_u2a_valid <= 'd0;
    else if (r_st_current == P_ST_IDLE && r_st_next == P_ST_REQ)
        ro_u2a_valid <= 'd1;
    else
        ro_u2a_valid <= ro_u2a_valid;
end

// out_to_user_busy
assign                                  o_user_busy = r_st_current != P_ST_IDLE;

// ctrl addr
reg [P_AXI_ADDR_WIDTH - 1:0]            ro_u2a_addr                         ;
assign                                  o_u2a_addr = ro_u2a_addr            ;
always@(posedge i_clk or posedge r_rst)
begin
    if (r_rst)
        ro_u2a_addr <= i_user_baddr;
    else if (ro_u2a_addr + P_WR_LENGTH > i_user_faddr && i_axi_ready && o_u2a_valid)
        ro_u2a_addr <= i_user_baddr;
    else if (i_axi_ready && o_u2a_valid)
        ro_u2a_addr <= ro_u2a_addr + P_WR_LENGTH;
    else
        ro_u2a_addr <= ro_u2a_addr;
end

// ctrl length
assign                                  o_u2a_length = P_BURST_LEN          ;


endmodule
