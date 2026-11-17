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
VU.enable_location_preprocessing(additional_subprograms=["check_byte", "strobe_bit"])

# create design library
src_lib = VU.add_library("src_lib")
# add design source files to design_lib
src_lib.add_source_files([DUT_PATH / "*.vhd"])
 
# create testbench library
tb_lib = VU.add_library("tb_lib")
# add testbench source files to tb_lib
tb_lib.add_source_files([TEST_PATH / "*.vhd"])

RX_tb = tb_lib.test_bench("RX_tb")
TX_tb = tb_lib.test_bench("TX_tb")
# since baud will be kept at 115200 and freq will be varied


TX_tb.add_config(name="two_cycles",  generics=dict(freq=2*115200, baud=115200))
TX_tb.add_config(name="four_cycles", generics=dict(freq=4*115200, baud=115200))
# real board values: 50e6/(16*115200) = 27.127, truncated to 27
TX_tb.add_config(name="real_board", generics=dict(freq=50_000_000, baud=115200))

RX_tb.add_config(name="1.8432MHz_9600B",  generics=dict(freq=1_843_200, baud=9600))
RX_tb.add_config(name="1.8432MHz_115200B",  generics=dict(freq=1_843_200, baud=115200))
RX_tb.add_config(name="12MHz_115200B",  generics=dict(freq=12_000_000, baud=115200))
RX_tb.add_config(name="20MHz_115200B",  generics=dict(freq=20_000_000, baud=115200))
RX_tb.add_config(name="50MHz_9600B",  generics=dict(freq=50_000_000, baud=9600))

RX_tb.add_config(name="50MHz_115200B", generics=dict(freq=50_000_000, baud=115200))






# So we see all internal signals
TX_tb.set_sim_option("modelsim.vsim_flags", ["-voptargs=+acc"])
RX_tb.set_sim_option("modelsim.vsim_flags", ["-voptargs=+acc"])



for tb in tb_lib.get_test_benches():
  tb.set_sim_option("modelsim.init_file.gui", str(ROOT) + "/waves/" + tb.name + "_wave.do")
  tb.set_sim_option("modelsim.init_files.after_load", ["dump.do"])
VU.main()


