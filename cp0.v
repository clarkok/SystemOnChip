`include "cp0_def.vh"

module cp0(
    input  clk,
    input  rst,

    input      [ 4:0]   cp0_addr_i,
    output reg [31:0]   cp0_data_o,
    input      [31:0]   cp0_data_i,
    input               cp0_we_i,

    output     [31:0]   cp0_epc_o,
    output     [31:0]   cp0_ehb_o,
    output     [31:0]   cp0_ptb_o,
    output              cp0_ptb_we,

    input               exception,
    input      [31:0]   cause,
    input      [31:0]   epc,
    input               eret,

    output              hw_interrupt,
    output reg [31:0]   hw_cause,

    input      [31:0]   devices_interrupt,

    input               hw_page_fault,
    input      [31:0]   hw_page_fault_addr
    );

    reg [31:0] cp0_epc;
    reg [31:0] cp0_ecause;
    reg [31:0] cp0_ie;
    reg [31:0] cp0_is;
    reg [31:0] cp0_ehb;
    reg [31:0] cp0_ptb;
    reg [31:0] cp0_pfa;

    assign cp0_epc_o    = cp0_epc;
    assign cp0_ehb_o    = cp0_ehb;
    assign cp0_ptb_o    = cp0_ptb;
    assign cp0_ptb_we   = cp0_we_i && (cp0_addr_i == `CP0_PTB);

    always @* begin
        case (cp0_addr_i)
            `CP0_EPC:       cp0_data_o  = cp0_epc;
            `CP0_ECAUSE:    cp0_data_o  = cp0_ecause;
            `CP0_IE:        cp0_data_o  = cp0_ie;
            `CP0_IS:        cp0_data_o  = cp0_is;
            `CP0_EHB:       cp0_data_o  = cp0_ehb;
            `CP0_PTB:       cp0_data_o  = cp0_ptb;
            `CP0_PFA:       cp0_data_o  = cp0_pfa;
            default:        cp0_data_o  = 32'h0;
        endcase
    end

    wire [30:0] interrupt   = cp0_ie[30:0] & cp0_is[30:0];
    assign hw_interrupt     = cp0_ie[31] && interrupt;

    always @* begin
        case (1)
            interrupt[ 0]:  hw_cause    =  0;
            interrupt[ 1]:  hw_cause    =  1;
            interrupt[ 2]:  hw_cause    =  2;
            interrupt[ 3]:  hw_cause    =  3;
            interrupt[ 4]:  hw_cause    =  4;
            interrupt[ 5]:  hw_cause    =  5;
            interrupt[ 6]:  hw_cause    =  6;
            interrupt[ 7]:  hw_cause    =  7;
            interrupt[ 8]:  hw_cause    =  8;
            interrupt[ 9]:  hw_cause    =  9;
            interrupt[10]:  hw_cause    = 10;
            interrupt[11]:  hw_cause    = 11;
            interrupt[12]:  hw_cause    = 12;
            interrupt[13]:  hw_cause    = 13;
            interrupt[14]:  hw_cause    = 14;
            interrupt[15]:  hw_cause    = 15;
            interrupt[16]:  hw_cause    = 16;
            interrupt[17]:  hw_cause    = 17;
            interrupt[18]:  hw_cause    = 18;
            interrupt[19]:  hw_cause    = 19;
            interrupt[20]:  hw_cause    = 20;
            interrupt[21]:  hw_cause    = 21;
            interrupt[22]:  hw_cause    = 22;
            interrupt[23]:  hw_cause    = 23;
            interrupt[24]:  hw_cause    = 24;
            interrupt[25]:  hw_cause    = 25;
            interrupt[26]:  hw_cause    = 26;
            interrupt[27]:  hw_cause    = 27;
            interrupt[28]:  hw_cause    = 28;
            interrupt[29]:  hw_cause    = 29;
            interrupt[30]:  hw_cause    = 30;
            default      :  hw_cause    = 0;
        endcase
    end

    task init;
    begin
        cp0_epc     <= 0;
        cp0_ecause  <= 0;
        cp0_ie      <= 0;
        cp0_is      <= 0;
        cp0_ehb     <= 0;
        cp0_ptb     <= 0;
        cp0_pfa     <= 0;
    end
    endtask

    initial init();

    always @(posedge clk) begin
        if (rst) init();
        else begin
            if (cp0_we_i) begin
                case (cp0_addr_i)
                    `CP0_EPC:       cp0_epc     <= cp0_data_i;
                    `CP0_ECAUSE:    cp0_ecause  <= cp0_data_i;
                    `CP0_IE:        cp0_ie      <= cp0_data_i;
                    `CP0_EHB:       cp0_ehb     <= cp0_data_i;
                    `CP0_PTB:       cp0_ptb     <= cp0_data_i;
                    `CP0_PFA:       cp0_pfa     <= cp0_data_i;
                endcase
            end

            cp0_is      <= devices_interrupt;
            if (exception) begin
                cp0_ie[31]  <= 0;
                cp0_epc     <= epc;
                cp0_ecause  <= cause;
            end
            if (eret) begin
                cp0_ie[31]  <= 1;
            end

            if (hw_page_fault) begin
                cp0_pfa     <= hw_page_fault_addr;
            end
        end
    end

endmodule
