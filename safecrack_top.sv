module safecrack_top (
    input  logic        CLOCK_50,
    input  logic [3:0]  KEY,
    output logic [6:0]  HEX0, HEX1, HEX2, HEX3, HEX4,
    output logic [8:0]  LEDG,
    output logic [17:0] LEDR
);

    // Sinais de pulso dos botões após debounce
    logic k0, k1, k2, k3;

    // KEY[0] é o Reset Geral do sistema
    button_debounce db0(.clk(CLOCK_50), .rst_n(1'b1), .btn_raw(KEY[0]), .btn_pulse(k0));
    button_debounce db1(.clk(CLOCK_50), .rst_n(1'b1), .btn_raw(KEY[1]), .btn_pulse(k1));
    button_debounce db2(.clk(CLOCK_50), .rst_n(1'b1), .btn_raw(KEY[2]), .btn_pulse(k2));
    button_debounce db3(.clk(CLOCK_50), .rst_n(1'b1), .btn_raw(KEY[3]), .btn_pulse(k3));

    // Senha correta definida no projeto: 1-2-3-4
    localparam [3:0] S0 = 4'd1, S1 = 4'd2, S2 = 4'd3, S3 = 4'd4;

    // Estados da FSM
    localparam [2:0]
        ST_DIGIT0  = 3'd0,
        ST_DIGIT1  = 3'd1,
        ST_DIGIT2  = 3'd2,
        ST_DIGIT3  = 3'd3,
        ST_SUCCESS = 3'd4,
        ST_FAIL    = 3'd5;

    reg [2:0]  state;
    reg [3:0]  digits [0:3];   // Armazena os números digitados
    reg [27:0] timer;
    reg        leds_green;
    reg        leds_red;

    // Índice do display ativo baseado no estado
    wire [1:0] idx = state[1:0]; 

    integer i;

    always @(posedge CLOCK_50) begin
        if (k0) begin
            // Reset do sistema para o estado inicial
            state      <= ST_DIGIT0;
            timer      <= 28'd0;
            leds_green <= 1'b0;
            leds_red   <= 1'b0;
            for (i = 0; i < 4; i = i + 1)
                digits[i] <= 4'd0;
        end else begin
            case (state)
                ST_DIGIT0, ST_DIGIT1, ST_DIGIT2, ST_DIGIT3: begin
                    if (k2) // Incrementa o dígito do display atual
                        digits[idx] <= (digits[idx] == 4'd9) ? 4'd0 : digits[idx] + 4'd1;
                    
                    if (k3) // Decrementa o dígito do display atual
                        digits[idx] <= (digits[idx] == 4'd0) ? 4'd9 : digits[idx] - 4'd1;
                        
                    if (k1) begin // Confirma o dígito e avança
                        if (state == ST_DIGIT3) begin
                            // Validação da senha de ponta a ponta
                            if (digits[0] == S0 && digits[1] == S1 &&
                                digits[2] == S2 && digits[3] == S3)
                                state <= ST_SUCCESS;
                            else
                                state <= ST_FAIL;
                        end else begin
                            state <= state + 3'd1;
                        end
                    end
                end

                ST_SUCCESS: begin
                    leds_green <= 1'b1;
                    if (timer == 28'd249_999_999) begin
                        timer      <= 28'd0;
                        leds_green <= 1'b0;
                        state      <= ST_DIGIT0;
                        for (i = 0; i < 4; i = i + 1)
                            digits[i] <= 4'd0;
                    end else
                        timer <= timer + 28'd1;
                end

                ST_FAIL: begin
                    leds_red <= 1'b1;
                    if (timer == 28'd149_999_999) begin
                        timer    <= 28'd0;
                        leds_red <= 1'b0;
                        state    <= ST_DIGIT0;
                        for (i = 0; i < 4; i = i + 1)
                            digits[i] <= 4'd0;
                    end else
                        timer <= timer + 28'd1;
                end

                default: state <= ST_DIGIT0;
            endcase
        end
    end

    // Conexão direta dos registradores
    seg7_decoder d0(.digit(digits[3]), .seg(HEX0)); 
    seg7_decoder d1(.digit(digits[2]), .seg(HEX1));
    seg7_decoder d2(.digit(digits[1]), .seg(HEX2));
    seg7_decoder d3(.digit(digits[0]), .seg(HEX3)); 
    

    wire [3:0] idx_humano = {2'b00, idx} + 4'd1;
    seg7_decoder d4(.digit(idx_humano), .seg(HEX4));

    assign LEDG = {9{leds_green}};
    assign LEDR = {18{leds_red}};

endmodule