`timescale 1ns / 1ps

module tb_spi_game_slave_reference;

    localparam FRAME_BYTES = 24;

    reg clk;
    reg rst_n;

    reg spi_cs_n;
    reg spi_sck;
    reg spi_mosi;
    wire spi_miso;

    reg p2_up_i;
    reg p2_down_i;
    reg p2_start_i;
    reg p2_reset_i;

    wire [15:0] frame_id_o;
    wire [15:0] ball_x_o;
    wire [15:0] ball_y_o;
    wire [15:0] paddle_p1_y_o;
    wire [15:0] paddle_p2_y_o;

    wire [7:0] score_p1_o;
    wire [7:0] score_p2_o;
    wire [7:0] status_o;
    wire [7:0] winner_o;
    wire [7:0] last_point_o;
    wire [15:0] elapsed_seconds_o;
    wire signed [7:0] serve_direction_o;
    wire [7:0] flags_o;

    wire state_valid_o;

    reg [7:0] master_tx [0:FRAME_BYTES-1];
    reg [7:0] master_rx [0:FRAME_BYTES-1];

    reg saw_state_valid;
    integer errors;
    integer i;

    spi_game_slave_reference dut (
        .clk(clk),
        .rst_n(rst_n),

        .spi_cs_n(spi_cs_n),
        .spi_sck(spi_sck),
        .spi_mosi(spi_mosi),
        .spi_miso(spi_miso),

        .p2_up_i(p2_up_i),
        .p2_down_i(p2_down_i),
        .p2_start_i(p2_start_i),
        .p2_reset_i(p2_reset_i),

        .frame_id_o(frame_id_o),
        .ball_x_o(ball_x_o),
        .ball_y_o(ball_y_o),
        .paddle_p1_y_o(paddle_p1_y_o),
        .paddle_p2_y_o(paddle_p2_y_o),

        .score_p1_o(score_p1_o),
        .score_p2_o(score_p2_o),
        .status_o(status_o),
        .winner_o(winner_o),
        .last_point_o(last_point_o),
        .elapsed_seconds_o(elapsed_seconds_o),
        .serve_direction_o(serve_direction_o),
        .flags_o(flags_o),

        .state_valid_o(state_valid_o)
    );

    always #5 clk = ~clk;

    always @(posedge clk) begin
        if (!rst_n) begin
            saw_state_valid <= 1'b0;
        end else if (state_valid_o) begin
            saw_state_valid <= 1'b1;
        end
    end

    function [7:0] checksum_state;
        input integer count;
        integer k;
        begin
            checksum_state = 8'h00;
            for (k = 0; k < count; k = k + 1) begin
                checksum_state = checksum_state ^ master_tx[k];
            end
        end
    endfunction

    task put_u16_le;
        input integer index;
        input [15:0] value;
        begin
            master_tx[index]     = value[7:0];
            master_tx[index + 1] = value[15:8];
        end
    endtask

    task build_state_packet;
        begin
            for (i = 0; i < FRAME_BYTES; i = i + 1) begin
                master_tx[i] = 8'h00;
                master_rx[i] = 8'h00;
            end

            master_tx[0] = 8'h02;

            put_u16_le(1, 16'h1234);
            put_u16_le(3, 16'd77);
            put_u16_le(5, 16'd22);
            put_u16_le(7, 16'd30);
            put_u16_le(9, 16'd70);

            master_tx[11] = 8'd3;
            master_tx[12] = 8'd4;
            master_tx[13] = 8'd1;
            master_tx[14] = 8'd0;
            master_tx[15] = 8'd2;

            put_u16_le(16, 16'd9);

            master_tx[18] = 8'hFF;
            master_tx[19] = 8'h04;

            master_tx[20] = 8'h00;
            master_tx[21] = 8'h00;
            master_tx[22] = 8'h00;

            master_tx[23] = checksum_state(23);
        end
    endtask

    task spi_transfer_byte;
        input [7:0] tx_byte;
        output [7:0] rx_byte;
        integer bit_i;
        begin
            rx_byte = 8'h00;

            for (bit_i = 7; bit_i >= 0; bit_i = bit_i - 1) begin
                spi_mosi = tx_byte[bit_i];

                #100;
                spi_sck = 1'b1;

                #50;
                rx_byte[bit_i] = spi_miso;

                #50;
                spi_sck = 1'b0;

                #100;
            end
        end
    endtask

    task spi_transfer_frame;
        integer byte_i;
        reg [7:0] rx_byte;
        begin
            spi_cs_n = 1'b0;
            #300;

            for (byte_i = 0; byte_i < FRAME_BYTES; byte_i = byte_i + 1) begin
                spi_transfer_byte(master_tx[byte_i], rx_byte);
                master_rx[byte_i] = rx_byte;
            end

            #200;
            spi_cs_n = 1'b1;
            #1000;
        end
    endtask

    task check_equal_8;
        input [7:0] actual;
        input [7:0] expected;
        input [127:0] name;
        begin
            if (actual !== expected) begin
                $display("ERROR: %0s actual=0x%02h expected=0x%02h", name, actual, expected);
                errors = errors + 1;
            end
        end
    endtask

    task check_equal_16;
        input [15:0] actual;
        input [15:0] expected;
        input [127:0] name;
        begin
            if (actual !== expected) begin
                $display("ERROR: %0s actual=0x%04h expected=0x%04h", name, actual, expected);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;

        spi_cs_n = 1'b1;
        spi_sck = 1'b0;
        spi_mosi = 1'b0;

        p2_up_i = 1'b1;
        p2_down_i = 1'b0;
        p2_start_i = 1'b1;
        p2_reset_i = 1'b0;

        errors = 0;

        #200;
        rst_n = 1'b1;
        #200;

        build_state_packet();
        spi_transfer_frame();

        check_equal_8(master_rx[0], 8'h01, "miso_packet_type");
        check_equal_8(master_rx[1], 8'h00, "miso_frame_id");
        check_equal_8(master_rx[2], 8'h01, "miso_up");
        check_equal_8(master_rx[3], 8'h00, "miso_down");
        check_equal_8(master_rx[4], 8'h01, "miso_start");
        check_equal_8(master_rx[5], 8'h00, "miso_reset");
        check_equal_8(master_rx[6], 8'h01, "miso_checksum");

        if (!saw_state_valid) begin
            $display("ERROR: state_valid_o never asserted");
            errors = errors + 1;
        end

        check_equal_16(frame_id_o, 16'h1234, "frame_id_o");
        check_equal_16(ball_x_o, 16'd77, "ball_x_o");
        check_equal_16(ball_y_o, 16'd22, "ball_y_o");
        check_equal_16(paddle_p1_y_o, 16'd30, "paddle_p1_y_o");
        check_equal_16(paddle_p2_y_o, 16'd70, "paddle_p2_y_o");

        check_equal_8(score_p1_o, 8'd3, "score_p1_o");
        check_equal_8(score_p2_o, 8'd4, "score_p2_o");
        check_equal_8(status_o, 8'd1, "status_o");
        check_equal_8(winner_o, 8'd0, "winner_o");
        check_equal_8(last_point_o, 8'd2, "last_point_o");
        check_equal_16(elapsed_seconds_o, 16'd9, "elapsed_seconds_o");
        check_equal_8(serve_direction_o, 8'hFF, "serve_direction_o");
        check_equal_8(flags_o, 8'h04, "flags_o");

        if (errors == 0) begin
            $display("TEST PASSED: spi_game_slave_reference");
        end else begin
            $display("TEST FAILED: %0d errors", errors);
        end

        $finish;
    end

endmodule
