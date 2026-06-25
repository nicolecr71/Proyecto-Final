`default_nettype none

module axi_lite_vram_writer #(
    parameter C_S_AXI_DATA_WIDTH = 32,
    parameter C_S_AXI_ADDR_WIDTH = 17,
    parameter VRAM_ADDR_WIDTH    = 15,
    parameter VRAM_DATA_WIDTH    = 12,
    parameter VRAM_MEMORY_DEPTH  = 19200
)(
    input  wire                                  S_AXI_ACLK,
    input  wire                                  S_AXI_ARESETN,

    input  wire [C_S_AXI_ADDR_WIDTH-1:0]         S_AXI_AWADDR,
    input  wire [2:0]                            S_AXI_AWPROT,
    input  wire                                  S_AXI_AWVALID,
    output reg                                   S_AXI_AWREADY,

    input  wire [C_S_AXI_DATA_WIDTH-1:0]         S_AXI_WDATA,
    input  wire [(C_S_AXI_DATA_WIDTH/8)-1:0]     S_AXI_WSTRB,
    input  wire                                  S_AXI_WVALID,
    output reg                                   S_AXI_WREADY,

    output reg  [1:0]                            S_AXI_BRESP,
    output reg                                   S_AXI_BVALID,
    input  wire                                  S_AXI_BREADY,

    input  wire [C_S_AXI_ADDR_WIDTH-1:0]         S_AXI_ARADDR,
    input  wire [2:0]                            S_AXI_ARPROT,
    input  wire                                  S_AXI_ARVALID,
    output reg                                   S_AXI_ARREADY,

    output reg  [C_S_AXI_DATA_WIDTH-1:0]         S_AXI_RDATA,
    output reg  [1:0]                            S_AXI_RRESP,
    output reg                                   S_AXI_RVALID,
    input  wire                                  S_AXI_RREADY,

    output reg                                   swap_request,

    output reg                                   vram_wr_en,
    output reg  [VRAM_ADDR_WIDTH-1:0]            vram_wr_addr,
    output reg  [VRAM_DATA_WIDTH-1:0]            vram_wr_data
);

    localparam [1:0] AXI_RESP_OKAY   = 2'b00;
    localparam [1:0] AXI_RESP_SLVERR = 2'b10;

    localparam [C_S_AXI_ADDR_WIDTH-1:0] SWAP_CONTROL_OFFSET = 17'h1FFF8;
    localparam [C_S_AXI_ADDR_WIDTH-3:0] SWAP_CONTROL_WORD_ADDR = SWAP_CONTROL_OFFSET[C_S_AXI_ADDR_WIDTH-1:2];

    wire [VRAM_ADDR_WIDTH-1:0] axi_word_addr;
    wire [C_S_AXI_ADDR_WIDTH-3:0] axi_write_word_addr;
    wire [C_S_AXI_ADDR_WIDTH-3:0] axi_read_word_addr;

    wire write_addr_valid;
    wire write_strobe_valid;
    wire write_transfer;
    wire swap_write_valid;

    wire unused_axi_signals;

    assign axi_word_addr       = S_AXI_AWADDR[VRAM_ADDR_WIDTH+1:2];
    assign axi_write_word_addr = S_AXI_AWADDR[C_S_AXI_ADDR_WIDTH-1:2];
    assign axi_read_word_addr  = S_AXI_ARADDR[C_S_AXI_ADDR_WIDTH-1:2];

    assign write_addr_valid = (axi_word_addr < VRAM_MEMORY_DEPTH);
    assign write_strobe_valid = S_AXI_WSTRB[0] && S_AXI_WSTRB[1];

    assign write_transfer =
        S_AXI_AWVALID &&
        S_AXI_WVALID &&
        !S_AXI_BVALID;

    assign swap_write_valid =
        (axi_write_word_addr == SWAP_CONTROL_WORD_ADDR) &&
        S_AXI_WSTRB[0] &&
        S_AXI_WDATA[0];

    assign unused_axi_signals = &{
        1'b0,
        S_AXI_AWPROT,
        S_AXI_ARPROT
    };

    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            S_AXI_AWREADY <= 1'b0;
            S_AXI_WREADY  <= 1'b0;
            S_AXI_BRESP   <= AXI_RESP_OKAY;
            S_AXI_BVALID  <= 1'b0;

            swap_request  <= 1'b0;

            vram_wr_en    <= 1'b0;
            vram_wr_addr  <= {VRAM_ADDR_WIDTH{1'b0}};
            vram_wr_data  <= {VRAM_DATA_WIDTH{1'b0}};
        end else begin
            S_AXI_AWREADY <= 1'b0;
            S_AXI_WREADY  <= 1'b0;
            swap_request  <= 1'b0;
            vram_wr_en    <= 1'b0;

            if (write_transfer) begin
                S_AXI_AWREADY <= 1'b1;
                S_AXI_WREADY  <= 1'b1;
                S_AXI_BVALID  <= 1'b1;

                if (write_addr_valid && write_strobe_valid) begin
                    S_AXI_BRESP  <= AXI_RESP_OKAY;

                    vram_wr_en   <= 1'b1;
                    vram_wr_addr <= axi_word_addr;
                    vram_wr_data <= S_AXI_WDATA[VRAM_DATA_WIDTH-1:0];
                end else if (swap_write_valid) begin
                    S_AXI_BRESP  <= AXI_RESP_OKAY;
                    swap_request <= 1'b1;

                    vram_wr_en   <= 1'b0;
                    vram_wr_addr <= {VRAM_ADDR_WIDTH{1'b0}};
                    vram_wr_data <= {VRAM_DATA_WIDTH{1'b0}};
                end else begin
                    S_AXI_BRESP  <= AXI_RESP_SLVERR;

                    vram_wr_en   <= 1'b0;
                    vram_wr_addr <= {VRAM_ADDR_WIDTH{1'b0}};
                    vram_wr_data <= {VRAM_DATA_WIDTH{1'b0}};
                end
            end else if (S_AXI_BVALID && S_AXI_BREADY) begin
                S_AXI_BVALID <= 1'b0;
                S_AXI_BRESP  <= AXI_RESP_OKAY;
            end
        end
    end

    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            S_AXI_ARREADY <= 1'b0;
            S_AXI_RDATA   <= {C_S_AXI_DATA_WIDTH{1'b0}};
            S_AXI_RRESP   <= AXI_RESP_OKAY;
            S_AXI_RVALID  <= 1'b0;
        end else begin
            S_AXI_ARREADY <= 1'b0;

            if (S_AXI_ARVALID && !S_AXI_RVALID) begin
                S_AXI_ARREADY <= 1'b1;
                S_AXI_RRESP   <= AXI_RESP_OKAY;
                S_AXI_RVALID  <= 1'b1;

                if (axi_read_word_addr == SWAP_CONTROL_WORD_ADDR) begin
                    S_AXI_RDATA <= 32'h44425546;
                end else begin
                    S_AXI_RDATA <= {C_S_AXI_DATA_WIDTH{1'b0}};
                end
            end else if (S_AXI_RVALID && S_AXI_RREADY) begin
                S_AXI_RVALID <= 1'b0;
                S_AXI_RRESP  <= AXI_RESP_OKAY;
            end
        end
    end

endmodule

`default_nettype wire
