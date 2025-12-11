library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity lock_controller is
    Port (
        clk             : in  STD_LOGIC;
        reset           : in  STD_LOGIC;
        user_input      : in  STD_LOGIC_VECTOR(15 downto 0);
        input_valid     : in  STD_LOGIC;
        lock_open       : out STD_LOGIC;
        notification_led: out STD_LOGIC
    );
end lock_controller;

architecture Behavioral of lock_controller is

    component sha3_256_core is
        Port (
            clk         : in  STD_LOGIC;
            reset       : in  STD_LOGIC;
            start       : in  STD_LOGIC;
            message_in  : in  STD_LOGIC_VECTOR(15 downto 0);
            byte_len    : in  STD_LOGIC_VECTOR(7 downto 0);
            hash_out    : out STD_LOGIC_VECTOR(255 downto 0);
            ready       : out STD_LOGIC;
            done        : out STD_LOGIC
        );
    end component;
    
    type fsm_state_type is (IDLE, VALIDATE, HASHING, COMPARE, OPEN_STATE, NOTIFY);
    signal current_state : fsm_state_type := IDLE;
    
    signal hash_start : STD_LOGIC := '0';
    signal hash_done : STD_LOGIC;
    signal hash_ready : STD_LOGIC;
    signal computed_hash : STD_LOGIC_VECTOR(255 downto 0);
    signal stored_input : STD_LOGIC_VECTOR(15 downto 0) := (others => '0');
    signal byte_length : STD_LOGIC_VECTOR(7 downto 0) := x"02";
    signal hash_started : STD_LOGIC := '0';
    signal hash_counter : integer range 0 to 100 := 0;
    
    constant SECRET_KEY_HASH : STD_LOGIC_VECTOR(255 downto 0) := 
        x"929CB125102905D2092F7960C08A339BFD88D098D8CC74490B82061F8F710F2F";
    
    signal notify_counter : integer range 0 to 500 := 0;
    constant NOTIFY_TIMEOUT : integer := 200; 
    signal open_counter : integer range 0 to 500 := 0;
    constant OPEN_TIMEOUT : integer := 200;
    
begin

    sha3_core_inst : sha3_256_core
        port map (
            clk         => clk,
            reset       => reset,
            start       => hash_start,
            message_in  => stored_input,
            byte_len    => byte_length,
            hash_out    => computed_hash,
            ready       => hash_ready,
            done        => hash_done
        );
    
    process(clk, reset)
    begin
        if reset = '1' then
            current_state <= IDLE;
            hash_start <= '0';
            hash_started <= '0';
            hash_counter <= 0;
            lock_open <= '0';
            notification_led <= '0';
            notify_counter <= 0;
            open_counter <= 0;
            stored_input <= (others => '0');
            
        elsif rising_edge(clk) then
            
            hash_start <= '0';
            
            case current_state is
                
                when IDLE =>
                    lock_open <= '0';
                    notification_led <= '0';
                    notify_counter <= 0;
                    open_counter <= 0;
                    hash_started <= '0';
                    hash_counter <= 0;
                    if input_valid = '1' then
                        stored_input <= user_input;
                        current_state <= VALIDATE;
                    end if;
                
                when VALIDATE =>
                    current_state <= HASHING;
                
                when HASHING =>
                    if hash_started = '0' then
                        hash_start <= '1';
                        hash_started <= '1';
                        hash_counter <= 0;
                    else
                        hash_counter <= hash_counter + 1;
                    end if;
                    
                    if hash_done = '1' or hash_counter >= 60 then
                        current_state <= COMPARE;
                        hash_started <= '0';
                        hash_counter <= 0;
                    end if;
                
                when COMPARE =>
                    if computed_hash = SECRET_KEY_HASH then
                        current_state <= OPEN_STATE;
                    else
                        current_state <= NOTIFY;
                    end if;
                
                when OPEN_STATE =>
                    lock_open <= '1';
                    if open_counter >= OPEN_TIMEOUT then
                        current_state <= IDLE;
                        open_counter <= 0;
                    else
                        open_counter <= open_counter + 1;
                    end if;
                
                when NOTIFY =>
                    notification_led <= '1';
                    if notify_counter >= NOTIFY_TIMEOUT then
                        current_state <= IDLE;
                        notify_counter <= 0;
                    else
                        notify_counter <= notify_counter + 1;
                    end if;
                    
            end case;
        end if;
    end process;

end Behavioral;