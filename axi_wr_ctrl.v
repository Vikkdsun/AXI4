module axi_wr_ctrl#(
    parameter               P_WR_LENGTH         =   4096    ,
                            P_USER_DATA_WIDTH   =   16      ,
                            P_AXI_DATA_WIDTH    =   128     ,
                            P_AXI_ADDR_WIDTH    =   32      
)(
    input                               i_clk               ,
    input                               i_rst               ,

    input                               i_ddr_init          ,

    input [P_USER_DATA_WIDTH - 1:0]     i_user_data         ,
    input [P_AXI_ADDR_WIDTH - 1:0]      i_user_baddr        ,   // got one clk but its in the begin of DATA_VALID
    input [P_AXI_ADDR_WIDTH - 1:0]      i_user_faddr        ,   // got one clk but its in the begin of DATA_VALID
    input                               i_user_valid        ,
    input                               i_user_last         ,

    output                              o_u2a_en            ,
    output [P_AXI_DATA_WIDTH - 1:0]     o_u2a_data          ,
    output [P_AXI_ADDR_WIDTH - 1:0]     o_u2a_addr          ,
    output [7:0]                        o_u2a_length        ,
    output                              o_u2a_valid         ,
    output                              o_u2a_last          
);

localparam                          P_WIDTH_CNT_MAX = P_AXI_DATA_WIDTH/P_USER_DATA_WIDTH;
localparam                          P_BURST_LEN     = P_WR_LENGTH/(P_AXI_DATA_WIDTH/8) - 1;

reg                                 r_rst                   ;
reg                                 r_rst_1d                ;
always@(posedge i_clk or posedge i_rst)
begin
    r_rst    <= i_rst;
    r_rst_1d <= r_rst;
end


reg                                 r_ddr_init              ;
reg                                 r_ddr_init_1d           ;
always@(posedge i_clk or posedge r_rst_1d)
begin
    if (i_rst) begin
        r_ddr_init    <= 'd0;
        r_ddr_init_1d <= 'd0;
    end else begin
        r_ddr_init    <= i_ddr_init;
        r_ddr_init_1d <= r_ddr_init;
    end
end

reg [P_USER_DATA_WIDTH - 1:0]       ri_user_data            ;
reg                                 ri_user_valid           ;
reg                                 ri_user_last            ;
always@(posedge i_clk or posedge r_rst_1d)
begin
    if (r_rst_1d) begin
        ri_user_valid <= 'd0;
        ri_user_data  <= 'd0;
        ri_user_last  <= 'd0;
    end else if (r_ddr_init_1d) begin
        ri_user_valid <= i_user_valid;
        ri_user_data  <= i_user_data ;
        ri_user_last  <= i_user_last;
    end else begin
        ri_user_valid <= 'd0;
        ri_user_data  <= 'd0;
        ri_user_last  <= 'd0;
    end
end

// 2 cnt
reg [15:0]                          r_width_cnt                 ;       // cnt shift
reg [15:0]                          r_len_cnt                   ;       // cnt num
always@(posedge i_clk or posedge r_rst_1d)
begin
    if (r_rst_1d)
        r_width_cnt <= 'd0;
    else if (r_width_cnt == P_WIDTH_CNT_MAX - 1 && ri_user_valid)
        r_width_cnt <= 'd0;
    else if (ri_user_valid)
        r_width_cnt <= r_width_cnt + 1;
    else
        r_width_cnt <= r_width_cnt;
end

always@(posedge i_clk or posedge r_rst_1d)
begin
    if (r_rst_1d)
        r_len_cnt <= 'd0;
    else if (r_len_cnt == P_BURST_LEN - 1 && r_width_cnt == P_WIDTH_CNT_MAX - 1 && ri_user_valid)
        r_len_cnt <= 'd0;
    else if (r_width_cnt == P_WIDTH_CNT_MAX - 1 && ri_user_valid)
        r_len_cnt <= r_len_cnt + 1;
    else
        r_len_cnt <= r_len_cnt;
end     

// output reg
reg                                 ro_u2a_en                       ;
reg [P_AXI_DATA_WIDTH - 1:0]        ro_u2a_data                     ;
reg [P_AXI_ADDR_WIDTH - 1:0]        ro_u2a_addr                     ;
reg                                 ro_u2a_valid                    ;
reg                                 ro_u2a_last                     ;
assign                              o_u2a_data   = ro_u2a_data      ;
assign                              o_u2a_addr   = ro_u2a_addr      ;
assign                              o_u2a_length = P_BURST_LEN      ;
assign                              o_u2a_valid  = ro_u2a_valid     ;
assign                              o_u2a_last   = ro_u2a_last      ;
assign                              o_u2a_en     = ro_u2a_en        ;

// ctrl valid
always@(posedge i_clk or posedge r_rst_1d)
begin
    if (r_rst_1d)
        ro_u2a_valid <= 'd0;
    else if (r_width_cnt == P_WIDTH_CNT_MAX - 1 && ri_user_valid)
        ro_u2a_valid <= 'd1;
    else
        ro_u2a_valid <= 'd0;
end

// ctrl data
always@(posedge i_clk or posedge r_rst_1d)
begin
    if (r_rst_1d)
        ro_u2a_data <= 'd0;
    else if (ri_user_valid)
        ro_u2a_data <= {ri_user_data, ro_u2a_data[P_AXI_DATA_WIDTH - P_USER_DATA_WIDTH - 1: 0]};
    else
        ro_u2a_data <= ro_u2a_data;
end

// ctrl last
always@(posedge i_clk or posedge r_rst_1d)
begin
    if (r_rst_1d)
        ro_u2a_last <= 'd0;
    else if (r_len_cnt == P_BURST_LEN - 1 && r_width_cnt == P_WIDTH_CNT_MAX - 1 && ri_user_valid)  
        ro_u2a_last <= 'd1;
    else
        ro_u2a_last <= 'd0;
end

// use a flag
always@(posedge i_clk or posedge r_rst_1d)
begin
    if (r_rst_1d)
        ro_u2a_en <= 'd0;
    else if (r_len_cnt == P_BURST_LEN - 1 && r_width_cnt == P_WIDTH_CNT_MAX - 1 && ri_user_valid)
        ro_u2a_en <= 'd1;
    else        
        ro_u2a_en <= 'd0;
end

// ctrl addr
always@(posedge i_clk or posedge r_rst_1d)
begin
    if (r_rst_1d)
        ro_u2a_addr <= i_user_baddr;          // here we supose that before rst we got addr from user input
    else if (ro_u2a_addr + P_WR_LENGTH >= i_user_faddr && ro_u2a_en)
        ro_u2a_addr <= i_user_baddr; 
    else if (ro_u2a_en)
        ro_u2a_addr <= ro_u2a_addr + P_WR_LENGTH;
    else
        ro_u2a_addr <= ro_u2a_addr;
end


endmodule
