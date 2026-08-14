# Hermes
 Hermes is a simple UART protocol implementation in VHDL. 

## Definitions
To make certain things easier to explain and keep terminology uniform I have prepared a list of not self explanatory words used in this documentation.

| Word/Phrase | Definition |
| --- | --- |
| BRG | Baud Rate Generator, the module that sends the enable pulses for the receiver and transmitter | 
| OSR | Oversampling Rate |
| mid_bit_point(short: mpb) | 1/2 bittime |
| tick | Frequency/(OSR*Baudrate), i.e 1/OSR of a bittime(in clock cycles) |


## Functionality


### Not implemented yet

### Known Issues

## Hardware and Toolchain

| Component | Version |
| --- | --- |
| Board | DE10-Lite |
| FPGA | MAX 10 10M50DAF484C7G |
| Synthesis | Altera Quartus |
| Simulation | Altera Questa |
| Testframework | VUnit |

If you wish to run tests, do not do it via quartus, as the testbenches have not been included in the quartus project to avoid compatibility issues. Refer to the [Testing and Verification](https://github.com/Gamydas/Hermes-UART-/blob/main/README.md#testing-and-verification) Section

## How to Use


## Timing Behavior

- The BRG generates an enable signal for the transmitter for one cycle at the end of a bittime
- The BRG generates an enable signal for the receiver for one cycle at mbp-1, mbp and mbp+1

## Timing Data 

## Architecture

## Modules

### Baud Rate Generator
The Baud Rate Generator(`BRG.vhd`) generates one cycle pulses for both tx and rx logic, i.e. telling both the transmitter when to send and the receiver when to read. For the Rx side, the BRG sends 3 pulses centered around
the mid-bit-point to decide out of a best of 3 when reading differing signals during this window. I.e Rx reads '1' at mid-1, '0' at mid and '1' on mid + 1, Rx will assume that 1 is the correct value.

| Generic | Purpose | 
| --- | --- |
| freq | used to configure the UART to the devices frequency,**default is 50 MHz** | 
| baud | used to set a before agreed upon baud rate, **default is 115200** |
| OSR  | used to set an oversampling rate, necessary for the receiver to make a best of 3 decision, **default is 16, but minimum is 4** |

| Ports | Direction | Purpose |
| --- | --- | --- |
| clk | IN | system clock port |
| rst | IN | global async reset port |
| sync | IN | sync reset, used to synchronise the receiver to the transmitters start-bit when receiving packages |
| tx_enable | OUT | enable signal for the transmitter |
| rx_enable | OUT | enable signal for the receiver | 

## Decisions 

### Implementing an OSR
I've decided to implement oversampling to allow the receiver to make a best of 3 decision for enhanced safety against glitches.


## Testing and Verification
As mentioned in the beginning, this project was tested via the VUnit [test framework](https://vunit.github.io/user_guide.html).
Look up the installation guide for VUnit before continuing.

### How to use
In the projects root directory there is a `run.py` file. With this we control the entire test environment.
- The command `python run.py` starts every test in every testbench, depending on the amount of tests there are, this could take a while.
- To start a specific test or testbench we instead run `python run.py *[name of testbench].[name of test]`. `[name of test]` can be substituted with an asterisk to start every test in the testbench.
- In this project I have also included multiple configurations, called `one_cycle`, `two_cycles`, `4_cycles`, `real_board` to test the design with different tick cycle lengths.
  - These can be specified by typing `python run.py *[name of testbench].[configuration].[name of test]` into your  terminal

### Currently implemented Tests

#### BRG_tb

| Test case | What it proves |
| --- | --- |
| tx_rx_test | proves tx_enable sends a one clock cycle long pulse after a full bittime and x_enable sends a pulse after 1/2 -1 bittime and after the next 2 ticks, centered around the half of a bittime |
| tx_rx_over_10_bittimes | proves that tx_enable and rx_enable behavior does not change/drift apart over time |
| sync_test | tests if sync signal works as intended and resets the counter |
| sync_before_tx_pulse | tests if sync works as intended at a different testing point, right before tx_enable should go high |
| reset_test | essentially tests the same thing as sync_test, but asynchronously, also holds the rst high for 1000 cycles to check that the counter is stopped |


