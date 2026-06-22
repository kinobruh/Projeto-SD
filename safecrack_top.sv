module safecrack_top (
    input  logic        CLOCK_50,
    input  logic [3:0]  KEY,
    output logic [6:0]  HEX0, HEX1, HEX2, HEX3, HEX4,
    output logic [8:0]  LEDG,
    output logic [17:0] LEDR
);

    // Sinais limpos dos botões após debounce
    logic k0, k1, k2, k3;

    button_debounce db0(.clk(CLOCK_50), .rst_n(1'b1), .btn_raw(KEY[0]), .btn_pulse(k0));
    button_debounce db1(.clk(CLOCK_50), .rst_n(1'b1), .btn_raw(KEY[1]), .btn_pulse(k1));
    button_debounce db2(.clk(CLOCK_50), .rst_n(1'b1), .btn_raw(KEY[2]), .btn_pulse(k2));
    button_debounce db3(.clk(CLOCK_50), .rst_n(1'b1), .btn_raw(KEY[3]), .btn_pulse(k3));

    // Senha padrão do cofre: 1-2-3-4
    localparam [3:0] S0 = 4'd1, S1 = 4'd2, S2 = 4'd3, S3 = 4'd4;

    // Estados da FSM
    localparam [2:0]
        ST_DIGIT0  = 3'd0,
        ST_DIGIT1  = 3'd1,
        ST_DIGIT2  = 3'd2,
        ST_DIGIT3  = 3'd3,
        ST_SUCCESS = 3'd4,
        ST_FAIL    = 3'd5;

    // Registradores de controle
    logic [2:0]  state;
    logic [3:0]  digits [0:3];
    logic [27:0] timer;
    logic        leds_green;
    logic        leds_red;

    // Ponteiro para o dígito atual
    logic [1:0] idx;
    assign idx = state[1:0]; 

    // Lógica sequencial da Maquina de Estados
    always_ff @(posedge CLOCK_50) begin
        if (k0) begin
            state      <= ST_DIGIT0;
            timer      <= 28'd0;
            leds_green <= 1'b0;
            leds_red   <= 1'b0;
            digits[0]  <= 4'd0;
            digits[1]  <= 4'd0;
            digits[2]  <= 4'd0;
            digits[3]  <= 4'd0;
        end else begin
            case (state)
                ST_DIGIT0, ST_DIGIT1, ST_DIGIT2, ST_DIGIT3: begin
                    if (k2) // Incrementa número (0 a 9)
                        digits[idx] <= (digits[idx] == 4'd9) ? 4'd0 : digits[idx] + 4'd1;
                    
                    if (k3) // Decrementa número (9 a 0)
                        digits[idx] <= (digits[idx] == 4'd0) ? 4'd9 : digits[idx] - 4'd1;
                        
                    if (k1) begin // Confirma dígito selecionado
                        if (state == ST_DIGIT3) begin
                            // Validação da senha completa
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
                    if (timer == 28'd249_999_999) begin // Mantém ativo por 5 segundos
                        timer      <= 28'd0;
                        leds_green <= 1'b0;
                        state      <= ST_DIGIT0;
                        digits[0]  <= 4'd0; digits[1] <= 4'd0;
                        digits[2]  <= 4'd0; digits[3] <= 4'd0;
                    end else
                        timer <= timer + 28'd1;
                end

                ST_FAIL: begin
                    leds_red <= 1'b1;
                    if (timer == 28'd149_999_999) begin // Mantém ativo por 3 segundos
                        timer    <= 28'd0;
                        leds_red <= 1'b0;
                        state    <= ST_DIGIT0;
                        digits[0] <= 4'd0; digits[1] <= 4'd0;
                        digits[2] <= 4'd0; digits[3] <= 4'd0;
                    end else
                        timer <= timer + 28'd1;
                end

                default: state <= ST_DIGIT0;
            endcase
        end
    end

    // Instanciação dos Decodificadores nos Displays de 7 segmentos
    seg7_decoder d0(.digit(digits[3]), .seg(HEX0)); 
    seg7_decoder d1(.digit(digits[2]), .seg(HEX1));
    seg7_decoder d2(.digit(digits[1]), .seg(HEX2));
    seg7_decoder d3(.digit(digits[0]), .seg(HEX3)); 

    // Indica o dígito atual no HEX4 (Ajustado para exibição de 1 a 4)
    logic [3:0] idx_humano;
    assign idx_humano = {2'b00, idx} + 4'd1;
    seg7_decoder d4(.digit(idx_humano), .seg(HEX4));

    // Atribuição das saídas dos barramentos de LEDs
    assign LEDG = {9{leds_green}};
    assign LEDR = {18{leds_red}};

endmodule
