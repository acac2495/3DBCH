`include "../2D_bch_datapath/ccp/ccp_top.v"

module slice_scheduler #(parameter N = 15, M = 4, T = 2, MAX_ITER = 100)(clk, rst, start_3d, load_3d, done_3d, fail_3d, iters, cube_in, cube_out);
    input clk, rst, start_3d, load_3d;
    input [N*N*N-1:0] cube_in;
    
    output reg done_3d, fail_3d;
    output reg [7:0] iters;
    output [N*N*N-1:0] cube_out;

    localparam IDLE = 0;
    localparam LOAD = 1;
    localparam SEND = 2;
    localparam WAIT = 3;
    localparam VERIFY = 4;
    localparam UPDATE = 5;
    localparam NEXT = 6;
    
    localparam IW = $clog2(N+1);

    reg [2:0] state;
    reg [1:0] pass_idx;
    reg [IW-1:0] view_idx;

    reg [11:0] sweep_flips;

    reg [N*N-1:0] r_in_2d;
    reg start_2d;

    wire done_2d;
    wire [N*N-1:0] c_out_2d;
    reg [N*N-1:0] err_2d;

    reg [N*N-1:0] xy_arr [0:N-1];
    reg [N*N-1:0] xz_arr [0:N-1];
    reg [N*N-1:0] yz_arr [0:N-1];

    wire [N*N-1:0] slice_sel;
    assign slice_sel = (pass_idx == 0) ? xy_arr[view_idx] :
                       (pass_idx == 1) ? xz_arr[view_idx] :
                       yz_arr[view_idx];

    reg any;
    reg [IW-1:0] rsel, csel;
    reg [IW-1:0] ux, uy, uz;

    integer i1, j1;

    always @(*) begin
        any = 0; 
        rsel = 0; 
        csel = 0;
        for (i1 = N-1; i1 >= 0; i1 = i1-1) begin
            if (|err_2d[i1*N +: N]) begin 
                any = 1; 
                rsel = i1; 
            end
        end
        for (j1 = N-1; j1 >= 0; j1 = j1-1) begin
            if (err_2d[rsel*N + j1]) begin 
                csel = j1;
            end
        end
    end

    always @(*) begin
        case(pass_idx)
            2'b00: begin    //XY
                ux = rsel;
                uy = csel;
                uz = view_idx;
            end             //XZ
            2'b01: begin
                ux = rsel;
                uy = view_idx;
                uz = csel;
            end
            default : begin //YZ
                ux = view_idx;
                uy = rsel;
                uz = csel;
            end
        endcase
    end

    ccp_top #(.M(M), .N(N), .T(T)) dec_2d_inst (
        .clk(clk),
        .rst(rst),
        .r_in(r_in_2d),
        .start(start_2d),
        .c_out(c_out_2d),
        .done(done_2d)
    );

    integer i;
    integer lx, ly, lz;

    wire check1;

    assign check1 = (r_in_2d == err_2d);

    task print_arr;
        input [N*N-1:0] arr_in;
        integer p, q;
        begin
            for(p = 0; p < N; p = p + 1) begin
                for(q = 0; q < N; q = q + 1) begin
                    $write("%b ", arr_in[N*p + q]);
                end
                $display("");
            end
        end
    endtask

    function [2*8-1:0] pr_or;
        input [1:0] pass_idx;
        begin
            case(pass_idx)
                2'b00 : pr_or = "xy";
                2'b01 : pr_or = "xz";
                2'b10 : pr_or = "yz";
                default : pr_or = "xy";
            endcase
        end
    endfunction

    //super FSM

    always @(posedge clk) begin
        if(rst) begin
            done_3d <= 0;
            state <= IDLE;
            start_2d <= 0;
            r_in_2d <= 0;
            pass_idx <= 0;
            view_idx <= 0;
            fail_3d <= 0;
            err_2d <= 0;
            iters <= 0;
            sweep_flips <= 0;

            for(i = 0; i < N; i = i + 1) begin
                xy_arr[i] <= 0;
                xz_arr[i] <= 0;
                yz_arr[i] <= 0;
            end
        end
        else begin
            case(state)
                IDLE : begin
                    done_3d <= 0;
                    fail_3d <= 0;
                    err_2d <= 0;
                    if(load_3d) begin
                        state <= LOAD;
                    end
                    else if(start_3d) begin
                        state <= SEND;
                        pass_idx <= 0;
                        view_idx <= 0;
                    end
                    sweep_flips <= 0;
                    iters <= 0;
                end

                LOAD : begin
                    for (lx = 0; lx < N; lx = lx + 1)
                        for (ly = 0; ly < N; ly = ly + 1)
                            for (lz = 0; lz < N; lz = lz + 1) begin
                                xy_arr[lz][lx*N+ly] <= cube_in[(lx*N+ly)*N+lz];
                                xz_arr[ly][lx*N+lz] <= cube_in[(lx*N+ly)*N+lz];
                                yz_arr[lx][ly*N+lz] <= cube_in[(lx*N+ly)*N+lz];
                            end
                    state <= IDLE;
                end
                
                SEND : begin
                    r_in_2d <= slice_sel;
                    state <= WAIT;
                    start_2d <= 1;
                end

                WAIT : begin
                    start_2d <= 0;
                    if(done_2d) begin
                        state <= VERIFY;
                        err_2d <= c_out_2d;
                    end
                end

                VERIFY : begin
                    if(r_in_2d != 0) begin
                        $display("decoded slice : ");
                        print_arr(r_in_2d);
                        $display("received error : ");
                        print_arr(err_2d);
                    end
                    if(~check1) begin
                        $display("invalid error, slice correction rejected");
                        err_2d <= 0;
                    end
                    else if(check1 & (r_in_2d != 0))begin
                        $display("slice corrected");
                    end
                    state <= UPDATE;
                end

                UPDATE : begin
                    if(any) begin
                        err_2d[rsel*N + csel] <= 1'b0;
                        xy_arr[uz][ux*N+uy] <= ~xy_arr[uz][ux*N+uy];
                        xz_arr[uy][ux*N+uz] <= ~xz_arr[uy][ux*N+uz];
                        yz_arr[ux][uy*N+uz] <= ~yz_arr[ux][uy*N+uz];
                        sweep_flips <= sweep_flips + 1;
                    end
                    else if(view_idx == (N-1)) begin
                        state <= NEXT;
                    end
                    else begin
                        view_idx <= view_idx + 1;
                        state <= SEND;
                    end
                end

                NEXT : begin
                    view_idx <= 0;
                    $display("done iter : %0d, pass : %s, flips upto %s pass : %0d", iters, pr_or(pass_idx), pr_or(pass_idx), sweep_flips);
                    if(pass_idx != 2) begin
                        pass_idx <= pass_idx + 1;
                        state <= SEND;
                    end
                    else if(sweep_flips == 0) begin
                        done_3d <= 1;
                        state <= IDLE;
                    end
                    else if(iters == MAX_ITER - 1) begin
                        fail_3d <= 1;
                        done_3d <= 1;
                        state <= IDLE;
                    end
                    else begin
                        iters <= iters + 1;
                        pass_idx <= 0;
                        sweep_flips <= 0;
                        state <= SEND;
                    end
                end

                default : begin
                    state <= IDLE;
                end
            endcase
        end
    end

    genvar gx;
    generate
        for (gx = 0; gx < N; gx = gx + 1) begin : CUBE_OUT
            assign cube_out[gx*N*N +: N*N] = yz_arr[gx];
        end
    endgenerate

endmodule