module pe_onehot #(parameter N = 15)(
    input  [N*N-1:0] err,
    output           any,
    output reg [3:0] rsel, csel,
    output [N-1:0] row_oh, col_oh
);

    wire [N-1:0] row_nz;
    genvar g;
    generate
        for (g = 0; g < N; g = g + 1) begin : RNZ
            assign row_nz[g] = |err[g*N +: N];
        end
    endgenerate

    assign any = |row_nz;

    assign row_oh = row_nz & (~row_nz + 1'b1);   // isolate lowest set row

    integer i;
    reg [N-1:0] row_bits;
    always @(*) begin                                  // AND-OR select of that row
        row_bits = 0;
        rsel = 0;
        for (i = 0; i < N; i = i + 1) begin
            if (row_oh[i]) begin
                row_bits = row_bits | err[i*N +: N];
                rsel = rsel | i[3:0];
            end
        end
    end

    assign col_oh = row_bits & (~row_bits + 1'b1);  // isolate lowest set column
    integer j;
    always @(*) begin
        csel = 0;
        for (j = 0; j < N; j = j + 1)
            if (col_oh[j]) csel = csel | j[3:0];
    end
endmodule