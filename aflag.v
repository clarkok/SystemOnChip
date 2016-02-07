module async_flag(
    input clk_src,
    input flag_src,
    input clk_dst,
    output flag_dst
    );

    reg flag_toggle_src;
    always @(posedge clk_src) flag_toggle_src   <= flag_toggle_src ^ flag_src;

    reg [2:0] sync_dst;
    always @(posedge clk_dst) sync_dst  <= {sync_dst[1:0], flag_toggle_src};

    assign flag_dst = sync_dst[2] ^ sync_dst[1];

    initial begin
        flag_toggle_src <= 1'b0;
        sync_dst        <= 3'b0;
    end
endmodule
