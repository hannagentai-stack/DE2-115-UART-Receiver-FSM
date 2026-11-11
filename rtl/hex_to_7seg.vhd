--------------------------------------------------------------------------------
-- File Name: hex_to_7seg.vhd
-- Project  : UART Receiver using FSM on Terasic DE2-115
-- Author   : FPGA Design Engineer
-- Standard : VHDL-93 / VHDL-2008
-- Description:
--   Bộ giải mã số hexa 4-bit sang led 7 thanh a, b, c, d, e, f, g.
--   Lưu ý: Kit DE2-115 sử dụng LED 7 đoạn Anode chung tích cực mức thấp:
--          '0' = Sáng, '1' = Tắt.
--   Ánh xạ chân: seg bit 0..6 tương ứng với các đoạn a, b, c, d, e, f, g.
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity hex_to_7seg is
    port (
        hex_digit : in  std_logic_vector(3 downto 0);  -- Đầu vào 4-bit hexa từ 0 đến F
        seg       : out std_logic_vector(6 downto 0)   -- 7 đoạn g f e d c b a tích cực mức thấp
    );
end entity hex_to_7seg;

architecture rtl of hex_to_7seg is
begin
    -- Ánh xạ các đoạn [g f e d c b a] tương ứng với bit [6 5 4 3 2 1 0]
    process(hex_digit)
    begin
        case hex_digit is
            --                               gfedcba
            when x"0"   => seg <= "1000000"; -- '0': Tắt đoạn g
            when x"1"   => seg <= "1111001"; -- '1': Bật đoạn b, c
            when x"2"   => seg <= "0100100"; -- '2': Tắt đoạn c, f
            when x"3"   => seg <= "0110000"; -- '3': Tắt đoạn e, f
            when x"4"   => seg <= "0011001"; -- '4': Tắt đoạn a, d, e
            when x"5"   => seg <= "0010010"; -- '5': Tắt đoạn b, e
            when x"6"   => seg <= "0000010"; -- '6': Tắt đoạn b
            when x"7"   => seg <= "1111000"; -- '7': Bật đoạn a, b, c
            when x"8"   => seg <= "0000000"; -- '8': Bật tất cả các đoạn
            when x"9"   => seg <= "0010000"; -- '9': Tắt đoạn e
            when x"A"   => seg <= "0001000"; -- 'A': Tắt đoạn d
            when x"B"   => seg <= "0000011"; -- 'b': Tắt đoạn a, b
            when x"C"   => seg <= "1000110"; -- 'C': Tắt đoạn b, c, g
            when x"D"   => seg <= "0100001"; -- 'd': Tắt đoạn a, f
            when x"E"   => seg <= "0000110"; -- 'E': Tắt đoạn b, c
            when x"F"   => seg <= "0001110"; -- 'F': Tắt đoạn b, c, d
            when others => seg <= "1111111"; -- Tắt toàn bộ
        end case;
    end process;

end architecture rtl;
