# Define o clock de 50 MHz (período de 20 ns)
create_clock -name CLOCK_50 -period 20.000 [get_ports CLOCK_50]

# Comandos padrão para análise de jitter e caminhos internos
derive_pll_clocks
derive_clock_uncertainty