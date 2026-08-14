from pathlib import Path
from vunit import VUnit

# ROOT
ROOT = Path(__file__).resolve().parent
# Sources path for DUT
DUT_PATH = ROOT / "src"
# Sources path for TB
TEST_PATH = ROOT / "tb"

# create VUnit instance
VU = VUnit.from_argv()
VU.add_vhdl_builtins()
VU.enable_location_preprocessing()

# create design library
src_lib = VU.add_library("src_lib")
# add design source files to design_lib
src_lib.add_source_files([DUT_PATH / "*.vhd"])
 
# create testbench library
tb_lib = VU.add_library("tb_lib")
# add testbench source files to tb_lib
tb_lib.add_source_files([TEST_PATH / "*.vhd"])

BRG_tb = tb_lib.test_bench("BRG_tb")

# since baud will be kept at 115200 and freq will be varied

# this configuration uses the smallest possible tick_cycle (1) by setting
# freq = OSR*baud
BRG_tb.add_config(name="one_cycle",   generics=dict(freq=1_843_200, baud=115200, OSR=16))
BRG_tb.add_config(name="two_cycles",  generics=dict(freq=1_843_200, baud=115200, OSR=8))
BRG_tb.add_config(name="four_cycles", generics=dict(freq=1_843_200, baud=115200, OSR=4))



# So we see all internal signals
BRG_tb.set_sim_option("modelsim.vsim_flags", ["-voptargs=+acc"])




for tb in tb_lib.get_test_benches():
  tb.set_sim_option("modelsim.init_file.gui", str(ROOT) + "/waves/" + tb.name + "_wave.do")

VU.main()


