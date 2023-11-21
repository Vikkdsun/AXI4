module wr_ctrl#(
    parameter               P_WR_LENGTH         =   4096    ,
                            P_USER_DATA_WIDTH   =   16      ,
                            P_AXI_DATA_WIDTH    =   128     ,
                            P_AXI_ADDR_WIDTH    =   32      
)(
    input                           i_user_clk              ,
    input                           i_user_rst              ,

    /*-------- DDR Port --------*/
    input                           i_ddr_init              ,

    /*-------- USER Port --------*/
    input                           i_user_valid            ,
    input [P_AXI_ADDR_WIDTH-1:0]    i_user_baddr            ,
    input [P_AXI_ADDR_WIDTH-1:0]    i_user_faddr            ,
    input [P_USER_DATA_WIDTH-1:0]   i_user_data             ,

    /*-------- AXI Port --------*/
    output [P_AXI_DATA_WIDTH-1:0]   o_axi_u2a_data          ,   // 1
    output                          o_axi_u2a_last          ,   // 1
    output                          o_axi_u2a_valid         ,   // 1

    output                          o_axi_wr_en             ,   // 1
    output [P_AXI_ADDR_WIDTH-1:0]   o_axi_wr_addr           ,   // 1
    output [7:0]                    o_axi_wr_length             // 1
);

localparam                          P_CNT_MAX = P_AXI_DATA_WIDTH/P_USER_DATA_WIDTH;
localparam                          P_BURST_LEN = P_WR_LENGTH/(P_AXI_DATA_WIDTH/8);

assign                              o_axi_wr_length = P_BURST_LEN-1;

// sync RST
reg                                 ri_user_rst             ;
reg                                 ri_user_rst_1d          ;
reg                                 r_user_rst              ;
always@(posedge i_user_clk)
begin
    ri_user_rst    <= i_user_rst;
    ri_user_rst_1d <= ri_user_rst;
    r_user_rst     <= ri_user_rst_1d;
end

// sync INIT
reg                                 ri_ddr_init             ;
reg                                 r_ddr_init              ;
always@(posedge i_user_clk or posedge r_user_rst)
begin
    if (r_user_rst) begin
        ri_ddr_init <= 'd0;
        r_ddr_init  <= 'd0;
    end else begin
        ri_ddr_init <= i_ddr_init;
        r_ddr_init  <= ri_ddr_init;
    end
end

// intit to valid
reg                                 ri_user_valid           ;
reg [P_USER_DATA_WIDTH-1:0]         ri_user_data            ;
always@(posedge i_user_clk or posedge r_user_rst)
begin
    if (r_user_rst) begin
        ri_user_valid <= 'd0;
        ri_user_data  <= 'd0;
    end else if (r_ddr_init) begin
        ri_user_valid <= i_user_valid;
        ri_user_data  <= i_user_data ;
    end else begin
        ri_user_valid <= 'd0;
        ri_user_data  <= 'd0;
    end
end

// cnt to shift input data
reg [15:0]                          r_shift_cnt             ;
always@(posedge i_user_clk or posedge r_user_rst)
begin
    if (r_user_rst)
        r_shift_cnt <= 'd0;
    else if (ri_user_valid && r_shift_cnt == P_CNT_MAX - 1)
        r_shift_cnt <= 'd0;
    else if (ri_user_valid)
        r_shift_cnt <= r_shift_cnt + 1;
    else
        r_shift_cnt <= r_shift_cnt;
end

// out to AXI data
reg [P_AXI_DATA_WIDTH-1:0]          ro_u2a_data             ;
assign                              o_axi_u2a_data = ro_u2a_data;
always@(posedge i_user_clk or posedge r_user_rst)
begin
    if (r_user_rst)
        ro_u2a_data <= 'd0;
    else if (ri_user_valid)
        ro_u2a_data <= {ri_user_data, ro_u2a_data[P_AXI_DATA_WIDTH - 1 : P_USER_DATA_WIDTH]};
    else
        ro_u2a_data <= ro_u2a_data;
end

// out to AXI valid
reg                                 ro_u2a_valid            ;
assign                              o_axi_u2a_valid = ro_u2a_valid;
always@(posedge i_user_clk or posedge r_user_rst)
begin
    if (r_user_rst)
        ro_u2a_valid <= 'd0;
    else if (ri_user_valid && r_shift_cnt == P_CNT_MAX - 1)
        ro_u2a_valid <= 'd1;
    else
        ro_u2a_valid <= 'd0;
end

// cnt to count num
reg [15:0]                          r_num_cnt               ;
always@(posedge i_user_clk or posedge r_user_rst)
begin
    if (r_user_rst)
        r_num_cnt <= 'd0;
    else if (ri_user_valid && r_shift_cnt == P_CNT_MAX - 1 && r_num_cnt == P_BURST_LEN - 1)
        r_num_cnt <= 'd0;
    else if (ri_user_valid && r_shift_cnt == P_CNT_MAX - 1)
        r_num_cnt <= r_num_cnt + 1;
    else
        r_num_cnt <= r_num_cnt;
end

// out to AXI last
reg                                 ro_u2a_last             ;
assign                              o_axi_u2a_last = ro_u2a_last;
always@(posedge i_user_clk or posedge r_user_rst)
begin
    if (r_user_rst)
        ro_u2a_last <= 'd0;
    else if (ri_user_valid && r_shift_cnt == P_CNT_MAX - 1 && r_num_cnt == P_BURST_LEN - 1)
        ro_u2a_last <= 'd1;
    else
        ro_u2a_last <= 'd0;
end 

// o_axi_wr_en
reg                                 ro_axi_wr_en            ;
assign                              o_axi_wr_en = ro_axi_wr_en;
always@(posedge i_user_clk or posedge r_user_rst)
begin
    if (r_user_rst)
        ro_axi_wr_en <= 'd0;
    else if (ri_user_valid && r_shift_cnt == P_CNT_MAX - 1 && r_num_cnt == P_BURST_LEN - 1)
        ro_axi_wr_en <= 'd1;
    else
        ro_axi_wr_en <= 'd0;
end

// [P_AXI_ADDR_WIDTH-1:0]   o_axi_wr_addr
reg [P_AXI_ADDR_WIDTH-1:0]          ro_axi_wr_addr          ;
assign                              o_axi_wr_addr = ro_axi_wr_addr;
always@(posedge i_user_clk or posedge r_user_rst)
begin
    if (r_user_rst)
        ro_axi_wr_addr <= i_user_baddr;
    else if (ro_axi_wr_en && ro_axi_wr_addr + o_axi_wr_length >= i_user_faddr)
        ro_axi_wr_addr <= i_user_baddr;
    else if (ro_axi_wr_en)
        ro_axi_wr_addr <= ro_axi_wr_addr + P_WR_LENGTH;
    else
        ro_axi_wr_addr <= ro_axi_wr_addr;
end


endmodule
