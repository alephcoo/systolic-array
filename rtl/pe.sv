module pe #(
    parameter int DATA_W  = 8,
    parameter int ACCUM_W = 32
) (
    input  logic                  clk,
    input  logic                  rst_n,

    input  logic [DATA_W-1:0]     a_in,
    input  logic [DATA_W-1:0]     b_in,
    input  logic                  valid_in,
    output logic                  ready_out,

    output logic [DATA_W-1:0]     a_out,
    output logic [DATA_W-1:0]     b_out,
    output logic                  valid_out,
    input  logic                  ready_in,

    input  logic                  acc_clear,
    output logic [ACCUM_W-1:0]    accum
);

    logic signed [DATA_W-1:0]   a_s;
    logic signed [DATA_W-1:0]   b_s;
    logic signed [2*DATA_W-1:0] product;

    assign a_s    = a_in;
    assign b_s    = b_in;
    assign product = a_s * b_s;

    logic [ACCUM_W-1:0] accum_reg;
    logic stall;

    assign stall     = valid_in & ~ready_in;
    assign ready_out = ~stall;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            accum_reg <= '0;
            a_out     <= '0;
            b_out     <= '0;
            valid_out <= 1'b0;
        end else begin
            if (acc_clear) begin
                accum_reg <= '0;
            end else if (valid_in && ready_out) begin
                accum_reg <= accum_reg +
                    signed'({{(ACCUM_W - 2*DATA_W){product[2*DATA_W-1]}}, product});
            end

            if (!stall) begin
                a_out     <= a_in;
                b_out     <= b_in;
                valid_out <= valid_in;
            end
        end
    end

    assign accum = accum_reg;

endmodule
