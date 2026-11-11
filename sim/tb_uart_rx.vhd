--------------------------------------------------------------------------------
-- File Name: tb_uart_rx.vhd
-- Project  : UART Receiver using FSM on Terasic DE2-115
-- Author   : FPGA Design Engineer
-- Standard : VHDL-93 / VHDL-2008
-- Description:
--   Testbench tu kiem tra cho khoi uart_rx:
--   1. Tao clock 50 MHz va chuoi reset ban dau.
--   2. Procedure phat khung UART chuan: Start + 8 Data LSB first + Stop.
--   3. Kich ban 1: Gui lan luot cac byte chuan 0x55, 0xAA, 0x00, 0xFF, 0x3C.
--   4. Kich ban 2: Gui 2 byte lien tiep khong co khoang nghi.
--   5. Kich ban 3: Gui Stop bit sai o muc '0' -> kiem tra frame_err va chan rx_done.
--   6. Kich ban 4: Xung nhieu nhon nho hon 8 ticks -> kiem tra bo loc nhieu.
--   7. Kich ban 5: Reset bat dong bo giua chung khi dang nhan du lieu.
--   8. Co che monitor bat xung dong bo, khong bi race condition.
--   9. Tu dong dung mo phong khi hoan tat tat ca kich ban.
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_uart_rx is
end entity tb_uart_rx;

architecture sim of tb_uart_rx is

    ----------------------------------------------------------------------------
    -- Hang so mo phong
    ----------------------------------------------------------------------------
    constant CLK_FREQ_C    : natural := 50_000_000;
    constant BAUD_RATE_C   : natural := 115_200;
    constant CLK_PERIOD    : time := 20 ns; -- 50 MHz
    constant BAUD_PERIOD   : time := 1 sec / BAUD_RATE_C; -- ~8680.55 ns

    ----------------------------------------------------------------------------
    -- Tin hieu ket noi DUT
    ----------------------------------------------------------------------------
    signal clk           : std_logic := '0';
    signal rst_n         : std_logic := '0';
    signal rx            : std_logic := '1';
    signal rx_data       : std_logic_vector(7 downto 0);
    signal rx_done       : std_logic;
    signal frame_err     : std_logic;
    signal parity_err    : std_logic;
    signal fsm_state_dbg : std_logic_vector(3 downto 0);

    -- Co dieu khien ket thuc mo phong
    signal sim_done      : boolean := false;
    signal sim_error_cnt : integer := 0;

    -- Tin hieu monitor chot xung rx_done va frame_err
    signal rx_done_latched   : std_logic := '0';
    signal rx_data_latched   : std_logic_vector(7 downto 0) := (others => '0');
    signal frame_err_latched : std_logic := '0';
    signal clear_latches     : std_logic := '0';

    ----------------------------------------------------------------------------
    -- Procedure gui 1 byte UART noi tiep
    ----------------------------------------------------------------------------
    procedure uart_send_byte (
        signal serial_out : out std_logic;
        constant data_in  : in  std_logic_vector(7 downto 0);
        constant bit_time : in  time;
        constant stop_bit : in  std_logic := '1'
    ) is
    begin
        -- 1. Start bit muc '0'
        serial_out <= '0';
        wait for bit_time;

        -- 2. 8 bit du lieu, truyen LSB truoc
        for i in 0 to 7 loop
            serial_out <= data_in(i);
            wait for bit_time;
        end loop;

        -- 3. Stop bit
        serial_out <= stop_bit;
        wait for bit_time;
    end procedure;

begin

    ----------------------------------------------------------------------------
    -- 1. DUT INSTANTIATION
    ----------------------------------------------------------------------------
    dut : entity work.uart_rx
        generic map (
            CLK_FREQ    => CLK_FREQ_C,
            BAUD_RATE   => BAUD_RATE_C,
            DATA_BITS   => 8,
            PARITY_EN   => false,
            PARITY_ODD  => false
        )
        port map (
            clk           => clk,
            rst_n         => rst_n,
            rx            => rx,
            rx_data       => rx_data,
            rx_done       => rx_done,
            frame_err     => frame_err,
            parity_err    => parity_err,
            fsm_state_dbg => fsm_state_dbg
        );

    ----------------------------------------------------------------------------
    -- 2. TAO CLOCK 50 MHz, TU DONG DUNG KHI sim_done = true
    ----------------------------------------------------------------------------
    clk_process : process
    begin
        while not sim_done loop
            clk <= '0';
            wait for CLK_PERIOD / 2;
            clk <= '1';
            wait for CLK_PERIOD / 2;
        end loop;
        wait;
    end process;

    ----------------------------------------------------------------------------
    -- 3. MONITOR PROCESS CHOT CAC XUNG RX_DONE VA FRAME_ERR
    ----------------------------------------------------------------------------
    monitor_proc : process(clk, rst_n)
    begin
        if rst_n = '0' then
            rx_done_latched   <= '0';
            rx_data_latched   <= (others => '0');
            frame_err_latched <= '0';
        elsif rising_edge(clk) then
            if clear_latches = '1' then
                rx_done_latched   <= '0';
                frame_err_latched <= '0';
            else
                if rx_done = '1' then
                    rx_done_latched <= '1';
                    rx_data_latched <= rx_data;
                end if;
                if frame_err = '1' then
                    frame_err_latched <= '1';
                end if;
            end if;
        end if;
    end process;

    ----------------------------------------------------------------------------
    -- 4. QUY TRINH KICH THICH VA KIEM TRA TU DONG
    ----------------------------------------------------------------------------
    stimulus_process : process
        type byte_array_t is array (0 to 4) of std_logic_vector(7 downto 0);
        constant test_bytes : byte_array_t := (x"55", x"AA", x"00", x"FF", x"3C");
    begin
        report "==========================================================";
        report ">>> BAT DAU MO PHONG KIEM CHUNG UART RECEIVER FSM <<<";
        report "==========================================================";

        -- Khoi tao
        rx            <= '1';
        rst_n         <= '0';
        clear_latches <= '0';
        wait for 100 ns;
        rst_n         <= '1';
        wait for 200 ns;

        ------------------------------------------------------------------------
        -- KICH BAN 1: Gui cac byte don le 0x55, 0xAA, 0x00, 0xFF, 0x3C
        ------------------------------------------------------------------------
        report "--- [KICH BAN 1] Kiem tra truyen cac byte don le ---";
        for i in test_bytes'range loop
            report "Dang truyen byte: 0x" & to_hstring(test_bytes(i));
            
            -- Xoa chot truoc khi gui
            clear_latches <= '1';
            wait for CLK_PERIOD;
            clear_latches <= '0';
            wait for CLK_PERIOD;

            -- Gui byte
            uart_send_byte(rx, test_bytes(i), BAUD_PERIOD, '1');

            -- Kiem tra ket qua sau khi truyen xong khung
            assert rx_done_latched = '1'
                report "[FAIL] Kich ban 1: Khong bat duoc rx_done cho byte 0x" & to_hstring(test_bytes(i))
                severity error;
            
            assert rx_data_latched = test_bytes(i)
                report "[FAIL] Kich ban 1: Sai du lieu! Ky vong 0x" & to_hstring(test_bytes(i)) &
                       ", Nhan duoc 0x" & to_hstring(rx_data_latched)
                severity error;

            if rx_done_latched = '1' and rx_data_latched = test_bytes(i) then
                report "  => [PASS] Nhan thanh cong byte: 0x" & to_hstring(rx_data_latched);
            else
                sim_error_cnt <= sim_error_cnt + 1;
            end if;

            wait for 2 * BAUD_PERIOD;
        end loop;

        ------------------------------------------------------------------------
        -- KICH BAN 2: Gui 2 byte lien tiep khong khoang nghi
        ------------------------------------------------------------------------
        report "--- [KICH BAN 2] Kiem tra truyen lien tiep: 0x12 noi tiep 0x34 ---";
        clear_latches <= '1';
        wait for CLK_PERIOD;
        clear_latches <= '0';
        wait for CLK_PERIOD;

        -- Gui byte 1 la 0x12
        uart_send_byte(rx, x"12", BAUD_PERIOD, '1');
        assert rx_done_latched = '1' and rx_data_latched = x"12"
            report "[FAIL] Kich ban 2 - Byte 1: Khong nhan dung 0x12"
            severity error;
        if rx_done_latched = '1' and rx_data_latched = x"12" then
            report "  => [PASS] Byte 1 0x12 hop le";
        else
            sim_error_cnt <= sim_error_cnt + 1;
        end if;

        -- Xoa chot va gui ngay byte 2 la 0x34 khong nghi
        clear_latches <= '1';
        wait for CLK_PERIOD;
        clear_latches <= '0';
        wait for CLK_PERIOD;

        uart_send_byte(rx, x"34", BAUD_PERIOD, '1');
        assert rx_done_latched = '1' and rx_data_latched = x"34"
            report "[FAIL] Kich ban 2 - Byte 2: Khong nhan dung 0x34"
            severity error;
        if rx_done_latched = '1' and rx_data_latched = x"34" then
            report "  => [PASS] Byte 2 0x34 hop le, truyen lien tiep hoat dong hoan hao";
        else
            sim_error_cnt <= sim_error_cnt + 1;
        end if;

        wait for 2 * BAUD_PERIOD;

        ------------------------------------------------------------------------
        -- KICH BAN 3: Stop bit sai o muc '0' -> Kiem tra Framing Error
        ------------------------------------------------------------------------
        report "--- [KICH BAN 3] Kiem tra Framing Error khi Stop bit = '0' ---";
        clear_latches <= '1';
        wait for CLK_PERIOD;
        clear_latches <= '0';
        wait for CLK_PERIOD;

        report "Dang gui byte 0xA5 voi Stop bit = '0'...";
        uart_send_byte(rx, x"A5", BAUD_PERIOD, stop_bit => '0');

        assert frame_err_latched = '1'
            report "[FAIL] Kich ban 3: Khong bat duoc frame_err khi Stop bit = '0'!"
            severity error;
        assert rx_done_latched = '0'
            report "[FAIL] Kich ban 3: rx_done bi bat khi co loi khung!"
            severity error;

        if frame_err_latched = '1' and rx_done_latched = '0' then
            report "  => [PASS] Framing Error duoc phat hien chinh xac, rx_done bi chan";
        else
            sim_error_cnt <= sim_error_cnt + 1;
        end if;

        -- Tra duong truyen ve Idle
        rx <= '1';
        wait for 2 * BAUD_PERIOD;

        ------------------------------------------------------------------------
        -- KICH BAN 4: Xung nhieu ngan nho hon 8 ticks -> Bo loc nhieu
        ------------------------------------------------------------------------
        report "--- [KICH BAN 4] Kiem tra bo loc nhieu Start bit ---";
        clear_latches <= '1';
        wait for CLK_PERIOD;
        clear_latches <= '0';
        wait for CLK_PERIOD;

        report "Tao xung nhieu muc '0' rong 3 ticks ~ 1.6 us...";
        rx <= '0';
        wait for 3 * (BAUD_PERIOD / 16);
        rx <= '1';
        wait for 2 * BAUD_PERIOD;

        assert rx_done_latched = '0'
            report "[FAIL] Kich ban 4: Xung nhieu kich hoat nham rx_done!"
            severity error;
        assert fsm_state_dbg = "0000"
            report "[FAIL] Kich ban 4: FSM khong quay ve IDLE!"
            severity error;

        if rx_done_latched = '0' and fsm_state_dbg = "0000" then
            report "  => [PASS] Xung nhieu da bi loai bo, FSM duy tri IDLE";
        else
            sim_error_cnt <= sim_error_cnt + 1;
        end if;

        wait for 2 * BAUD_PERIOD;

        ------------------------------------------------------------------------
        -- KICH BAN 5: Reset bat dong bo giua chung
        ------------------------------------------------------------------------
        report "--- [KICH BAN 5] Kiem tra Reset bat dong bo giua khung truyen ---";
        clear_latches <= '1';
        wait for CLK_PERIOD;
        clear_latches <= '0';
        wait for CLK_PERIOD;

        rx <= '0'; wait for BAUD_PERIOD;     -- Start bit
        rx <= '1'; wait for BAUD_PERIOD;     -- Bit 0
        rx <= '0'; wait for BAUD_PERIOD / 2; -- Giua bit 1

        report "Kich hoat rst_n = '0' bat dong bo giua chung...";
        rst_n <= '0';
        wait for 200 ns;
        rst_n <= '1';
        rx    <= '1';
        wait for 100 ns;

        assert fsm_state_dbg = "0000"
            report "[FAIL] Kich ban 5: FSM khong tro ve IDLE sau reset!"
            severity error;
        assert rx_done_latched = '0'
            report "[FAIL] Kich ban 5: Phat sinh xung gia rx_done sau reset!"
            severity error;

        if fsm_state_dbg = "0000" and rx_done_latched = '0' then
            report "  => [PASS] Reset giua chung thanh cong, FSM ve IDLE ngay lap tuc";
        else
            sim_error_cnt <= sim_error_cnt + 1;
        end if;

        wait for 2 * BAUD_PERIOD;

        ------------------------------------------------------------------------
        -- TONG KET KET QUA
        ------------------------------------------------------------------------
        report "==========================================================";
        if sim_error_cnt = 0 then
            report ">>> KET QUA: TAT CA KICH BAN DEU PASS <<<";
        else
            report ">>> KET QUA: CO " & integer'image(sim_error_cnt) & " LOI <<<";
        end if;
        report "==========================================================";

        -- Ket thuc tao clock va ket thuc mo phong
        sim_done <= true;
        wait;
    end process;

end architecture sim;
