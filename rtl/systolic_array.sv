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

    // Input skew registers.
    // a_pipe[r][s] holds a_row[r] delayed by s+1 cycles.
    // b_pipe[c][s] holds b_col[c] delayed by s+1 cycles.
    // v_pipe[s]    holds valid_in delayed by s+1 cycles.
    // Row r is fed from a_pipe[r][r-1] (r-cycle delay); row 0 bypasses the pipe.
    // Col c is fed from b_pipe[c][c-1] (c-cycle delay); col 0 bypasses the pipe.
    // This guarantees A[r][k] and B[k][c] arrive at PE[r][c] on the same cycle.

    logic [N-1:0][N-1:0][DATA_W-1:0] a_pipe;
    logic [N-1:0][N-1:0][DATA_W-1:0] b_pipe;
    logic [N-1:0]                     v_pipe;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            a_pipe <= '0;
            b_pipe <= '0;
            v_pipe <= '0;
        end else begin
            for (int r = 0; r < N; r++) begin
                a_pipe[r][0] <= a_row[r];
                for (int s = 1; s < N; s++)
                    a_pipe[r][s] <= a_pipe[r][s-1];
            end
            for (int c = 0; c < N; c++) begin
                b_pipe[c][0] <= b_col[c];
                for (int s = 1; s < N; s++)
                    b_pipe[c][s] <= b_pipe[c][s-1];
            end
            v_pipe[0] <= valid_in;
            for (int s = 1; s < N; s++)
                v_pipe[s] <= v_pipe[s-1];
        end
    end

    // PE array wires.
    // a_wire[r][c]: A data entering column stage c of row r.
    //   Flows left-to-right: PE[r][c] reads a_wire[r][c], writes a_wire[r][c+1].
    // b_wire[c][r]: B data entering row stage r of column c.
    //   Flows top-to-bottom: PE[r][c] reads b_wire[c][r], writes b_wire[c][r+1].
    // va[r][c]:    valid signal carried with A in row r at column stage c.

    logic [N-1:0][N:0][DATA_W-1:0] a_wire;
    logic [N-1:0][N:0][DATA_W-1:0] b_wire;
    logic [N-1:0][N:0]             va;

    for (genvar r = 0; r < N; r++) begin : g_a_edge
        if (r == 0) begin : g_direct
            assign a_wire[0][0] = a_row[0];
            assign va[0][0]     = valid_in;
        end else begin : g_skewed
            assign a_wire[r][0] = a_pipe[r][r-1];
            assign va[r][0]     = v_pipe[r-1];
        end
    end

    for (genvar c = 0; c < N; c++) begin : g_b_edge
        if (c == 0) begin : g_direct
            assign b_wire[0][0] = b_col[0];
        end else begin : g_skewed
            assign b_wire[c][0] = b_pipe[c][c-1];
        end
    end

    for (genvar r = 0; r < N; r++) begin : g_row
        for (genvar c = 0; c < N; c++) begin : g_col
            logic pe_vout;

            pe #(
                .DATA_W  (DATA_W),
                .ACCUM_W (ACCUM_W)
            ) u_pe (
                .clk       (clk),
                .rst_n     (rst_n),
                .a_in      (a_wire[r][c]),
                .b_in      (b_wire[c][r]),
                .valid_in  (va[r][c]),
                .ready_out (),
                .a_out     (a_wire[r][c+1]),
                .b_out     (b_wire[c][r+1]),
                .valid_out (pe_vout),
                .ready_in  (1'b1),
                .acc_clear (acc_clear),
                .accum     (result[r][c])
            );

            assign va[r][c+1] = pe_vout;
        end
    end

    assign ready_out = 1'b1;

    // valid_out timing:
    // A[r][k] enters left edge of row r at cycle k+r (k=0..N-1, skew=r).
    // It reaches PE[r][c] after c more cycles: arrival cycle = k+r+c.
    // B[k][c] enters top edge of col c at cycle k+c (skew=c).
    // It reaches PE[r][c] after r more cycles: arrival cycle = k+r+c.
    // Last product at PE[N-1][N-1]: k=N-1, r=N-1, c=N-1 -> cycle 3N-3.
    // PE registers it, so result is stable from cycle 3N-2 onward.
    // LATENCY = 3N-2 cycles from first valid_in to valid_out.

    localparam int LATENCY = 3 * N - 2;
    logic [LATENCY-1:0] vout_sr;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            vout_sr <= '0;
        end else begin
            vout_sr <= {vout_sr[LATENCY-2:0], valid_in};
        end
    end

    assign valid_out = vout_sr[LATENCY-1];

endmodule
