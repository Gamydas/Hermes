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
VU.enable_location_preprocessing(additional_subprograms=[])

# create design library
src_lib = VU.add_library("src_lib")
# add design source files to design_lib
src_lib.add_source_files([DUT_PATH / "*.vhd"])
 
# create testbench library
tb_lib = VU.add_library("tb_lib")
# add testbench source files to tb_lib
tb_lib.add_source_files([TEST_PATH / "*.vhd"])

I2C_tb = tb_lib.test_bench("tb_i2c")

I2C_tb.add_config(name="Standard",  generics=dict(sys_freq=20_000_000, scl_freq=100_000))
I2C_tb.add_config(name="Fast",  generics=dict(sys_freq=125_000_000, scl_freq=400_000))
I2C_tb.add_config(name="FastPlus",  generics=dict(sys_freq=125_000_000, scl_freq=1_000_000))

# So we see all internal signals
I2C_tb.set_sim_option("modelsim.vsim_flags", ["-voptargs=+acc"])



for tb in tb_lib.get_test_benches():
  tb.set_sim_option("modelsim.init_file.gui", str(ROOT) + "/waves/" + tb.name + "_wave.do")
  tb.set_sim_option("modelsim.init_files.after_load", ["dump.do"])
VU.main()


