`timescale 1ns/1ps

module tb_regfile;
    // RTL regfile dùng @(posedge i_clk or negedge i_rstn).
    // Reset bất đồng bộ, tích cực mức thấp.
    parameter bit ASYNC_RESET = 1'b1;

    logic        i_clk = 0;
    logic        i_rstn;
    logic [4:0]  i_rs1_addr, i_rs2_addr;
    logic [4:0]  i_rd_addr;
    logic [31:0] i_rd_data;
    logic        i_rd_wren;
    wire  [31:0] o_rs1_data, o_rs2_data;

    integer i;
    integer errors = 0;
    integer errors_before = 0;
    integer passed_tests = 0;
    integer failed_tests = 0;
    integer test_items = 0;
    integer passed_items = 0;

    regfile dut (
        .i_clk      (i_clk),
        .i_rstn     (i_rstn),
        .i_rs1_addr (i_rs1_addr),
        .i_rs2_addr (i_rs2_addr),
        .i_rd_addr  (i_rd_addr),
        .i_rd_data  (i_rd_data),
        .i_rd_wren  (i_rd_wren),
        .o_rs1_data (o_rs1_data),
        .o_rs2_data (o_rs2_data)
    );

    always #5 i_clk = ~i_clk;

    // Đặt tín hiệu ở cạnh xuống, giữ qua cạnh lên ghi dữ liệu.
    task automatic write_reg(input logic [4:0] addr,
                             input logic [31:0] data,
                             input logic enable);
        @(negedge i_clk);
        i_rd_addr = addr;
        i_rd_data = data;
        i_rd_wren = enable;
        @(posedge i_clk);
        #1;
        @(negedge i_clk);
        i_rd_wren = 0;
    endtask

    // Chờ 0.1 ns cho NBA/logic tổ hợp ổn định rồi kiểm tra cả hai cổng.
    // 32 lượt chỉ mất 3.2 ns, đủ kiểm tra reset trước cạnh lên kế tiếp.
    task automatic check_read(input logic [31:0] expected1,
                              input logic [31:0] expected2);
        bit item_passed;
        #0.1;
        // Một item đạt khi cả hai cổng đúng và không có X/Z ngoài kỳ vọng.
        item_passed = (o_rs1_data === expected1) &&
                      (o_rs2_data === expected2);
        test_items = test_items + 1;
        if (item_passed)
            passed_items = passed_items + 1;
        else
            errors = errors + 1;

        $display("[%0t]   rs1=x%0d Expected=%0d Actual=%0d | rs2=x%0d Expected=%0d Actual=%0d -> %s",
                 $realtime, i_rs1_addr, expected1, o_rs1_data,
                 i_rs2_addr, expected2, o_rs2_data,
                 item_passed ? "PASSED" : "FAILED");
    endtask

    task automatic start_test(input string test_name);
        errors_before = errors;
        test_items = 0;
        passed_items = 0;
        $display("");
        $display("[%0t] %s:", $realtime, test_name);
    endtask

    // Tổng kết số item đạt/tổng item của riêng test hiện tại.
    task automatic report_test(input string test_name);
        if (errors == errors_before) begin
            passed_tests = passed_tests + 1;
            $display("[%0t] %s Finish - PASSED %0d/%0d",
                     $realtime, test_name, passed_items, test_items);
        end else begin
            failed_tests = failed_tests + 1;
            $display("[%0t] %s Finish - FAILED (PASSED %0d/%0d)",
                     $realtime, test_name, passed_items, test_items);
        end
    endtask

    initial begin
        $timeformat(-9, 1, " ns", 0);
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_regfile);

        i_rstn = 0;
        i_rs1_addr = 0;
        i_rs2_addr = 0;
        i_rd_addr = 0;
        i_rd_data = 0;
        i_rd_wren = 0;

        $display("Reset expectation: %s",
                 ASYNC_RESET ? "asynchronous" : "synchronous");

        // Reset khởi tạo, phù hợp với cả hai kiểu reset.
        @(posedge i_clk);
        #1;
        @(negedge i_clk);
        i_rstn = 1;

        // TC01: Ghi khác 0 vào mọi thanh ghi, sau đó kiểm tra reset.
        start_test("TC1 Asynchronous Reset");
        for (i = 1; i < 32; i = i + 1)
            write_reg(i, i * 10, 1'b1);

        // Xác nhận dữ liệu trước reset để tránh PASS do thanh ghi đã là 0.
        for (i = 0; i < 32; i = i + 1) begin
            i_rs1_addr = i;
            i_rs2_addr = 31 - i;
            check_read(i * 10, (31 - i) * 10);
        end

        @(negedge i_clk);
        i_rstn = 0;
        // Toàn bộ vòng lặp kết thúc trước cạnh lên kế tiếp (3.2 < 5 ns).
        for (i = 0; i < 32; i = i + 1) begin
            i_rs1_addr = i;
            i_rs2_addr = 31 - i;
            if (ASYNC_RESET)
                check_read(32'd0, 32'd0);
            else
                check_read(i * 10, (31 - i) * 10);
        end

        @(posedge i_clk);
        #1;
        for (i = 0; i < 32; i = i + 1) begin
            i_rs1_addr = i;
            i_rs2_addr = 31 - i;
            check_read(32'd0, 32'd0);
        end
        @(negedge i_clk);
        i_rstn = 1;
        report_test("TC1");

        // TC02: Ghi x1..x31, đọc đủ 32 địa chỉ trên từng cổng.
        start_test("TC2 Write and Read All Registers");
        for (i = 1; i < 32; i = i + 1)
            write_reg(i, i * 10, 1'b1);
        for (i = 0; i < 32; i = i + 1) begin
            i_rs1_addr = i;
            i_rs2_addr = 31 - i;
            check_read(i * 10, (31 - i) * 10);
        end
        report_test("TC2");

        // TC03: Thử ghi mọi thanh ghi khi write enable bằng 0.
        start_test("TC3 Write Enable");
        for (i = 1; i < 32; i = i + 1)
            write_reg(i, 32'd999, 1'b0);
        for (i = 0; i < 32; i = i + 1) begin
            i_rs1_addr = i;
            i_rs2_addr = 31 - i;
            check_read(i * 10, (31 - i) * 10);
        end
        report_test("TC3");

        // TC04: Bốn lần đổi địa chỉ/kiểm tra trong cùng nửa chu kỳ thấp.
        start_test("TC4 Asynchronous Read");
        @(negedge i_clk);
        i_rd_wren = 0;
        i_rs1_addr = 1;
        i_rs2_addr = 2;
        check_read(32'd10, 32'd20);
        i_rs1_addr = 5;
        i_rs2_addr = 10;
        check_read(32'd50, 32'd100);
        i_rs1_addr = 31;
        i_rs2_addr = 0;
        check_read(32'd310, 32'd0);
        i_rs1_addr = 7;
        i_rs2_addr = 7;
        check_read(32'd70, 32'd70);
        report_test("TC4");

        // TC05: x0 vẫn bằng 0 dù được yêu cầu ghi toàn bit 1.
        start_test("TC5 x0 Protection");
        write_reg(5'd0, 32'hFFFFFFFF, 1'b1);
        i_rs1_addr = 0;
        i_rs2_addr = 0;
        check_read(32'd0, 32'd0);
        report_test("TC5");

        // TC06: Hai cổng cùng đọc x5 trong khi chuẩn bị ghi đè.
        start_test("TC6 Overwrite and Simultaneous Read");
        @(negedge i_clk);
        i_rs1_addr = 5;
        i_rs2_addr = 5;
        i_rd_addr = 5;
        i_rd_data = 200;
        i_rd_wren = 1;
        check_read(32'd50, 32'd50);
        @(posedge i_clk);
        #1;
        check_read(32'd200, 32'd200);
        @(negedge i_clk);
        i_rd_wren = 0;
        report_test("TC6");

        $display("SUMMARY: %0d PASS, %0d FAIL, %0d errors",
                 passed_tests, failed_tests, errors);
        if (errors == 0)
            $finish;
        else
            $fatal(1, "Register file verification failed");
    end
endmodule
