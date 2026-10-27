module systolic_array #(
    parameter int N       = 4,
    parameter int DATA_W  = 8,
    parameter int ACCUM_W = 32
) (
    input  logic                              clk,
    input  logic                              rst_n,

    input  logic [N-1:0][DATA_W-1:0]         a_row,
    input  logic [N-1:0][DATA_W-1:0]         b_col,
    input  logic                              valid_in,
    output logic                              ready_out,

    output logic [N-1:0][N-1:0][ACCUM_W-1:0] result,
    output logic                              valid_out,
    input  logic                              ready_in,

    input  logic                              acc_clear
);

    logic [N:0][N-1:0][DATA_W-1:0]  a_wire;
    logic [N-1:0][N:0][DATA_W-1:0]  b_wire;
    logic [N:0][N-1:0]              v_h;
    logic [N-1:0][N:0]              v_v;
    logic [N:0][N-1:0]              r_h;
    logic [N-1:0][N:0]              r_v;

    for (genvar r = 0; r < N; r++) begin : g_row
        assign a_wire[0][r] = a_row[r];
        assign v_h[0][r]    = valid_in;
    end
    for (genvar c = 0; c < N; c++) begin : g_col
        assign b_wire[c][0] = b_col[c];
        assign v_v[c][0]    = valid_in;
    end

    assign ready_out = r_h[0][0];

    for (genvar r = 0; r < N; r++) begin : g_r
        for (genvar c = 0; c < N; c++) begin : g_c
            logic [ACCUM_W-1:0] pe_accum;

            pe #(
                .DATA_W  (DATA_W),
                .ACCUM_W (ACCUM_W)
            ) u_pe (
                .clk       (clk),
                .rst_n     (rst_n),
                .a_in      (a_wire[c][r]),
                .b_in      (b_wire[r][c]),
                .valid_in  (v_h[c][r] & v_v[r][c]),
                .ready_out (r_h[c][r]),
                .a_out     (a_wire[c+1][r]),
                .b_out     (b_wire[r][c+1]),
                .valid_out (v_h[c+1][r]),
                .ready_in  (r_h[c+1][r]),
                .acc_clear (acc_clear),
                .accum     (pe_accum)
            );

            assign result[r][c] = pe_accum;
        end
    end

    for (genvar r = 0; r < N; r++) begin : g_rtail
        assign r_h[N][r] = ready_in;
    end
    for (genvar c = 0; c < N; c++) begin : g_ctail
        assign r_v[c][N] = ready_in;
    end

    logic [N-1:0] col_valid_last;
    for (genvar c = 0; c < N; c++) begin : g_vout
        assign col_valid_last[c] = v_h[N][c];
    end

    assign valid_out = &col_valid_last;

endmodule
