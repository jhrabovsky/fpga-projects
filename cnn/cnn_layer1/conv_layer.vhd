library IEEE;
	use IEEE.STD_LOGIC_1164.ALL;
	use IEEE.NUMERIC_STD.ALL;

entity conv_layer is
	Generic (
		NO_INPUT_MAPS : natural := 1;
		NO_OUTPUT_MAPS : natural := 16;		
		INPUT_ROW_SIZE : natural := 9;
		KERNEL_SIZE : natural := 3;
		DATA_INTEGER_WIDTH : natural := 8; -- zahrna aj znamienkovy bit
		DATA_FRACTION_WIDTH : natural := 0;
		COEF_INTEGER_WIDTH : natural := 8; -- zahrna aj znamienkovy bit
		COEF_FRACTION_WIDTH : natural := 0;
		RESULT_INTEGER_WIDTH : natural := 8; -- zahrna aj znamienkovy bit
		RESULT_FRACTION_WIDTH : natural := 0
	);

	Port (
		din : in std_logic_vector(NO_INPUT_MAPS * (DATA_INTEGER_WIDTH + DATA_FRACTION_WIDTH) - 1 downto 0);
        w : in std_logic_vector(NO_OUTPUT_MAPS * NO_INPUT_MAPS * (KERNEL_SIZE**2) * (COEF_INTEGER_WIDTH + COEF_FRACTION_WIDTH) - 1 downto 0);
        dout : out std_logic_vector(NO_OUTPUT_MAPS * (RESULT_INTEGER_WIDTH + RESULT_FRACTION_WIDTH) - 1 downto 0);
        clk : in std_logic;
        rst : in std_logic;
        coef_load : in std_logic;
        valid_in : in std_logic;
        valid_out : out std_logic
	);
end conv_layer;

architecture rtl of conv_layer is

---------------------------------------
--				COMPONENTS  		 --
---------------------------------------

component conv_2d is
    Generic(
        INPUT_ROW_LENGTH : integer; -- row length in image
        KERNEL_SIZE : integer;  -- kernel size
        DATA_WIDTH : natural;
        DATA_FRAC_LEN : natural;
        COEF_WIDTH : natural;
        COEF_FRAC_LEN : natural;
        RESULT_WIDTH : natural;
        RESULT_FRAC_LEN : natural
    );
    
    Port (
        din : in std_logic_vector(DATA_WIDTH - 1 downto 0);
        w : in std_logic_vector((KERNEL_SIZE**2) * COEF_WIDTH - 1 downto 0);
        dout : out std_logic_vector(RESULT_WIDTH - 1 downto 0);
        clk : in std_logic;
        ce : in std_logic;
        coef_load : in std_logic;
        rst : in std_logic     
    );
end component;

component adder_tree is
	Generic (
		NO_INPUTS : natural;
		DATA_WIDTH : natural
	);

	Port (
		din : in std_logic_vector(NO_INPUTS * DATA_WIDTH - 1 downto 0);
        dout : out std_logic_vector(DATA_WIDTH - 1 downto 0);
        clk : in std_logic;
        ce : in std_logic;
        rst : in std_logic
	); 
end component;

component fsm is
    Generic (
        INPUT_ROW_LENGTH : integer;
        KERNEL_SIZE : integer
    );
    
    Port ( 
        clk : in std_logic;
		rst : in std_logic;
		run : in std_logic;
		valid : out std_logic
	);
end component;

---------------------------------------
--				CONSTANTS			 --
---------------------------------------

constant DATA_WIDTH : natural := DATA_INTEGER_WIDTH + DATA_FRACTION_WIDTH;
constant COEF_WIDTH : natural := COEF_INTEGER_WIDTH + COEF_FRACTION_WIDTH;
constant RESULT_WIDTH : natural := RESULT_INTEGER_WIDTH + RESULT_FRACTION_WIDTH;
constant NO_BITS_PER_KERNEL : natural := (KERNEL_SIZE**2) * COEF_WIDTH;

---------------------------------------
--				SIGNALS 			 --
---------------------------------------

signal from_conv_to_tree : std_logic_vector(NO_OUTPUT_MAPS * NO_INPUT_MAPS * RESULT_WIDTH - 1 downto 0);

begin
    ---------------------------------------
    --		DATA PATH - COMPUTATION		 --
    ---------------------------------------
    
	output_map_gen : for J in 0 to NO_OUTPUT_MAPS - 1 generate
		
		input_map_gen : for I in 0 to NO_INPUT_MAPS - 1 generate
			conv2d_inst : conv_2d
				generic map (
					INPUT_ROW_LENGTH => INPUT_ROW_SIZE,
					KERNEL_SIZE => KERNEL_SIZE,
					DATA_WIDTH => DATA_WIDTH,
					DATA_FRAC_LEN => DATA_FRACTION_WIDTH,
					COEF_WIDTH => COEF_WIDTH,
					COEF_FRAC_LEN => COEF_FRACTION_WIDTH,
					RESULT_WIDTH => RESULT_WIDTH,
					RESULT_FRAC_LEN => RESULT_FRACTION_WIDTH
				)
				port map (
					din => din((I+1) * DATA_WIDTH - 1 downto I * DATA_WIDTH),
					w => w(J * NO_INPUT_MAPS * NO_BITS_PER_KERNEL + (I+1) * NO_BITS_PER_KERNEL - 1 downto J * NO_INPUT_MAPS * NO_BITS_PER_KERNEL + I * NO_BITS_PER_KERNEL),
                    dout => from_conv_to_tree (J * NO_INPUT_MAPS * RESULT_WIDTH + (I+1) * RESULT_WIDTH - 1 downto J * NO_INPUT_MAPS * RESULT_WIDTH + I * RESULT_WIDTH),
					clk => clk,
					ce => valid_in,
					coef_load => coef_load,
					rst => rst
				);
		end generate input_map_gen;

		adder_tree_inst : adder_tree
			generic map (
				NO_INPUTS => NO_INPUT_MAPS,
				DATA_WIDTH => RESULT_WIDTH
			)
			port map (
				din => from_conv_to_tree ((J+1) * NO_INPUT_MAPS * RESULT_WIDTH - 1 downto J * NO_INPUT_MAPS * RESULT_WIDTH),
				dout => dout ((J+1) * RESULT_WIDTH - 1 downto J * RESULT_WIDTH),
				clk => clk,
				ce => valid_in,
				rst => rst
			);

	end generate output_map_gen;

    -----------------------------------------------
    -- CONTROL PATH - STATUS AND CONTROL SIGNALS --
    -----------------------------------------------
    
    fsm_inst : fsm
        generic map (
            INPUT_ROW_LENGTH => INPUT_ROW_SIZE,
            KERNEL_SIZE => KERNEL_SIZE
        )
        port map (
            clk => clk,
            rst => rst,
            run => valid_in,
            valid => valid_out
        );
        
end rtl;
