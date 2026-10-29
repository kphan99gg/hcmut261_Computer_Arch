
module regfile (
    // Clock and Reset.
    input  logic        i_clk,
    input  logic        i_rstn,

    // Read Port 1
    input  logic [4:0]  i_rs1_addr,
    output logic [31:0] o_rs1_data,

    // Read Port 2
    input  logic [4:0]  i_rs2_addr,
    output logic [31:0] o_rs2_data,

    // Write Port
    input  logic [4:0]  i_rd_addr,
    input  logic [31:0] i_rd_data,
    input  logic        i_rd_wren
);

    // 31 registers: x1 to x31
    // x0 is not implemented using Flip-Flops.
    logic [31:0] registers [1:31];

    // -----------------------------------------
    // Asynchronous Read Port 1
    // -----------------------------------------
    always_comb begin
        if (i_rs1_addr == 5'd0)
            o_rs1_data = 32'b0;
        else
            o_rs1_data = registers[i_rs1_addr];
    end

    // -----------------------------------------
    // Asynchronous Read Port 2
    // -----------------------------------------
    always_comb begin
        if (i_rs2_addr == 5'd0)
            o_rs2_data = 32'b0;
        else
            o_rs2_data = registers[i_rs2_addr];
    end

    // -----------------------------------------
    // Synchronous Write + Asynchronous Reset
    // -----------------------------------------
    always_ff @(posedge i_clk or negedge i_rstn) begin
        if (!i_rstn) begin
            for (int i = 1; i < 32; i++) begin
                registers[i] <= 32'b0;
            end
        end
        else if (i_rd_wren && (i_rd_addr != 5'd0)) begin
            registers[i_rd_addr] <= i_rd_data;
        end
    end

endmodule
