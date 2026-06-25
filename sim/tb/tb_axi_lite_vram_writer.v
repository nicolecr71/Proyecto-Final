`timescale 1ns/1ps
`default_nettype none

module tb_axi_lite_vram_writer;

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

    wire        vram_wr_en;
    wire [14:0] vram_wr_addr;
    wire [11:0] vram_wr_data;

    integer error_count;

    axi_lite_vram_writer dut (
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

        .vram_wr_en(vram_wr_en),
        .vram_wr_addr(vram_wr_addr),
        .vram_wr_data(vram_wr_data)
    );

    always #(CLK_PERIOD_NS / 2) S_AXI_ACLK = ~S_AXI_ACLK;

    task axi_write_and_check;
        input [16:0] axi_addr;
        input [31:0] axi_data;
        input [3:0]  axi_wstrb;
        input        expected_vram_wr_en;
        input [14:0] expected_vram_addr;
        input [11:0] expected_vram_data;
        input [1:0]  expected_bresp;
        begin
            @(negedge S_AXI_ACLK);
            S_AXI_AWADDR  = axi_addr;
            S_AXI_AWVALID = 1'b1;
            S_AXI_WDATA   = axi_data;
            S_AXI_WSTRB   = axi_wstrb;
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

            if (S_AXI_BRESP !== expected_bresp) begin
                $display("ERROR: BRESP incorrecto. valor=%b esperado=%b",
                    S_AXI_BRESP, expected_bresp);
                error_count = error_count + 1;
            end

            if (vram_wr_en !== expected_vram_wr_en) begin
                $display("ERROR: vram_wr_en incorrecto. valor=%b esperado=%b",
                    vram_wr_en, expected_vram_wr_en);
                error_count = error_count + 1;
            end

            if (vram_wr_addr !== expected_vram_addr) begin
                $display("ERROR: vram_wr_addr incorrecto. valor=%0d esperado=%0d",
                    vram_wr_addr, expected_vram_addr);
                error_count = error_count + 1;
            end

            if (vram_wr_data !== expected_vram_data) begin
                $display("ERROR: vram_wr_data incorrecto. valor=%h esperado=%h",
                    vram_wr_data, expected_vram_data);
                error_count = error_count + 1;
            end

            @(negedge S_AXI_ACLK);
            S_AXI_AWVALID = 1'b0;
            S_AXI_WVALID  = 1'b0;

            @(posedge S_AXI_ACLK);
            #1;
        end
    endtask

    task axi_read_and_check_zero;
        input [16:0] axi_addr;
        begin
            @(negedge S_AXI_ACLK);
            S_AXI_ARADDR  = axi_addr;
            S_AXI_ARVALID = 1'b1;
            S_AXI_RREADY  = 1'b1;

            @(posedge S_AXI_ACLK);
            #1;

            if (S_AXI_ARREADY !== 1'b1) begin
                $display("ERROR: ARREADY no se activo.");
                error_count = error_count + 1;
            end

            if (S_AXI_RVALID !== 1'b1) begin
                $display("ERROR: RVALID no se activo.");
                error_count = error_count + 1;
            end

            if (S_AXI_RDATA !== 32'h00000000) begin
                $display("ERROR: RDATA incorrecto. valor=%h esperado=00000000",
                    S_AXI_RDATA);
                error_count = error_count + 1;
            end

            if (S_AXI_RRESP !== 2'b00) begin
                $display("ERROR: RRESP incorrecto. valor=%b esperado=00",
                    S_AXI_RRESP);
                error_count = error_count + 1;
            end

            @(negedge S_AXI_ACLK);
            S_AXI_ARVALID = 1'b0;

            @(posedge S_AXI_ACLK);
            #1;
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

        repeat (5) @(posedge S_AXI_ACLK);
        S_AXI_ARESETN = 1'b1;

        // Pixel 0: offset = 0 * 4 = 0
        axi_write_and_check(
            17'd0,
            32'h00000F00,
            4'b1111,
            1'b1,
            15'd0,
            12'hF00,
            2'b00
        );

        // Pixel 1: offset = 1 * 4 = 4
        axi_write_and_check(
            17'd4,
            32'h000000F0,
            4'b1111,
            1'b1,
            15'd1,
            12'h0F0,
            2'b00
        );

        // Pixel de segunda fila: pixel_index = 160, offset = 640
        axi_write_and_check(
            17'd640,
            32'h0000000F,
            4'b1111,
            1'b1,
            15'd160,
            12'h00F,
            2'b00
        );

        // Centro: pixel_index = 9680, offset = 38720
        axi_write_and_check(
            17'd38720,
            32'h00000FFF,
            4'b1111,
            1'b1,
            15'd9680,
            12'hFFF,
            2'b00
        );

        // Último pixel válido: pixel_index = 19199, offset = 76796
        axi_write_and_check(
            17'd76796,
            32'h00000555,
            4'b1111,
            1'b1,
            15'd19199,
            12'h555,
            2'b00
        );

        // Dirección fuera de rango: pixel_index = 19200, offset = 76800
        axi_write_and_check(
            17'd76800,
            32'h00000AAA,
            4'b1111,
            1'b0,
            15'd0,
            12'h000,
            2'b10
        );

        // Strobe inválido para RGB444.
        axi_write_and_check(
            17'd0,
            32'h00000BBB,
            4'b0001,
            1'b0,
            15'd0,
            12'h000,
            2'b10
        );

        // Lectura básica: por ahora debe devolver cero.
        axi_read_and_check_zero(17'd0);

        if (error_count == 0) begin
            $display("TEST PASSED: axi_lite_vram_writer funciona correctamente.");
        end else begin
            $display("TEST FAILED: errores detectados = %0d", error_count);
        end

        $finish;
    end

endmodule

`default_nettype wire
