# SafeCrack Pro - Cofre Eletrônico em FPGA

Este projeto implementa um jogo de cofre eletrônico desenvolvido em **SystemVerilog** para a placa de desenvolvimento **Altera/Intel DE2-115 (Cyclone IV E)**. O objetivo do jogo é adivinhar uma senha de 4 dígitos (configurada por padrão como `1-2-3-4`).

---

##  Descrição Detalhada dos Requisitos Implementados e Bugs Conhecidos

O sistema foi projetado seguindo as melhores práticas de design digital síncrono, dividindo-se em controle de periféricos, lógica de estados e interface visual.

1. **Tratamento de Entradas Assíncronas (Debounce e Sincronização):**
   Os botões físicos (`KEYs`) sofrem com o efeito de *bounce* mecânico e estão em um domínio de tempo diferente do clock do sistema. O módulo `button_debounce` utiliza um registrador de deslocamento de dois estágios para evitar problemas de metaestabilidade e gera um pulso de controle limpo de exatamente **1 ciclo de clock** na borda de descida (quando o botão é pressionado).

2. **Lógica de Controle e Validação (FSM):**
   A lógica principal reside em uma Máquina de Estados Finitos (FSM) síncrona operando a 50 MHz. 
   * Enquanto nos estados de digitação (`ST_DIGIT0` a `ST_DIGIT3`), os pulsos de `KEY[2]` e `KEY[3]` operam sobre um ponteiro indexado (`idx`), alterando o registrador do dígito atual.
   * O botão `KEY[1]` atua como o sinal de confirmação (Enter), avançando os estados.
   * No último dígito (`ST_DIGIT3`), ao pressionar `KEY[1]`, comparadores em paralelo validam o vetor armazenado contra a senha gravada em `localparam`.

3. **Temporização de Saídas (Sucesso e Falha):**
   Contadores de 28 bits baseados no clock de 50 MHz realizam a temporização dos efeitos visuais sem travar a execução do circuito:
   * **Sucesso:** Dispara um contador até 250.000.000 de ciclos (5 segundos), mantendo os LEDs verdes acesos e reiniciando o jogo automaticamente após o término.
   * **Falha:** Dispara um contador até 150.000.000 de ciclos (3 segundos), mantendo os LEDs vermelhos acesos e limpando a memória para uma nova tentativa após o término.

4. **Interface Visual Humana:**
   Os displays funcionam em lógica ativa em baixo (Anodo Comum). O array de memória é continuamente mapeado para os decodificadores de sete segmentos. Adicionalmente, uma lógica combinacional soma `4'd1` ao índice interno do estado da FSM e envia para o `HEX4`, exibindo dinamicamente para o usuário o número do dígito que ele está alterando (de 1 a 4).
   
5. **Bugs Conhecidos (Known Issues):**
   * **Falta de Auto-Repeat:** A lógica de debounce gera estritamente um pulso por pressionamento físico. Manter o botão de incremento (`KEY[2]`) pressionado não fará o número rolar automaticamente. O usuário deve clicar repetidamente.
   * **Interrupção de Animação via Reset:** O botão de reset (`KEY[0]`) é tratado de forma imediata dentro do bloco sequencial principal. Se acionado durante o bloqueio temporizado (`ST_SUCCESS` ou `ST_FAIL`), ele cancelará a animação em andamento, apagará os LEDs e forçará o retorno ao `ST_DIGIT0`.
   * **Falta de Feedback no Incremento de Limites:** Ao incrementar de 9 para 0 ou decrementar de 0 para 9, a transição é instantânea (wraparound). Não há feedback tátil ou visual para indicar que o limite foi atingido.

---

##  Diagrama de Estados (FSM)

Abaixo está o fluxo de transição da Máquina de Estados Finitos que dita as regras do sistema:

```text
       +--------------+
       |  ST_DIGIT0   |<----------------------------------+
       +--------------+                                   |
              |  (KEY[1] Pressionado)                     |
              v                                           |
       +--------------+                                   |
       |  ST_DIGIT1   |                                   |
       +--------------+                                   |
              |  (KEY[1] Pressionado)                     |
              v                                           |
       +--------------+                                   |
       |  ST_DIGIT2   |                                   |
       +--------------+                                   |
              |  (KEY[1] Pressionado)                     |
              v                                           |
       +--------------+                                   |
       |  ST_DIGIT3   |                                   |
       +--------------+                                   |
              |                                           |
              |-- (KEY[1] Pressionado & Senha Correta) -> | -> ST_SUCCESS (Liga LEDG por 5s)
              |                                           |
              +-- (KEY[1] Pressionado & Senha Incorreta)-> | -> ST_FAIL    (Liga LEDR por 3s)
