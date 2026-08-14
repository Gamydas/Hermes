# Hermes
 Hermes is a simple UART protocol implementation in VHDL. 

## Definitions
To make certain things easier to explain and keep terminology uniform I have prepared a list of not self explanatory words used in this documentation.

| Word/Phrase | Definition |
| --- | --- |
| BRG | Baud Rate Generator, the module that sends the enable pulses for the receiver and transmitter | 
| OSR | Oversampling Rate |
| tick | Frequency/(OSR*Baudrate), i.e 1/OSR of a bittime |


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

If you wish to run tests, do not do it via quartus, as the testbenches have not been included in the quartus project to avoid compatibility issues. Refer to the [Testing and Verification](https://github.com/Gamydas/Hermes-UART-/edit/main/README.md#testing-and-verification) Section

## How to Use


## Timing Behaviour

## Timing Data 

## Architecture

## Decisions 

## Testing and Verification
As mentioned in the beginning, this project was tested via the VUnit [test framework](https://vunit.github.io/user_guide.html).
Look up the installation guide for VUnit before continuing.

### How to use
In the projects root directory there is a `run.py` file. With this we control the entire test environment.
- The command `python run.py` starts every test in every testbench, depending on the amount of tests there are, this could take a while.
- To start a specific test or testbench we instead run `python run.py *[name of testbench].[name of test]`. `[name of test]` can be substituted with an asterisk to start every test in the testbench.
- In this project I have also included multiple configurations, called `one_cycle`, `two_cycles` and `4_cycles` to test the design with different tick cycle lengths.
  - These can be specified by typing `python run.py *[name of testbench].[configuration].[name of test]` into your  terminal

### Currently implemented Tests

#### BRG_tb

| Test case | What it proves |
| --- | --- |
| tx_enable_test | proves tx_enable sends a one clock cycle long pulse after a full bittime |
| rx_enable_test | proves rx_enable sends a pulse after 1/2 -1 bittime and after the next 2 ticks, centered around the half of a bittime |
