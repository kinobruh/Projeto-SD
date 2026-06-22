module button_debounce (
    input  logic clk,
    input  logic rst_n,
    input  logic btn_raw,
    output logic btn_pulse
);
    logic sync0, sync1, prev;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sync0 <= 1'b1;
            sync1 <= 1'b1;
            prev  <= 1'b1;
        end else begin
            sync0 <= btn_raw;
            sync1 <= sync0;
            prev  <= sync1;
        end
    end
    
    // Detecta borda de descida (botão pressionado, ativo baixo)
    assign btn_pulse = prev & ~sync1;
endmodule