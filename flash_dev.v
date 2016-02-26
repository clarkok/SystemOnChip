module flash_dev(
    input  clk,
    input  rst,

    output [25:0]   bpi_a,
    inout  [31:0]   bpi_q,
    output [ 1:0]   bpi_cen,
    output          bpi_oen,
    output          bpi_wen,
    output          bpi_rstn,
    input  [ 1:0]   bpi_rynby,

    input  [31:0]   addr_i,
    output [31:0]   data_o,
    input  [31:0]   data_i,
    input  [ 1:0]   sel_i,
    input           rd_i,
    input           we_i,
    output          ack_o,

    output          interrupt
    );

    parameter   FLASH_CTRL_ADDR = 32'hFFFF_FE00;

    reg  [31:0] status;

    wire [ 6:0] buffer_addr;
    wire [31:0] buffer_data_i;
    wire [31:0] buffer_data_o;
    wire        buffer_we;

    flash_buffer flash_buffer(
        .clk(clk),
        .a(buffer_addr),
        .d(buffer_data_i),
        .spo(buffer_data_o),
        .we(buffer_we)
    );

    wire [25:0] flash_block_addr;
    wire [31:0] flash_data_i;
    wire [31:0] flash_data_o;
    wire        flash_we_i;
    wire        flash_rd_i;
    wire        flash_ack_o;

    flash flash(
        .clk(clk),
        .rst(rst),
        .block_addr(flash_block_addr),
        .data_i(flash_data_i),
        .data_o(flash_data_o),
        .we_i(flash_we_i),
        .rd_i(flash_rd_i),
        .ack_o(flash_ack_o),
        .bpi_a(bpi_a),
        .bpi_q(bpi_q),
        .bpi_cen(bpi_cen),
        .bpi_oen(bpi_oen),
        .bpi_wen(bpi_wen),
        .bpi_rstn(bpi_rstn),
        .bpi_rynby(bpi_rynby)
    );

    localparam  S_IDLE = 0,
                S_READ = 1,
                S_WRITE = 2,
                S_END = 3;

    reg  [ 6:0] counter;
    reg  [ 3:0] state;

    reg  [31:0] data_wr;
    reg  [31:0] data_rr;

    wire ctrl_stb       = (addr_i == FLASH_CTRL_ADDR);
    wire in_read        = (state == S_READ);
    wire in_write       = (state == S_WRITE);
    wire in_operation   =  in_read || in_write;

    assign data_o           = ctrl_stb ? status : data_rr;
    assign ack_o            = 1'b1;
    assign interrupt        = status[31];

    assign buffer_addr      = in_operation ? counter                    : addr_i[8:2];
    assign buffer_data_i    = in_operation ? flash_data_o               : data_wr;
    assign buffer_we        = in_operation ? (in_read && flash_ack_o)   : (we_i && ~ctrl_stb);

    assign flash_block_addr     = status[25:0];
    assign flash_data_i         = buffer_data_o;
    assign flash_we_i           = in_write;
    assign flash_rd_i           = in_read;

    task init;
    begin
        status  <= 0;
        counter <= 0;
        state   <= S_IDLE;
    end
    endtask

    initial init();

    always @(posedge clk) begin
        if (rst) init();
        else begin
            if (ctrl_stb && we_i) begin
                status  <= data_i;
            end

            case (state)
                S_IDLE: begin
                    if (~status[31]) begin
                        if (status[30]) begin
                            state   <= S_READ;
                            counter <= 0;
                        end
                        else if (status[29]) begin
                            state   <= S_WRITE;
                            counter <= 0;
                        end
                    end
                end
                S_READ: begin
                    if (flash_ack_o) begin
                        if (counter == 7'h7F)   state   <= S_END;
                        else                    counter <= counter + 1;
                    end
                end
                S_WRITE: begin
                    if (flash_ack_o) begin
                        if (counter == 7'h7F)   state   <= S_END;
                        else                    counter <= counter + 1;
                    end
                end
                S_END: begin
                    status[31]  <= 1'b1;
                    state       <= S_IDLE;
                end
            endcase
        end
    end

    always @* begin
        case (sel_i)
            2'd0: begin
                case (addr_i[1:0])
                    2'd0: data_wr = {buffer_data_o[31: 8], data_i[7:0]                     };
                    2'd1: data_wr = {buffer_data_o[31:16], data_i[7:0], buffer_data_o[ 7:0]};
                    2'd2: data_wr = {buffer_data_o[31:24], data_i[7:0], buffer_data_o[15:0]};
                    2'd3: data_wr = {                      data_i[7:0], buffer_data_o[23:0]};
                endcase
            end
            2'd1: begin
                data_wr = addr_i[1] ? {                      data_i[15:0], buffer_data_o[15:0]}
                                    : {buffer_data_o[31:16], data_i[15:0]};
            end
            2'd2: data_wr = data_i;
        endcase
    end

    always @* begin
        case (sel_i)
            2'd0: begin
                case (addr_i[1:0])
                    2'd0: data_rr = {24'b0, buffer_data_o[ 7: 0]};
                    2'd1: data_rr = {24'b0, buffer_data_o[15: 8]};
                    2'd2: data_rr = {24'b0, buffer_data_o[23:16]};
                    2'd3: data_rr = {24'b0, buffer_data_o[31:24]};
                endcase
            end
            2'd1: begin
                data_rr = addr_i[1] ? {16'b0, buffer_data_o[31:16]}
                                    : {16'b0, buffer_data_o[15: 0]};
            end
            2'd2: data_rr = buffer_data_o;
        endcase
    end
endmodule
