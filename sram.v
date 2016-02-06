module sram(
    input  clk,
    input  rst,

    // sram IO
    output reg [19:0] sram_addr,
    inout      [47:0] sram_dq,
    output reg        sram_ce,
    output reg        sram_oen,
    output reg        sram_wen,

    // VGA IO
    input  [19:0] vga_addr,
    output [47:0] vga_data,
    input         vga_sel,
    output        vga_valid,

    // GPU master IO
    input  [19:0] gpu_master_addr,
    output [47:0] gpu_master_data_o,
    input  [47:0] gpu_master_data_i,
    input         gpu_master_sel,
    input         gpu_master_we,
    output        gpu_master_valid,

    // GPU slave IO
    input  [19:0] gpu_slave_addr,
    output [47:0] gpu_slave_data_o,
    input  [47:0] gpu_slave_data_i,
    input         gpu_slave_sel,
    input         gpu_slave_we,
    output        gpu_slave_valid,

    // BUS IO
    input  [31:0] bus_addr_i,
    output [31:0] bus_data_o,
    input  [31:0] bus_data_i,
    input  [ 1:0] bus_sel_i,
    input         bus_rd_i,
    input         bus_we_i,
    output        bus_ack_o
    );

    reg [ 2:0] state;
    reg [ 2:0] last_state;
    reg [47:0] sram_dq_r;
    reg        sram_read;
    wire [ 2:0] state_next;
    wire [19:0] sram_addr_next;
    wire [47:0] sram_dq_next;
    wire        sram_oen_next;
    wire        sram_wen_next;

    wire        bus_sel         = bus_rd_i || bus_we_i;
    wire        bus_we          = bus_we_i;
    wire        bus_valid;
    assign      bus_ack_o       = bus_valid;

    wire        vga_req         = vga_sel & ~vga_valid;
    wire        gpu_master_req  = gpu_master_sel & ~gpu_master_valid;
    wire        gpu_slave_req   = gpu_slave_sel & ~gpu_slave_valid;
    wire        bus_req         = bus_sel & ~bus_valid;

    wire   sram_wea       =  vga_req        ? 1'b0              :
                             gpu_master_req ? gpu_master_we     :
                             gpu_slave_req  ? gpu_slave_we      :
                             bus_req        ? bus_we            :
                                              1'b0;
    assign state_next     =  vga_req        ? 3'h1              :
                             gpu_master_req ? 3'h2              :
                             gpu_slave_req  ? 3'h3              :
                             bus_req        ? 3'h4              :
                                              3'h0;
    assign sram_addr_next =  vga_req        ? vga_addr          :
                             gpu_master_req ? gpu_master_addr   :
                             gpu_slave_req  ? gpu_slave_addr    :
                             bus_req        ? bus_addr_i[19:0]  :
                                              20'h0;
    assign sram_dq_next   =  vga_req         ? {48{1'bz}} :
                             gpu_master_req  ? ( gpu_master_we ? gpu_master_data_i      : {48{1'bz}} )  :
                             gpu_slave_req   ? ( gpu_slave_we  ? gpu_slave_data_i       : {48{1'bz}} )  :
                             bus_req         ? { bus_we        ? {16'b0, bus_data_i}    : {48{1'bz}}}   :
                                               {48{1'bz}};
    assign sram_oen_next  =  sram_wea;
    assign sram_wen_next  = ~sram_wea;
    assign sram_dq        =  sram_read ? {48{1'bz}} : sram_dq_r;

    assign vga_data  =  sram_dq;
    assign vga_valid =  (last_state == 3'h1) && (sram_addr == vga_addr);

    assign gpu_master_data_o=  sram_dq;
    assign gpu_master_valid =  (last_state == 3'h2 && sram_addr == gpu_master_addr);

    assign gpu_slave_data_o =  sram_dq;
    assign gpu_slave_valid  =  (last_state == 3'h3 && sram_addr == gpu_slave_addr);

    assign bus_data_o       =  sram_dq;
    assign bus_valid        =  (last_state == 3'h4 && sram_addr == bus_addr_i[19:0]);

    task init;
    begin
        state       <= 3'h0;
        last_state  <= 3'h0;
        sram_addr   <= 20'b0;
        sram_dq_r   <= 48'b0;
        sram_ce     <= 1'b0;
        sram_oen    <= 1'b0;
        sram_wen    <= 1'b1;
        sram_read   <= 1'b0;
    end
    endtask

    initial init();

    always @(posedge clk) begin
        if (rst) init();
        else if (state) begin
            state       <= 3'h0;
        end
        else begin
            state       <= state_next;
            sram_addr   <= sram_addr_next;
            sram_dq_r   <= sram_dq_next;
            sram_oen    <= sram_oen_next;
            sram_wen    <= sram_wen_next;
            sram_read   <= ~sram_wea;
        end
        last_state  <= state;
    end

endmodule
