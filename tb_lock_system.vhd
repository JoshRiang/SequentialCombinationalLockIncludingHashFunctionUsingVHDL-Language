library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_lock_system is
end tb_lock_system;

architecture Behavioral of tb_lock_system is

    component lock_controller is
        Port (
            clk             : in  STD_LOGIC;
            reset           : in  STD_LOGIC;
            user_input      : in  STD_LOGIC_VECTOR(15 downto 0);
            input_valid     : in  STD_LOGIC;
            lock_open       : out STD_LOGIC;
            notification_led: out STD_LOGIC
        );
    end component;
    
    signal clk              : STD_LOGIC := '0';
    signal reset            : STD_LOGIC := '1';
    signal user_input       : STD_LOGIC_VECTOR(15 downto 0) := (others => '0');
    signal input_valid      : STD_LOGIC := '0';
    signal lock_open        : STD_LOGIC;
    signal notification_led : STD_LOGIC;
    
    constant CLK_PERIOD : time := 10 ns;
    constant CORRECT_PIN : STD_LOGIC_VECTOR(15 downto 0) := x"04D2";
    constant WRONG_PIN   : STD_LOGIC_VECTOR(15 downto 0) := x"0000";

begin

    uut: lock_controller
        port map (
            clk             => clk,
            reset           => reset,
            user_input      => user_input,
            input_valid     => input_valid,
            lock_open       => lock_open,
            notification_led => notification_led
        );
    
    clk_process: process
    begin
        clk <= '0';
        wait for CLK_PERIOD/2;
        clk <= '1';
        wait for CLK_PERIOD/2;
    end process;
    
    stim_proc: process
    begin
        wait for 100 ns;
        reset <= '0';
        
        wait for 200 ns;
        user_input <= CORRECT_PIN;
        
        wait for 100 ns;
        input_valid <= '1';
        wait for 50 ns;
        input_valid <= '0';
        
        wait for 5 us;
        
        user_input <= WRONG_PIN;
        wait for 100 ns;
        input_valid <= '1';
        wait for 50 ns;
        input_valid <= '0';
        
        wait for 5 us;
        
        user_input <= x"1111";
        wait for 100 ns;
        input_valid <= '1';
        wait for 50 ns;
        input_valid <= '0';
        
        wait for 5 us;
        
        user_input <= CORRECT_PIN;
        wait for 100 ns;
        input_valid <= '1';
        wait for 50 ns;
        input_valid <= '0';
        
        wait for 5 us;
        wait;
        
    end process;

end Behavioral;
