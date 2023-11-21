module user_gen_module#(
    parameter               P_WR_LENGTH         =   4096    ,
                            P_USER_DATA_WIDTH   =   16      ,
                            P_AXI_DATA_WIDTH    =   128     ,
                            P_AXI_ADDR_WIDTH    =   32      
)(
    input                           i_user_rdclk            ,
    input                           i_user_wrclk            ,
    input                           i_rst                   ,

    output [P_USER_DATA_WIDTH-1:0]  o_user_data             ,
    output                          o_user_valid            ,

    output                          o_user_rdreq            
);

// sync rst
reg                                 ri_wr_rst               ;
reg                                 ri_wr_rst_1d            ;
reg                                 r_wr_rst                ;

reg                                 ri_rd_rst               ;
reg                                 ri_rd_rst_1d            ;
reg                                 r_rd_rst                ;

/*-------- wr --------*/
always@(posedge i_user_wrclk)
begin
    ri_wr_rst    <= i_rst;
    ri_wr_rst_1d <= ri_wr_rst;
    r_wr_rst     <= ri_wr_rst_1d;
end

reg [15:0]                          r_wr_timer              ;
reg                                 r_wr_reset              ;
always@(posedge i_user_wrclk or posedge r_wr_rst)
begin
    if (r_wr_rst) begin
        r_wr_timer <= 'd0;
        r_wr_reset <= 'd1;
    end else if (r_wr_timer <= 'd1000) begin
        r_wr_timer <= r_wr_timer + 1;
        r_wr_reset <= 'd1;
    end else begin
        r_wr_timer <= r_wr_timer;
        r_wr_reset <= 'd0;
    end
end

reg [P_USER_DATA_WIDTH-1:0]         ro_user_data            ;
reg                                 ro_user_valid           ;
assign                              o_user_data  = ro_user_data ;
assign                              o_user_valid = ro_user_valid;
reg [15:0]                          r_wr_cnt                ;
always@(posedge i_user_wrclk or posedge r_wr_reset)
begin
    if (r_wr_reset)
        r_wr_cnt <= 'd0;
    else if (r_wr_cnt == 'd4095)
        r_wr_cnt <= 'd0;
    else
        r_wr_cnt <= r_wr_cnt + 1;
end

always@(posedge i_user_wrclk or posedge r_wr_reset)
begin
    if (r_wr_reset)
        ro_user_valid <= 'd0;
    else if (r_wr_cnt <= 'd4095)
        ro_user_valid <= 'd1;
    else
        ro_user_valid <= 'd0;
end

always@(posedge i_user_wrclk or posedge r_wr_reset)
begin
    if (r_wr_reset)
        ro_user_data <= 'd0;
    else if (r_wr_cnt == 'd4095)
        ro_user_data <= 'd0;
    else
        ro_user_data <= ro_user_data + 1;
end

/*-------- rd --------*/
always@(posedge i_user_rdclk or posedge r_rd_rst)
begin
    ri_rd_rst    <= i_rst;
    ri_rd_rst_1d <= ri_rd_rst;
    r_rd_rst     <= ri_rd_rst_1d;
end

reg [15:0]                          r_rd_timer              ;
reg                                 r_rd_reset              ;
always@(posedge i_user_rdclk or posedge r_rd_rst)
begin
    if (r_rd_rst) begin
        r_rd_timer <= 'd0;
        r_rd_reset <= 'd1;
    end else if (r_rd_timer <= 'd2000) begin
        r_rd_timer <= r_rd_timer + 1;
        r_rd_reset <= 'd1;
    end else begin
        r_rd_timer <= r_rd_timer;
        r_rd_reset <= 'd0;
    end
end

reg [15:0]                          r_rd_cnt                ;
always@(posedge i_user_rdclk or posedge r_rd_reset)
begin
    if (r_rd_reset)
        r_rd_cnt <= 'd0;
    else if (r_rd_cnt == 'd3000)
        r_rd_cnt <= 'd0;
    else
        r_rd_cnt <= r_rd_cnt + 1;
end

reg                                 ro_user_rdreq           ;
assign                              o_user_rdreq = ro_user_rdreq;
always@(posedge i_user_rdclk or posedge r_rd_reset)
begin
    if (r_rd_reset)
        ro_user_rdreq <= 'd0;
    else if (r_rd_cnt == 'd3000)
        ro_user_rdreq <= 'd1;
    else
        ro_user_rdreq <= 'd0;
end

reg [15:0]                          r_req_num               ;
always@(posedge i_user_rdclk or posedge r_rd_reset)
begin
    if (r_rd_reset)
        r_req_num <= 'd0;
    else if (ro_user_rdreq)
        r_req_num <= r_req_num + 1;
    else
        r_req_num <= r_req_num;
end


endmodule
