--------------------------------------------------------------------------------
-- File Name: pulse_stretcher.vhd
-- Project  : UART Receiver using FSM on Terasic DE2-115
-- Author   : FPGA Design Engineer
-- Standard : VHDL-93 / VHDL-2008
-- Description:
--   Mạch kéo dài xung (Pulse Stretcher).
--   Xung rx_done chỉ tồn tại trong 1 chu kỳ clock (20 ns @ 50 MHz), mắt người
--   không thể nhìn thấy LED chớp tắt. Mạch này kéo dài xung lên khoảng 100 ms
--   (5,000,000 chu kỳ clock tại 50 MHz) để quan sát rõ ràng trên LEDG[8].
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pulse_stretcher is
    generic (
        PULSE_CLOCKS : natural := 5_000_000 -- Số chu kỳ clock duy trì mức '1' (100 ms @ 50 MHz)
    );
    port (
        clk      : in  std_logic; -- Clock hệ thống 50 MHz
        rst_n    : in  std_logic; -- Reset bất đồng bộ tích cực mức thấp
        pulse_in : in  std_logic; -- Xung đầu vào (rộng 1 chu kỳ clock)
        pulse_out: out std_logic  -- Xung đầu ra kéo dài mức cao
    );
end entity pulse_stretcher;

architecture rtl of pulse_stretcher is
    signal count_reg : natural range 0 to PULSE_CLOCKS := 0;
    signal out_reg   : std_logic := '0';
begin

    process(clk, rst_n)
    begin
        if rst_n = '0' then
            count_reg <= 0;
            out_reg   <= '0';
        elsif rising_edge(clk) then
            if pulse_in = '1' then
                count_reg <= PULSE_CLOCKS;
                out_reg   <= '1';
            elsif count_reg > 0 then
                count_reg <= count_reg - 1;
                out_reg   <= '1';
            else
                out_reg   <= '0';
            end if;
        end if;
    end process;

    pulse_out <= out_reg;

end architecture rtl;
