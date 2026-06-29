`default_nettype none

//! @title Escritor AXI4-Lite hacia VRAM
//! @author Grupo Pong EL3313
//! @brief Recibe escrituras AXI4-Lite desde MicroBlaze y las convierte en escrituras lineales hacia la VRAM. Tambien expone un registro de control para solicitar el intercambio de buffers de video.

module axi_lite_vram_writer #(
    parameter C_S_AXI_DATA_WIDTH = 32,
    parameter C_S_AXI_ADDR_WIDTH = 17,
    parameter VRAM_ADDR_WIDTH    = 15,
    parameter VRAM_DATA_WIDTH    = 12,
    parameter VRAM_MEMORY_DEPTH  = 19200
)(
    input  wire                                  S_AXI_ACLK, //! Reloj de la interfaz AXI4-Lite.
    input  wire                                  S_AXI_ARESETN, //! Reset AXI activo en bajo.

    input  wire [C_S_AXI_ADDR_WIDTH-1:0]         S_AXI_AWADDR, //! Canal de direccion de escritura AXI4-Lite.
    input  wire [2:0]                            S_AXI_AWPROT, //! Canal de direccion de escritura AXI4-Lite.
    input  wire                                  S_AXI_AWVALID, //! Canal de direccion de escritura AXI4-Lite.
    output reg                                   S_AXI_AWREADY, //! Canal de direccion de escritura AXI4-Lite.

    input  wire [C_S_AXI_DATA_WIDTH-1:0]         S_AXI_WDATA, //! Canal de datos de escritura AXI4-Lite.
    input  wire [(C_S_AXI_DATA_WIDTH/8)-1:0]     S_AXI_WSTRB, //! Canal de datos de escritura AXI4-Lite.
    input  wire                                  S_AXI_WVALID, //! Canal de datos de escritura AXI4-Lite.
    output reg                                   S_AXI_WREADY, //! Canal de datos de escritura AXI4-Lite.

    output reg  [1:0]                            S_AXI_BRESP, //! Canal de respuesta de escritura AXI4-Lite.
    output reg                                   S_AXI_BVALID, //! Canal de respuesta de escritura AXI4-Lite.
    input  wire                                  S_AXI_BREADY, //! Canal de respuesta de escritura AXI4-Lite.

    input  wire [C_S_AXI_ADDR_WIDTH-1:0]         S_AXI_ARADDR, //! Canal de direccion de lectura AXI4-Lite.
    input  wire [2:0]                            S_AXI_ARPROT, //! Canal de direccion de lectura AXI4-Lite.
    input  wire                                  S_AXI_ARVALID, //! Canal de direccion de lectura AXI4-Lite.
    output reg                                   S_AXI_ARREADY, //! Canal de direccion de lectura AXI4-Lite.

    output reg  [C_S_AXI_DATA_WIDTH-1:0]         S_AXI_RDATA, //! Canal de datos de lectura AXI4-Lite.
    output reg  [1:0]                            S_AXI_RRESP, //! Canal de datos de lectura AXI4-Lite.
    output reg                                   S_AXI_RVALID, //! Canal de datos de lectura AXI4-Lite.
    input  wire                                  S_AXI_RREADY, //! Canal de datos de lectura AXI4-Lite.

    output reg                                   swap_request, //! Solicitud de intercambio de buffer de video.

    output reg                                   vram_wr_en, //! Habilitacion de escritura hacia VRAM.
    output reg  [VRAM_ADDR_WIDTH-1:0]            vram_wr_addr, //! Direccion lineal de escritura en VRAM.
    output reg  [VRAM_DATA_WIDTH-1:0]            vram_wr_data //! Dato RGB444 hacia VRAM.
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
