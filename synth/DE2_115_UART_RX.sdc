# ==============================================================================
# Synopsys Design Constraints (.sdc)
# Clock 50 MHz (Chu kỳ 20.000 ns) tren kit DE2-115
# ==============================================================================

create_clock -period 20.000 -name CLOCK_50 [get_ports CLOCK_50]

# Tinh toan do khong chac chan cua xung clock
derive_clock_uncertainty
