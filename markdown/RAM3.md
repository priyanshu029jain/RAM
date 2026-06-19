# 📦 Entity: RAM3 

- **File**: `RAM3.v`

The `RAM3` module implements a standard 8-bit Single-Port Static RAM macro cell ($1 \times 8\text{-bit}$ words). This module uses a clean, split unidirectional bus strategy—utilizing a dedicated `data_in` port for write operations and an independent `data_out` port for read operations. By separating the input and output datapath lines, it eliminates the need for tristate logic handling (`8'hzz`), making it highly compatible with modern FPGA routing architectures that prefer internal multiplexer logic over physical tristate pads.

---

## 🗺️ Diagram

![Diagram](RAM3.svg "RTL Schematic Diagram of the Unidirectional Split-Bus RAM3 Module")

---

## 🔌 Ports

| Port name | Direction | Type | Description |
| --------- | --------- | ---------- | ----------- |
| **`cs`** | input | wire | **Chip Select:** Must be asserted high (`1`) to enable any read or write memory cycles within the macrocell. |
| **`rd`** | input | wire | **Read Enable:** Active-high control strobe that triggers a combinational data lookup from the internal storage array. |
| **`wr`** | input | wire | **Write Enable:** Active-high control strobe that enables asynchronous writing of data into the targeted address slot. |
| **`addr`** | input | wire [3:0] | **Address Bus:** Parallel 4-bit input wire used to decode and index 1 of the 16 available byte rows. |
| **`data_in`** | input | wire [7:0] | **Dedicated Data Input:** Unidirectional 8-bit input bus carrying the raw write payload bits. |
| **`data_out`** | output | reg [7:0]  | **Dedicated Data Output:** Unidirectional 8-bit output register rail displaying the looked-up data word. |

---

## 🎛️ Signals

| Name | Type | Description |
| ---------------- | --------- | ----------- |
| **`mem_array [0:15]`** | reg [7:0] | Core Static RAM memory matrix consisting of 16 individual byte storage registers. |

---

## ⚡ Core Hardware Design Realities & Architectural Caveats

### 1. Advantage of Split Unidirectional Datapaths

Unlike bidirectional `inout` memory cores (which require high-impedance `8'hzz` isolation), `RAM3` uses completely separate paths for reading and writing. This structural design maps cleanly to modern FPGA internal architectures (such as AMD/Xilinx Artix-7 or Spartan series). Because these fabrics do not have internal hardware tristate buffers, split signals allow the synthesis tool to implement the memory lookup using clean, predictable, high-speed multiplexer trees.

### ⚠️ 2. Sequential-Behavioral Simulation Warning (Inferred Latches)

> **CRITICAL HARDWARE IMPLEMENTATION NOTE:** This module executes all memory modifications inside unclocked combinational blocks (`always @(*)`):
> 
> * Because the **`write` block** lacks a standard edge-triggered clock (`posedge clk`), the write mechanism infers **Combinational Latches** rather than stable D-type flip-flops.
> * In real silicon implementation, this design pattern is highly susceptible to timing hazards, race conditions, and signal glitches. If the values on `addr` or `data_in` ripple or change at slightly different propagation speeds while `wr` is held active, the circuit can inadvertently corrupt adjacent memory locations. Shifting the write logic to a standard clocked sequential block (`always @(posedge clk)`) is highly recommended for stable production deployments.

---

## 🧬 Processes

### 1. `write`

* **Trigger:** `( @(*) )`
* **Type:** always
* **Functional Mechanics:** Monitors the control interfaces combinationally. If the device is selected and the control lines indicate a write cycle (`cs && wr && !rd`), the module immediately samples the bits from the `data_in` bus and passes them straight into the memory matrix row indexed by `addr`.

### 2. `read`

* **Trigger:** `( @(*) )`
* **Type:** always
* **Functional Mechanics:** Evaluates address pointers combinationally. When the chip conditions evaluate to a valid read phase (`cs && !wr && rd`), `data_out` instantly mirrors the byte contents currently residing inside `mem_array[addr]`. If these conditions are not met, the output typically drops back or holds its assignment state depending on the behavioral defaults.