
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity roms_from_file is
    Generic (
        N : natural := 2;
        ADDR_LEN : natural := 4;
        DATA_LEN : natural := 8
    );
    
    Port (
        clk : in std_logic;
        rst : in std_logic;
        ce : in std_logic;
        addrs : in std_logic_vector(N * ADDR_LEN - 1 downto 0);
        datas : out std_logic_vector(N * DATA_LEN - 1 downto 0)
    );
end roms_from_file;

architecture Behavioral of roms_from_file is

component rom is
    Generic (
        FILENAME : string;
        DATA_LENGTH : natural;
        ADDR_LENGTH  : natural
    );
    
    Port (
        clk : in std_logic;
        en : in std_logic;
        addr : in std_logic_vector(ADDR_LENGTH - 1 downto 0);
        data : out std_logic_vector(DATA_LENGTH - 1 downto 0)
    );
end component;

type addr_frame is array (0 to N-1) of std_logic_vector(ADDR_LEN - 1 downto 0);
type data_frame is array (0 to N-1) of std_logic_vector(DATA_LEN - 1 downto 0);

signal addr_f : addr_frame;
signal data_f : data_frame; 

begin
    gen_arrays : for I in 0 to N-1 generate
        addr_f(I) <= addrs(ADDR_LEN * (I+1) - 1 downto ADDR_LEN * I);
        datas(DATA_LEN * (I+1) - 1 downto DATA_LEN * I) <= data_f(I);
    end generate;
    
    mem_map : for I in 1 to N generate
        rom_inst : rom
            generic map (
                FILENAME => "rom_" & INTEGER'IMAGE(I) & ".data",
                DATA_LENGTH => DATA_LEN,
                ADDR_LENGTH => ADDR_LEN
            )
            port map (
                clk => clk,
                en => ce,
                addr => addr_f(I-1),
                data => data_f(I-1)
            );
    end generate;

end Behavioral;
