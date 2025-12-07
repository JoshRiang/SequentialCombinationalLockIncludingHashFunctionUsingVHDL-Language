library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity sha3_256_core is
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
end sha3_256_core;

architecture Behavioral of sha3_256_core is
    
    type lane_type is array (0 to 4, 0 to 4) of STD_LOGIC_VECTOR(63 downto 0);
    type state_type is (S_IDLE, S_ABSORB, S_PERMUTE, S_SQUEEZE, S_DONE);
    signal current_state : state_type := S_IDLE;
    signal keccak_state : lane_type;
    signal round_counter : integer range 0 to 24 := 0;
    signal hash_buffer : STD_LOGIC_VECTOR(255 downto 0);
    
    constant RATE_BITS : integer := 1088;
    constant CAPACITY_BITS : integer := 512;
    constant NUM_ROUNDS : integer := 24;
    
    type rc_array is array (0 to 23) of STD_LOGIC_VECTOR(63 downto 0);
    constant ROUND_CONSTANTS : rc_array := (
        x"0000000000000001", x"0000000000008082", x"800000000000808A", x"8000000080008000",
        x"000000000000808B", x"0000000080000001", x"8000000080008081", x"8000000000008009",
        x"000000000000008A", x"0000000000000088", x"0000000080008009", x"000000008000000A",
        x"000000008000808B", x"800000000000008B", x"8000000000008089", x"8000000000008003",
        x"8000000000008002", x"8000000000000080", x"000000000000800A", x"800000008000000A",
        x"8000000080008081", x"8000000000008080", x"0000000080000001", x"8000000080008008"
    );
    
    type rotation_array is array (0 to 4, 0 to 4) of integer;
    constant RHO_OFFSETS : rotation_array := (
        (0,  1, 62, 28, 27),
        (36, 44,  6, 55, 20),
        (3, 10, 43, 25, 39),
        (41, 45, 15, 21,  8),
        (18,  2, 61, 56, 14)
    );
    
    function rotate_left(word : STD_LOGIC_VECTOR(63 downto 0); n : integer) 
        return STD_LOGIC_VECTOR is
        variable result : STD_LOGIC_VECTOR(63 downto 0);
    begin
        if n = 0 then
            result := word;
        else
            result := word(63-n downto 0) & word(63 downto 64-n);
        end if;
        return result;
    end function;
        
begin

    process(clk, reset)
        variable temp_state : lane_type;
        type temp_array is array (0 to 4) of STD_LOGIC_VECTOR(63 downto 0);
        variable C : temp_array;
        variable D : temp_array;
        variable B : lane_type;
        variable x, y : integer;
    begin
        if reset = '1' then
            current_state <= S_IDLE;
            round_counter <= 0;
            ready <= '1';
            done <= '0';
            hash_out <= (others => '0');
            
            for x in 0 to 4 loop
                for y in 0 to 4 loop
                    keccak_state(x, y) <= (others => '0');
                end loop;
            end loop;
            
        elsif rising_edge(clk) then
            
            case current_state is
                
                when S_IDLE =>
                    ready <= '1';
                    done <= '0';
                    
                    if start = '1' then
                        for x in 0 to 4 loop
                            for y in 0 to 4 loop
                                keccak_state(x, y) <= (others => '0');
                            end loop;
                        end loop;
                        current_state <= S_ABSORB;
                        ready <= '0';
                    end if;
                
                when S_ABSORB =>
                    keccak_state(0, 0) <= x"0000000000000006" xor (x"000000000000" & message_in);
                    keccak_state(4, 3) <= x"8000000000000000";
                    round_counter <= 0;
                    current_state <= S_PERMUTE;
                
                when S_PERMUTE =>
                    if round_counter < NUM_ROUNDS then
                        temp_state := keccak_state;
                        
                        for x in 0 to 4 loop
                            C(x) := temp_state(x,0) xor temp_state(x,1) xor 
                                    temp_state(x,2) xor temp_state(x,3) xor 
                                    temp_state(x,4);
                        end loop;
                        
                        for x in 0 to 4 loop
                            D(x) := C((x+4) mod 5) xor rotate_left(C((x+1) mod 5), 1);
                        end loop;
                        
                        for x in 0 to 4 loop
                            for y in 0 to 4 loop
                                temp_state(x,y) := temp_state(x,y) xor D(x);
                            end loop;
                        end loop;
                        
                        for x in 0 to 4 loop
                            for y in 0 to 4 loop
                                temp_state(x,y) := rotate_left(temp_state(x,y), RHO_OFFSETS(x,y));
                            end loop;
                        end loop;
                        
                        for x in 0 to 4 loop
                            for y in 0 to 4 loop
                                B(x,y) := temp_state(x,y);
                            end loop;
                        end loop;
                        
                        for x in 0 to 4 loop
                            for y in 0 to 4 loop
                                temp_state(y, (2*x + 3*y) mod 5) := B(x, y);
                            end loop;
                        end loop;
                        
                        for x in 0 to 4 loop
                            for y in 0 to 4 loop
                                B(x,y) := temp_state(x,y);
                            end loop;
                        end loop;
                        
                        for x in 0 to 4 loop
                            for y in 0 to 4 loop
                                temp_state(x,y) := B(x,y) xor 
                                    ((not B((x+1) mod 5, y)) and B((x+2) mod 5, y));
                            end loop;
                        end loop;
                        
                        temp_state(0,0) := temp_state(0,0) xor ROUND_CONSTANTS(round_counter);
                        
                        keccak_state <= temp_state;
                        round_counter <= round_counter + 1;
                        
                    else
                        current_state <= S_SQUEEZE;
                    end if;
                
                when S_SQUEEZE =>
                    hash_buffer(63 downto 0)     <= keccak_state(0, 0);
                    hash_buffer(127 downto 64)   <= keccak_state(1, 0);
                    hash_buffer(191 downto 128)  <= keccak_state(2, 0);
                    hash_buffer(255 downto 192)  <= keccak_state(3, 0);
                    current_state <= S_DONE;
                
                when S_DONE =>
                    hash_out <= hash_buffer;
                    done <= '1';
                    ready <= '0';
                    if start = '0' then
                        current_state <= S_IDLE;
                    end if;
                    
            end case;
        end if;
    end process;

end Behavioral;