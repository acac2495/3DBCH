`include "../2D_bch_datapath/ccp/ccp_top.v"
`include "../alt_impl/pe_onehot.v"

module slice_scheduler #(parameter N = 15, M = 4, T = 2, MAX_ITER = 100)(clk, rst, start_3d, load_3d, done_3d, fail_3d, iters, cube_in, cube_out);
    input clk, rst, start_3d, load_3d;
    input [N*N*N-1:0] cube_in;
    
    output reg done_3d, fail_3d;
    output reg [7:0] iters;
    output [N*N*N-1:0] cube_out;

    reg [N*N*N-1:0] cube;

    assign cube_out = cube;

    localparam IDLE = 0;
    localparam LOAD = 1;
    localparam SEND = 2;
    localparam WAIT = 3;
    localparam VERIFY = 4;
    localparam UPDATE = 5;
    localparam NEXT = 6;
    
    localparam IW = $clog2(N+1);

    //key registers

    reg [2:0] state;
    reg [1:0] pass_idx;
    reg [IW-1:0] view_idx;
    reg [11:0] sweep_flips;
    reg [N*N-1:0] r_in_2d;
    reg start_2d;
    reg [N*N-1:0] err_2d;

    wire done_2d;
    wire [N*N-1:0] c_out_2d;

    reg [N*N-1:0] slice_sel;

    integer r, c;
    
    //extracting slices
    always @(*) begin
        for (r = 0; r < N; r = r + 1) begin
            for (c = 0; c < N; c = c + 1) begin
                case (pass_idx)
                    2'd0:    slice_sel[r*N+c] = cube[(r*N + c)*N + view_idx];   // XY: x=r y=c z=i
                    2'd1:    slice_sel[r*N+c] = cube[(r*N + view_idx)*N + c];   // XZ: x=r y=i z=c
                    default: slice_sel[r*N+c] = cube[(view_idx*N + r)*N + c];   // YZ: x=i y=r z=c
                endcase
            end
        end
    end

    //priority encoder registers

    wire any;
    wire [3:0] rsel, csel;
    wire [N-1:0] row_oh, col_oh;

    //priority encoder

    pe_onehot #(.N(N)) PE (
        .any(any),
        .rsel(rsel),
        .csel(csel),
        .row_oh(row_oh),
        .col_oh(col_oh),
        .err(err_2d)
    );

    wire [N-1:0] v_oh;

    genvar gi, gx, gy, gz;

    generate
        for(gi = 0; gi < N; gi = gi + 1) begin
            assign v_oh[gi] = (view_idx == gi);
        end
    endgenerate

    //key registers for flip
    wire do_flip = (state == UPDATE) & any;
    wire [N-1:0] x_oh = ((pass_idx == 2'd2) ? v_oh : row_oh) & {N{do_flip}};
    wire [N-1:0] y_oh = (pass_idx == 2'd0) ? col_oh : (pass_idx == 2'd1) ? v_oh   : row_oh;
    wire [N-1:0] z_oh = (pass_idx == 2'd0) ? v_oh   : col_oh;

    //flipping the cube at the respective positions
    wire [N*N*N-1:0] flip_mask;
    generate
        for (gx = 0; gx < N; gx = gx + 1) begin : FX
            for (gy = 0; gy < N; gy = gy + 1) begin : FY
                for (gz = 0; gz < N; gz = gz + 1) begin : FZ
                    assign flip_mask[(gx*N + gy)*N + gz] = x_oh[gx] & y_oh[gy] & z_oh[gz];
                end
            end
        end
    endgenerate

    //generating a 2d flip at the respective coordinates
    wire [N*N-1:0] err_clr;
    genvar gr, gc;
    generate
        for (gr = 0; gr < N; gr = gr + 1) begin : ER
            for (gc = 0; gc < N; gc = gc + 1) begin : EC
                assign err_clr[gr*N + gc] = row_oh[gr] & col_oh[gc];
            end
        end
    endgenerate

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
            cube <= 0;
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
                    cube <= cube_in;
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
                    if (any) begin
                        err_2d      <= err_2d & ~err_clr;
                        cube        <= cube ^ flip_mask;      // flip_mask is 0 unless do_flip
                        sweep_flips <= sweep_flips + 1;
                    end
                    else if (view_idx == (N-1)) begin 
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
endmodule