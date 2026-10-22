`include "slice_scheduler.v"
`timescale 1ns/1ns

module tb_slices;

    localparam N = 15;
    localparam T = 2;
    localparam M = 4;
    localparam MAX_ITER = 100;

    reg clk, rst, start_3d, load_3d;
    reg [N*N*N-1:0] cube_in_mem [0:0];

    reg [N*N*N-1:0] cube_in;

    wire done_3d, fail_3d;
    wire [7:0] iters;

    slice_scheduler #(.M(M), .T(T), .N(N), .MAX_ITER(MAX_ITER)) DUT(
        .clk(clk),
        .rst(rst),
        .start_3d(start_3d),
        .load_3d(load_3d),
        .done_3d(done_3d),
        .fail_3d(fail_3d),
        .iters(iters),
        .cube_in(cube_in)
    );

    always #5 clk = ~clk;

    initial begin
        $dumpfile("waveform.vcd");
        $dumpvars(0, tb_slices);

        clk = 0;
        rst = 1;
        start_3d = 0;
        load_3d = 0;

        $readmemh("cube_in.hex", cube_in_mem);
        cube_in = cube_in_mem[0];

        repeat (4) @(posedge clk);
        rst <= 0;
        repeat (2) @(posedge clk);

        load_3d <= 1; @(posedge clk); load_3d <= 0;
        repeat (4) @(posedge clk);

        start_3d <= 1; @(posedge clk); start_3d <= 0;
        wait (done_3d);
        $display("done: fail_3d=%b iters=%0d", fail_3d, iters);
        $finish;
    end

    initial begin
        #2_000_00;
        $display("TIMEOUT");
        $finish;
    end
endmodule