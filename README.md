// ============================================================================
// Projeto: SafeCrack Pro
// Disciplina: Sistemas Digitais (CIN0130)
// Descrição: FSM de cofre eletrônico com navegação de dígitos
// ============================================================================

module safecrack_pro (
    input  logic        CLOCK_50,   // Clock de 50MHz da DE2-115
    input  logic  [3:0] KEY,        // Push buttons (Ativos em BAIXO)
                                    // KEY[0]: Reset
                                    // KEY[1]: Confirma/Avança
                                    // KEY[2]: Incrementa dígito
                                    // KEY[3]: Decrementa dígito
    output logic  [6:0] HEX0,       // Display do 4º dígito
    output logic  [6:0] HEX1,       // Display do 3º dígito
    output logic  [6:0] HEX2,       // Display do 2º dígito
    output logic  [6:0] HEX3,       // Display do 1º dígito
    output logic  [6:0] HEX4,       // Display do índice do dígito ativo
    output logic  [8:0] LEDG,       // LEDs Verdes (Sucesso)
    output logic [17:0] LEDR        // LEDs Vermelhos (Erro)
);

    // ========================================================================
    // 1. PARÂMETROS E DEFINIÇÕES
    // ========================================================================
    // A senha secreta (exemplo: 2-0-2-6)
    localparam logic [3:0] PASS_D1 = 4'd2; // Primeiro dígito (HEX3)
    localparam logic [3:0] PASS_D2 = 4'd0; // Segundo dígito (HEX2)
    localparam logic [3:0] PASS_D3 = 4'd2; // Terceiro dígito (HEX1)
    localparam logic [3:0] PASS_D4 = 4'd6; // Quarto dígito (HEX0)

    // Tempos baseados em clock de 50MHz
    localparam int TIMER_5_SEC = 250_000_000; // 5 segundos para sucesso
    localparam int TIMER_3_SEC = 150_000_000; // 3 segundos para erro

    // Estados da Máquina
    typedef enum logic [2:0] {
        EDIT_DIGIT,     // Usuário está mudando o valor do dígito atual
        CHECK_PASS,     // Verifica se a senha está correta
        SUCCESS_STATE,  // Acende LEDG por 5s
        ERROR_STATE     // Acende LEDR por 3s
    } state_t;

    state_t state, next_state;

    // Sinais internos
    logic rst_n;
    assign rst_n = KEY[0]; // Reset é o KEY[0] (Ativo em baixo)

    // ========================================================================
    // 2. DETECTOR DE BORDA (ANTI-DEDO PESADO)
    // ========================================================================
    logic [3:1] key_inv;     // Botões invertidos (Ativo ALTO)
    logic [3:1] key_prev;    // Estado anterior dos botões
    logic [3:1] key_edge;    // Pulso de 1 clock quando pressionado

    assign key_inv = ~KEY[3:1];

    always_ff @(posedge CLOCK_50 or negedge rst_n) begin
        if (!rst_n) begin
            key_prev <= 3'b000;
        end else begin
            key_prev <= key_inv;
        end
    end

    // Detecta transição de 0 para 1 (borda de subida realógica do botão)
    assign key_edge = key_inv & ~key_prev; 
    
    logic btn_conf, btn_up, btn_down;
    assign btn_conf = key_edge[1];
    assign btn_up   = key_edge[2];
    assign btn_down = key_edge[3];

    // ========================================================================
    // 3. DATAPATH (CONTROLE DOS DÍGITOS E TIMER)
    // ========================================================================
    logic [3:0] digits [3:0]; // array para os 4 dígitos: [3]=D1, [2]=D2, [1]=D3, [0]=D4
    logic [1:0] active_idx;   // Indica o dígito sendo editado (3 a 0)
    logic [27:0] timer_cnt;   // Contador para os segundos

    always_ff @(posedge CLOCK_50 or negedge rst_n) begin
        if (!rst_n) begin
            digits[3] <= 4'd0;
            digits[2] <= 4'd0;
            digits[1] <= 4'd0;
            digits[0] <= 4'd0;
            active_idx <= 2'd3; // Começa no primeiro dígito (índice 3, ligado ao HEX3)
            timer_cnt <= 28'd0;
        end else begin
            if (state == EDIT_DIGIT) begin
                // Lógica de Incremento (KEY2)
                if (btn_up) begin
                    if (digits[active_idx] == 4'd9)
                        digits[active_idx] <= 4'd0; // wrap-around
                    else
                        digits[active_idx] <= digits[active_idx] + 1'b1;
                end
                // Lógica de Decremento (KEY3)
                else if (btn_down) begin
                    if (digits[active_idx] == 4'd0)
                        digits[active_idx] <= 4'd9; // wrap-around
                    else
                        digits[active_idx] <= digits[active_idx] - 1'b1;
                end
                // Lógica de Confirmação (KEY1)
                else if (btn_conf) begin
                    if (active_idx != 2'd0) begin
                        active_idx <= active_idx - 1'b1; // Avança para o próximo dígito
                    end
                end
            end
            else if (state == SUCCESS_STATE || state == ERROR_STATE) begin
                // Decrementa timer se estiver nos estados finais
                if (timer_cnt > 0) timer_cnt <= timer_cnt - 1'b1;
            end
            
            // Carrega timer na transição para os estados finais
            if (state == CHECK_PASS) begin
                if (digits[3] == PASS_D1 && digits[2] == PASS_D2 && 
                    digits[1] == PASS_D3 && digits[0] == PASS_D4) begin
                    timer_cnt <= TIMER_5_SEC;
                end else begin
                    timer_cnt <= TIMER_3_SEC;
                end
            end
            
            // Reseta a interface quando volta do estado de Erro/Sucesso pro Edit
            if ((state == SUCCESS_STATE || state == ERROR_STATE) && timer_cnt == 0) begin
                digits[3] <= 4'd0;
                digits[2] <= 4'd0;
                digits[1] <= 4'd0;
                digits[0] <= 4'd0;
                active_idx <= 2'd3;
            end
        end
    end

    // ========================================================================
    // 4. MÁQUINA DE ESTADOS (FSM)
    // ========================================================================
    always_ff @(posedge CLOCK_50 or negedge rst_n) begin
        if (!rst_n) state <= EDIT_DIGIT;
        else state <= next_state;
    end

    always_comb begin
        next_state = state; // padrão: manter no mesmo estado
        
        case (state)
            EDIT_DIGIT: begin
                // Se apertar confirm e estiver no último dígito (idx 0), vai checar
                if (btn_conf && active_idx == 2'd0)
                    next_state = CHECK_PASS;
            end
            
            CHECK_PASS: begin
                // Verifica a senha no exato ciclo
                if (digits[3] == PASS_D1 && digits[2] == PASS_D2 && 
                    digits[1] == PASS_D3 && digits[0] == PASS_D4)
                    next_state = SUCCESS_STATE;
                else
                    next_state = ERROR_STATE;
            end
            
            SUCCESS_STATE: begin
                if (timer_cnt == 0) next_state = EDIT_DIGIT; // Acabou os 5s, reinicia
            end
            
            ERROR_STATE: begin
                if (timer_cnt == 0) next_state = EDIT_DIGIT; // Acabou os 3s, reinicia
            end
            
            default: next_state = EDIT_DIGIT;
        endcase
    end

    // Lógica de Saída (LEDs)
    always_comb begin
        LEDG = 9'd0;
        LEDR = 18'd0;
        if (state == SUCCESS_STATE) LEDG = {9{1'b1}};   // Liga todos verdes
        if (state == ERROR_STATE)   LEDR = {18{1'b1}};  // Liga todos vermelhos
    end

    // ========================================================================
    // 5. DECODIFICADORES DE DISPLAY DE 7 SEGMENTOS
    // ========================================================================
    
    // Função auxiliar para decodificar BCD para 7 Segmentos (Ativo em Baixo)
    function logic [6:0] bcd_to_7seg(input logic [3:0] bcd);
        case (bcd)
            4'd0: return 7'b1000000;
            4'd1: return 7'b1111001;
            4'd2: return 7'b0100100;
            4'd3: return 7'b0110000;
            4'd4: return 7'b0011001;
            4'd5: return 7'b0010010;
            4'd6: return 7'b0000010;
            4'd7: return 7'b1111000;
            4'd8: return 7'b0000000;
            4'd9: return 7'b0010000;
            default: return 7'b1111111; // Apagado
        endcase
    endfunction

    // Atribuindo os displays aos dígitos correspondentes
    assign HEX3 = bcd_to_7seg(digits[3]);
    assign HEX2 = bcd_to_7seg(digits[2]);
    assign HEX1 = bcd_to_7seg(digits[1]);
    assign HEX0 = bcd_to_7seg(digits[0]);

    // Visor HEX4 indicando a posição visual do dígito ativo (1, 2, 3 ou 4)
    logic [3:0] display_idx;
    always_comb begin
        case (active_idx)
            2'd3: display_idx = 4'd1; // Editando o 1º dígito
            2'd2: display_idx = 4'd2; // Editando o 2º dígito
            2'd1: display_idx = 4'd3; // Editando o 3º dígito
            2'd0: display_idx = 4'd4; // Editando o 4º dígito
            default: display_idx = 4'd0;
        endcase
    end
    
    assign HEX4 = bcd_to_7seg(display_idx);

endmodule
