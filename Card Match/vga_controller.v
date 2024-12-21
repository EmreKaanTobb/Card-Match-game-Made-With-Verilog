`timescale 1ns / 1ps

module vga_controller(
    input clk,  // 25 MHz clock
    output reg hsync,
    output reg vsync,
    output reg [9:0] x,  // X coordinate (0-639)
    output reg [8:0] y,  // Y coordinate (0-479)
    output reg active_video
);
    reg [9:0] h_count = 0;
    reg [9:0] v_count = 0;

    // Horizontal timing parameters
    parameter H_SYNC = 96;
    parameter H_BACK = 48;
    parameter H_ACTIVE = 640;
    parameter H_FRONT = 16;
    parameter H_TOTAL = 800;

    // Vertical timing parameters
    parameter V_SYNC = 2;
    parameter V_BACK = 33;
    parameter V_ACTIVE = 480;
    parameter V_FRONT = 10;
    parameter V_TOTAL = 525;

    always @(posedge clk) begin
        if (h_count == H_TOTAL - 1) begin
            h_count <= 0;
            if (v_count == V_TOTAL - 1) begin
                v_count <= 0;
            end else begin
                v_count <= v_count + 1;
            end
        end else begin
            h_count <= h_count + 1;
        end

        // Generate hsync and vsync signals
        hsync <= (h_count < H_SYNC) ? 0 : 1;
        vsync <= (v_count < V_SYNC) ? 0 : 1;

        // Calculate active video region
        active_video <= (h_count >= H_SYNC + H_BACK && h_count < H_SYNC + H_BACK + H_ACTIVE) &&
                        (v_count >= V_SYNC + V_BACK && v_count < V_SYNC + V_BACK + V_ACTIVE);

        // Calculate pixel coordinates
        x <= (h_count >= H_SYNC + H_BACK) ? h_count - (H_SYNC + H_BACK) : 0;
        y <= (v_count >= V_SYNC + V_BACK) ? v_count - (V_SYNC + V_BACK) : 0;
    end
endmodule