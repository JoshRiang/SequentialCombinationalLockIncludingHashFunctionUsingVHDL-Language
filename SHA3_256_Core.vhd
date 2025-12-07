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