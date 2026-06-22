// Módulo: button_debounce
// Descrição: Sincroniza o sinal assíncrono do botão com o clock do sistema
//            e gera um pulso único de um ciclo de clock na borda de descida 
//            (quando o botão é pressionado, considerando lógica ativa em baixo).
// ============================================================================

module button_debounce (
    input  logic clk,        // Clock de amostragem do sistema (ex: 50 MHz)
    input  logic rst_n,      // Reset assíncrono (ativo em nível baixo)
    input  logic btn_raw,    // Sinal bruto vindo diretamente do pino físico do botão
    output logic btn_pulse   // Saída de pulso limpo com duração de 1 ciclo de clock
);

    //-------------------------------------------------------------------------
    // Sinais Internos (Flip-Flops de Sincronização e Histórico)
    //-------------------------------------------------------------------------
    // sync0 e sync1: Formam uma estrutura de 2 estágios para mitigar metaestabilidade
    // prev: Armazena o estado do botão no ciclo anterior para detecção de borda
    logic sync0, sync1, prev;
    
    //-------------------------------------------------------------------------
    // Bloco Sequencial: Sincronização e Shift Register
    //-------------------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Como os botões físicos da DE2-115 possuem resistores de pull-up,
            // o estado de repouso (solto) é nível lógico alto (1'b1).
            sync0 <= 1'b1;
            sync1 <= 1'b1;
            prev  <= 1'b1;
        end else begin
            sync0 <= btn_raw; // Captura o sinal assíncrono do mundo externo
            sync1 <= sync0;   // Sincroniza o sinal com o domínio de clock interno
            prev  <= sync1;   // Guarda o estado anterior para comparação de borda
        end
    end
    
    //-------------------------------------------------------------------------
    // Lógica Combinacional: Detector de Borda de Descida (Falling Edge)
    //-------------------------------------------------------------------------
    // O pulso é gerado quando o botão ESTAVA solto (prev == 1) 
    // e AGORA está pressionado (sync1 == 0).
    assign btn_pulse = prev & ~sync1;

endmodule
