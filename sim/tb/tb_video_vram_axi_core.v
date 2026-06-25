`timescale 1ns/1ps
`default_nettype none

module tb_video_vram_axi_core;

    localparam CLK_PERIOD_NS = 10;

    reg         S_AXI_ACLK;
    reg         S_AXI_ARESETN;

    reg  [16:0] S_AXI_AWADDR;
    reg  [2:0]  S_AXI_AWPROT;
    reg         S_AXI_AWVALID;
    wire        S_AXI_AWREADY;

    reg  [31:0] S_AXI_WDATA;
    reg  [3:0]  S_AXI_WSTRB;
    reg         S_AXI_WVALID;
    wire        S_AXI_WREADY;

    wire [1:0]  S_AXI_BRESP;
    wire        S_AXI_BVALID;
    reg         S_AXI_BREADY;

    reg  [16:0] S_AXI_ARADDR;
    reg  [2:0]  S_AXI_ARPROT;
    reg         S_AXI_ARVALID;
    wire        S_AXI_ARREADY;

    wire [31:0] S_AXI_RDATA;
    wire [1:0]  S_AXI_RRESP;
    wire        S_AXI_RVALID;
    reg         S_AXI_RREADY;

    wire [3:0]  vga_red;
    wire [3:0]  vga_green;
    wire [3:0]  vga_blue;
    wire        vga_hsync;
    wire        vga_vsync;

    integer error_count;
    integer red_pixel_detected;
    integer green_pixel_detected;
    integer blue_pixel_detected;

    video_vram_axi_core dut (
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

        .vga_red(vga_red),
        .vga_green(vga_green),
        .vga_blue(vga_blue),
        .vga_hsync(vga_hsync),
        .vga_vsync(vga_vsync)
    );

    always #(CLK_PERIOD_NS / 2) S_AXI_ACLK = ~S_AXI_ACLK;

    task axi_write;
        input [16:0] axi_addr;
        input [31:0] axi_data;
        begin
            @(negedge S_AXI_ACLK);
            S_AXI_AWADDR  = axi_addr;
            S_AXI_AWVALID = 1'b1;
            S_AXI_WDATA   = axi_data;
            S_AXI_WSTRB   = 4'b1111;
            S_AXI_WVALID  = 1'b1;
            S_AXI_BREADY  = 1'b1;

            @(posedge S_AXI_ACLK);
            #1;

            if (S_AXI_AWREADY !== 1'b1) begin
                $display("ERROR: AWREADY no se activo.");
                error_count = error_count + 1;
            end

            if (S_AXI_WREADY !== 1'b1) begin
                $display("ERROR: WREADY no se activo.");
                error_count = error_count + 1;
            end

            if (S_AXI_BVALID !== 1'b1) begin
                $display("ERROR: BVALID no se activo.");
                error_count = error_count + 1;
            end

            if (S_AXI_BRESP !== 2'b00) begin
                $display("ERROR: BRESP incorrecto. valor=%b esperado=00", S_AXI_BRESP);
                error_count = error_count + 1;
            end

            @(negedge S_AXI_ACLK);
            S_AXI_AWVALID = 1'b0;
            S_AXI_WVALID  = 1'b0;

            @(posedge S_AXI_ACLK);
            #1;

            S_AXI_BREADY = 1'b0;
        end
    endtask

    initial begin
        S_AXI_ACLK = 1'b0;
        S_AXI_ARESETN = 1'b0;

        S_AXI_AWADDR = 17'd0;
        S_AXI_AWPROT = 3'b000;
        S_AXI_AWVALID = 1'b0;

        S_AXI_WDATA = 32'd0;
        S_AXI_WSTRB = 4'b0000;
        S_AXI_WVALID = 1'b0;

        S_AXI_BREADY = 1'b0;

        S_AXI_ARADDR = 17'd0;
        S_AXI_ARPROT = 3'b000;
        S_AXI_ARVALID = 1'b0;
        S_AXI_RREADY = 1'b0;

        error_count = 0;
        red_pixel_detected = 0;
        green_pixel_detected = 0;
        blue_pixel_detected = 0;

        repeat (10) @(posedge S_AXI_ACLK);
        S_AXI_ARESETN = 1'b1;

        // Escribir pixeles conocidos en VRAM:
        // pixel_index 0     -> offset 0      -> rojo
        // pixel_index 1     -> offset 4      -> verde
        // pixel_index 160   -> offset 640    -> azul
        axi_write(17'd0,   32'h00000F00);
        axi_write(17'd4,   32'h000000F0);
        axi_write(17'd640, 32'h0000000F);

        repeat (800 * 525 * 4) begin
            @(posedge S_AXI_ACLK);
            #1;

            if (dut.vga_timing_inst.video_active) begin
                if ((vga_red == 4'hF) && (vga_green == 4'h0) && (vga_blue == 4'h0)) begin
                    red_pixel_detected = 1;
                end

                if ((vga_red == 4'h0) && (vga_green == 4'hF) && (vga_blue == 4'h0)) begin
                    green_pixel_detected = 1;
                end

                if ((vga_red == 4'h0) && (vga_green == 4'h0) && (vga_blue == 4'hF)) begin
                    blue_pixel_detected = 1;
                end
            end
        end

        if (!red_pixel_detected) begin
            $display("ERROR: no se detecto pixel rojo escrito por AXI.");
            error_count = error_count + 1;
        end

        if (!green_pixel_detected) begin
            $display("ERROR: no se detecto pixel verde escrito por AXI.");
            error_count = error_count + 1;
        end

        if (!blue_pixel_detected) begin
            $display("ERROR: no se detecto pixel azul escrito por AXI.");
            error_count = error_count + 1;
        end

        if (error_count == 0) begin
            $display("TEST PASSED: video_vram_axi_core funciona correctamente.");
        end else begin
            $display("TEST FAILED: errores detectados = %0d", error_count);
        end

        $finish;
    end

endmodule

`default_nettype wire
