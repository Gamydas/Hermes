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

## Architecture Transmitter(Tx)
The UART Transmitter(`Tx.vhd`) transmits data as defined by the uart protocol in the form of 8E1, meaning 8 bits of data, Even parity and one stop bit. Both parity and length of the stop bit might become generically configurable in the future.

### Interface/Port Map

| Generic | Purpose | 
| --- | --- |
| freq | used to configure the UART to the devices frequency,**default is 50 MHz** | 
| baud | used to set a before agreed upon baud rate, **default is 115200** |


| Ports | Direction | Purpose |
| --- | --- | --- |
| clk | IN | system clock port |
| rst | IN | global async reset port |
| data_rdy | IN | port for the source of the data to tell the transmitter that data has been put on on the data_in port. This data takes on cycle to be written into the buffer/holding register of the transmitter, so wait atleast 1 cycle between putting data on the bus and setting data_rdy high |
| data_in | IN | 8 bit bus line from which the transmission data is read. Data on the bus gets loaded into the holding register at the first legal clock cycle |
| data_out | OUT | The serial output of the transmitter | 
| status | OUT | status signal of the transmitter, used to signal the 


### Functionality
The transmitter is driven by an a `5 State FSM`, containing the states `idle`, `start`, `data`, `parity` and `stop`. Below is a table explaining the different states.

| State | Purpose |
| --- | --- |
| `idle` | Transmitters idling phase. During this time, the `data_out` Port is constantly held high. This phase also actively stop/resets the BRG |
| `start` | Transmissions start bit. As is usual in UART, the `data_out` is pulled low **for exactly 1 bittime** before beginning data transmission. All changes to input data happening will no longer be considered for this transmission |
| `data` | Transmission of data. 1 Bit gets shifted out of the `tx_shift_reg` per **bittime** not per clock cycle, at 50 MHz/115200 baudrate this would be 434 clock cycles | 
| `parity` | Transmission of parity. For now the Transmitter **always** sends an even parity bit | 
| `stop` | Transmission of stop bit. As is usual in UART, the `data_out` is pulled high **for exactly 1 bittime**(this might become configurable) before either entering `start` or `idle` again |

Apart from the FSM the transmitter is also fitted with 2 registers and of course the `BRG`/`baud enable generator`. \
First is `tx_hold_reg`, which is the buffer/holding register, loading data from the bus before and during transmissions. \
The other is the `tx_shift_reg`, this is the serial out shift register of the transmitter, used to push the parallely loaded data bits onto the `data_out` line.

Lastly the `BRG`, at compilation the `bittime` constant is calculated, which follows from the formula **frequency/baud** which gives us the bittime in cycles instead of seconds. The counter counts up to bittime-1 before wrapping back to 0.
The counter wraps at bittime-1 instead of bittime because this allows the FSM to drive transmission on the final rising edge of the bittime, removing the 1 cycle latency mentioned in [Decisions](https://github.com/Gamydas/Hermes-UART-/blob/main/README.md#removing-the-brg-module). 

To begin transmission the data on the bus(`data_in`) must first be loaded into the holding register(1 cycle) and then `data_rdy` has to be set high for atleast 1 more clock cycle. This starts the transition between `idle` and `start` state. 

For continuous data transmission the transmitter outputs a status signal. This signal goes high for exactly 1 bittime when the start state is entered, before going back to low. The source of data can use this in many ways, as data in the 
shift register can not be changed anymore once the `start` state has been entered. This means that the source can reliably send new data on the rising edge of this signal, on the continous high level or on the falling edge. All 3 guarantee 
that the new data will be asserted, **IF** the `data_rdy` signal is high when the `stop` state of is exited. 

Realistically continuous transmission could look like this: 
**[IMAGE FOLLOWS]**



### Block Schematic
![Tx BlockSchematic](doc/TxBlock.png)



## Modules




## Decisions 

### Removing the BRG module  
Previously this was a separate module, however this caused timing issues, causing a 1 clock cycle delay between the end of the bittime and the actual transmission of data, while this wouldn't have broken the design, I preferred to change it to a single process within the `Tx` module and later the `Rx` module.

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

**[Coming Soon]**



### Deprecated Modules
Space where deprecated contents can still be found. Unsure if this will be deleted at some point.

### Baud Rate Generator
The Baud Rate Generator(`BRG.vhd`) generates one cycle pulses for both tx and rx logic, i.e. telling both the transmitter when to send and the receiver when to read. For the Rx side, the BRG sends 3 pulses centered around
the mid-bit-point to decide out of a best of 3 when reading differing signals during this window. I.e Rx reads '1' at mbp-1, '0' at mbp and '1' on mbp + 1, Rx will assume that 1 is the correct value.

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

#### BRG_tb

| Test case | What it proves |
| --- | --- |
| tx_rx_test | proves tx_enable sends a one clock cycle long pulse after a full bittime and x_enable sends a pulse after 1/2 -1 bittime and after the next 2 ticks, centered around the half of a bittime |
| tx_rx_over_10_bittimes | proves that tx_enable and rx_enable behavior does not change/drift apart over time |
| sync_test | tests if sync signal works as intended and resets the counter |
| sync_before_tx_pulse | tests if sync works as intended at a different testing point, right before tx_enable should go high |
| reset_test | essentially tests the same thing as sync_test, but asynchronously, also holds the rst high for 1000 cycles to check that the counter is stopped |
