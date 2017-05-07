library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library UNISIM;
use UNISIM.VComponents.all;

entity systolic_fir is
    Generic (
        N : integer := 5;
        MODE : string -- "DIRECT" (First SE) or "CASCADE" (Next SE)
    );
    
    Port ( xn : in std_logic_vector(17 downto 0);
           yn : out std_logic_vector(47 downto 0);
           bcout : out std_logic_vector(17 downto 0); 
           W : in std_logic_vector(30*N - 1 downto 0); 
           clk : in std_logic;
           ce : in std_logic;
           coef_load : in std_logic;
           rst : in std_logic
    );
end systolic_fir;

architecture Behavioral of systolic_fir is

------------------------------------------------------------------------
--
-- Component Declarations:
--
------------------------------------------------------------------------

component MADD_FIRST is
    Generic (
        B_MODE : string
    );
    Port ( b : in std_logic_vector(17 downto 0);
           bcin : in std_logic_vector(17 downto 0);             
           a : in std_logic_vector(29 downto 0); 
           clk : in std_logic;
           ce : in std_logic;
           coef_load : in std_logic;
           rst : in std_logic;
           bcout : out std_logic_vector(17 downto 0);
		   pcout : out std_logic_vector(47 downto 0)
    );
end component;

component MADD_IN is
    Port ( bcin : in std_logic_vector(17 downto 0);            
           a : in std_logic_vector(29 downto 0); 
           pcin : in std_logic_vector(47 downto 0);
           clk : in std_logic;
           ce : in std_logic;
           coef_load : in std_logic;
           rst : in std_logic;
           bcout : out std_logic_vector(17 downto 0);
		   pcout : out std_logic_vector(47 downto 0)
	);
end component;

component MADD_LAST is
    Port ( bcin : in std_logic_vector(17 downto 0);            
           bcout : out std_logic_vector(17 downto 0);
           a : in std_logic_vector(29 downto 0); 
           pcin : in std_logic_vector(47 downto 0);
           clk : in std_logic;
           ce : in std_logic;
           coef_load : in std_logic;
           rst : in std_logic;
		   p : out std_logic_vector(47 downto 0)
	);
end component;

---------------------------------------------------------------------------------
--     Setup all the connecting signals between MADD elements in one vector    --
---------------------------------------------------------------------------------
  
  signal pcin_tmp : std_logic_vector(48*N - 1 downto 0);
  signal bcin_tmp : std_logic_vector(18*N - 1 downto 0);
  
  signal b_to_first_madd : std_logic_vector(17 downto 0);
  signal bcin_to_first_madd : std_logic_vector(17 downto 0); 
  
begin

-------------------------------------------
--  DISTINGUISH FIR POSITION IN CASCADE  --
-------------------------------------------

  first_se_input : if (MODE = "DIRECT") generate
    b_to_first_madd <= xn;
    bcin_to_first_madd <= (others => '0');
  end generate;

  next_se_input : if (MODE = "CASCADE") generate
    b_to_first_madd <= (others => '0');
    bcin_to_first_madd <= xn;
  end generate;
  
  G: for I in 0 to N - 1 generate

  G_first_direct: if I = 0 generate    
    M0: MADD_FIRST
      generic map (
        B_MODE => MODE
      ) 
      port map (
        b => b_to_first_madd,
        bcin => bcin_to_first_madd,
        a => W(30*I + 29 downto 30*I),
        clk => clk,
        ce => ce,
        coef_load => coef_load,
        rst => rst,
        bcout => bcin_tmp(18*I + 17 downto 18*I),
        pcout => pcin_tmp(48*I + 47 downto 48*I)
      );
  end generate;

  GX: if (I >= 1 and I < N - 1) generate
    M1: MADD_IN
      port map (
        bcin => bcin_tmp(18*(I-1) + 17 downto 18*(I-1)), 
        a => W(30*I + 29 downto 30*I),
        pcin => pcin_tmp(48*(I-1) + 47 downto 48*(I-1)),
        clk => clk,
        ce => ce,
        coef_load => coef_load,
        rst => rst,
        bcout => bcin_tmp(18*I + 17 downto 18*I),
        pcout => pcin_tmp(48*I + 47 downto 48*I)
      );
  end generate;

  G_last: if I = N - 1 generate
    M2:  MADD_LAST
      port map (
        bcin => bcin_tmp(18*(I-1) + 17 downto 18*(I-1)),
        bcout => bcout,
        a => W(30*I + 29 downto 30*I),
        pcin => pcin_tmp(48*(I-1) + 47 downto 48*(I-1)),
        clk => clk,
        ce => ce,
        coef_load => coef_load,
        rst => rst,
        p => yn
      );
    end generate;
    
  end generate;
end Behavioral;
