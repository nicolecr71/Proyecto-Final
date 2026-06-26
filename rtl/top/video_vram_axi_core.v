`default_nettype none

module video_vram_axi_core #(
    parameter C_S_AXI_DATA_WIDTH = 32,
    parameter C_S_AXI_ADDR_WIDTH = 17
)(
    input  wire                                  S_AXI_ACLK,
    input  wire                                  S_AXI_ARESETN,

    input  wire [C_S_AXI_ADDR_WIDTH-1:0]         S_AXI_AWADDR,
    input  wire [2:0]                            S_AXI_AWPROT,
    input  wire                                  S_AXI_AWVALID,
    output wire                                  S_AXI_AWREADY,

    input  wire [C_S_AXI_DATA_WIDTH-1:0]         S_AXI_WDATA,
    input  wire [(C_S_AXI_DATA_WIDTH/8)-1:0]     S_AXI_WSTRB,
    input  wire                                  S_AXI_WVALID,
    output wire                                  S_AXI_WREADY,

    output wire [1:0]                            S_AXI_BRESP,
    output wire                                  S_AXI_BVALID,
    input  wire                                  S_AXI_BREADY,

    input  wire [C_S_AXI_ADDR_WIDTH-1:0]         S_AXI_ARADDR,
    input  wire [2:0]                            S_AXI_ARPROT,
    input  wire                                  S_AXI_ARVALID,
    output wire                                  S_AXI_ARREADY,

    output wire [C_S_AXI_DATA_WIDTH-1:0]         S_AXI_RDATA,
    output wire [1:0]                            S_AXI_RRESP,
    output wire                                  S_AXI_RVALID,
    input  wire                                  S_AXI_RREADY,

    output wire [3:0]                            vga_red,
    output wire [3:0]                            vga_green,
    output wire [3:0]                            vga_blue,
    output wire                                  vga_hsync,
    output wire                                  vga_vsync
);

    wire reset_active_high;

    wire pixel_tick;
    wire video_active;
    wire frame_tick;
    wire [9:0] pixel_x;
    wire [9:0] pixel_y;

    wire [14:0] vram_read_addr;
    wire        vram_read_active;
    wire [11:0] vram_read_data;

    wire        axi_vram_wr_en;
    wire [14:0] axi_vram_wr_addr;
    wire [11:0] axi_vram_wr_data;

    wire        swap_request;

    reg         front_bank;
    reg         swap_pending;

    assign reset_active_high = ~S_AXI_ARESETN;

    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            front_bank   <= 1'b0;
            swap_pending <= 1'b0;
        end else begin
            if (swap_request) begin
                swap_pending <= 1'b1;
            end

            if (frame_tick && swap_pending) begin
                front_bank   <= ~front_bank;
                swap_pending <= 1'b0;
            end
        end
    end

    pixel_tick_gen #(
        .DIVISOR(4)
    ) pixel_tick_gen_inst (
        .clk(S_AXI_ACLK),
        .rst(reset_active_high),
        .pixel_tick(pixel_tick)
    );

    vga_timing vga_timing_inst (
        .clk(S_AXI_ACLK),
        .rst(reset_active_high),
        .pixel_tick(pixel_tick),
        .hsync(vga_hsync),
        .vsync(vga_vsync),
        .video_active(video_active),
        .frame_tick(frame_tick),
        .pixel_x(pixel_x),
        .pixel_y(pixel_y)
    );

    vram_read_addr_gen vram_read_addr_gen_inst (
        .video_active(video_active),
        .pixel_x(pixel_x),
        .pixel_y(pixel_y),
        .vram_read_addr(vram_read_addr),
        .vram_read_active(vram_read_active)
    );

    axi_lite_vram_writer #(
        .C_S_AXI_DATA_WIDTH(C_S_AXI_DATA_WIDTH),
        .C_S_AXI_ADDR_WIDTH(C_S_AXI_ADDR_WIDTH),
        .VRAM_ADDR_WIDTH(15),
        .VRAM_DATA_WIDTH(12),
        .VRAM_MEMORY_DEPTH(19200)
    ) axi_lite_vram_writer_inst (
        .S_AXI_ACLK(S_AXI_ACLK),
        .S_AXI_ARESETN(S_AXI_ARESETN),

        .S_AXI_AWADDR(S_AXI_AWADDR),
        .S_AXI_AWPROT(S_AXI_AWPROT),
        .S_AXI_AWVALID(S_AXI_AWVALID),
        .S_AXI_AWREADY(S_AXI_AWREADY),

        .S_AXI_WDATA(S_AXI_WDATA),
        .S_AXI_WSTRB(S_AXI_WSTRB),
        .S_AXI_WVALID(S_AXI_WVALID),
        .S_AXI_WREADY(S_AXI_WREADY),

        .S_AXI_BRESP(S_AXI_BRESP),
        .S_AXI_BVALID(S_AXI_BVALID),
        .S_AXI_BREADY(S_AXI_BREADY),

        .S_AXI_ARADDR(S_AXI_ARADDR),
        .S_AXI_ARPROT(S_AXI_ARPROT),
        .S_AXI_ARVALID(S_AXI_ARVALID),
        .S_AXI_ARREADY(S_AXI_ARREADY),

        .S_AXI_RDATA(S_AXI_RDATA),
        .S_AXI_RRESP(S_AXI_RRESP),
        .S_AXI_RVALID(S_AXI_RVALID),
        .S_AXI_RREADY(S_AXI_RREADY),

        .swap_request(swap_request),

        .vram_wr_en(axi_vram_wr_en),
        .vram_wr_addr(axi_vram_wr_addr),
        .vram_wr_data(axi_vram_wr_data)
    );

    vram_dual_port #(
        .ADDR_WIDTH(15),
        .DATA_WIDTH(12),
        .MEMORY_DEPTH(19200)
    ) vram_dual_port_inst (
        .clk(S_AXI_ACLK),

        .wr_bank(~front_bank),
        .wr_en(axi_vram_wr_en),
        .wr_addr(axi_vram_wr_addr),
        .wr_data(axi_vram_wr_data),

        .rd_bank(front_bank),
        .rd_addr(vram_read_addr),
        .rd_data(vram_read_data)
    );

    assign vga_red   = vram_read_active ? vram_read_data[11:8] : 4'h0;
    assign vga_green = vram_read_active ? vram_read_data[7:4]  : 4'h0;
    assign vga_blue  = vram_read_active ? vram_read_data[3:0]  : 4'h0;

endmodule

`default_nettype wire
