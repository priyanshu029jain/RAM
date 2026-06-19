# 📦 Entity: RAM2 

- **File**: `RAM2.v`

The `RAM2` module implements a highly pin-efficient, 128-bit Single-Port RAM macro cell ($16 \times 8\text{-bit}$ words) utilizing an **Address/Data Time-Multiplexed Bus** scheme. Controlled by an Address Latch Enable line (labeled as `rtl`), the module multiplexes both 4-bit memory addresses and 8-bit data payloads onto a single, shared 8-bit bidirectional bidirectional bus interface (`data`). This structure mimics traditional high-efficiency microprocessor-to-peripheral hardware interfaces where minimizing physical pin counts is an absolute priority.

---

## 🗺️ Diagram

![Diagram](RAM2.svg "Diagram")

---

## 🔌 Ports

| Port name | Direction | Type | Description |
| --------- | --------- | ---------- | ----------- |
| **`cs`** | input | wire | **Chip Select:** Must be asserted high (`1`) to enable any read, write, or address-latch memory cycle operations within the macro. |
| **`rtl`** | input | wire | **Address Latch Enable (ALE equivalent):** When high, the lower nibble of the shared data bus is captured as an address. When low, the bus is unlocked for data transfer phases. |
| **`rd`** | input | wire | **Read Enable:** Active-high control strobe that enables the combinational data output buffer to drive the shared bus. |
| **`wr`** | input | wire | **Write Enable:** Active-high control strobe that validates an asynchronous data write into the targeted memory array slot. |
| **`data`** | inout | wire [7:0] | **Multiplexed Bidirectional Bus:** Time-shared 8-bit datapath carrying target address coordinates (`rtl == 1`), incoming write data, or outgoing read data. |

---

## 🎛️ Signals

| Name | Type | Description |
| ---------------- | --------- | ----------- |
| **`mem_array [0:15]`** | reg [7:0] | Internal high-density Static RAM storage matrix consisting of 16 individual byte rows. |
| **`data_out`** | reg [7:0] | Dedicated output hold buffer isolating internal memory arrays from the external tristate pad line. |
| **`addr`** | reg [3:0] | Transparent latch tracking register that stores and freezes the active 4-bit row coordinate after the address phase terminates. |

---

## ⚡ Core Hardware Design Realities & Architectural Caveats

### 1. Two-Phase Bus Protocol Execution

Because the same 8 physical wires are shared for two entirely different purposes, the system interface must strictly adhere to a distinct hardware sequence:

1. **Address Latch Phase (`rtl == 1`):** The master places an address on the bus and pulses `rtl` high. The RAM samples `data[3:0]` into its internal `addr` storage element.
2. **Data Cycle Phase (`rtl == 0`):** `rtl` drops low to lock the active address register in place. The bus is now free to read out data vectors (`rd == 1`) or latch incoming data payloads (`wr == 1`).

### ⚠️ 2. Sequential-Behavioral Simulation Warning (Inferred Latches)

Inside your current source design, all functional logic loops are modeled using completely combinational blocks (`always @(*)`):

* The **`address` block** (`if (cs && rtl)`) infers a **Transparent Combinational Latch** on the `addr` signal. When `rtl` drops back to `0`, `addr` relies on behavioral feedback to preserve its contents.  
* The **`write` block** similarly infers a combinational level-sensitive latch matrix block.

In real silicon layouts (FPGAs/ASICs), unclocked combinational storage cells are highly susceptible to timing glitches and racing hazards. If values on the shared `data` bus ripple while control lines transition, the system can inadvertently corrupt adjacent memory slots. Shifting the write and latch logic to a standard clocked sequential block (`always @(posedge clk)`) is highly recommended for production hardware deployment.

---

## 🧬 Processes

### 1. `address`

* **Trigger:** `( @(*) )`
* **Type:** always
* **Functional Mechanics:** Monitors the state of the system control lines combinationally. While `cs` and `rtl` are actively held high, the internal transparent latch register `addr` opens up its pass-gates to continuously track the lower nibble broadcasting on the `data[3:0]` bus lines.

### 2. `write`

* **Trigger:** `( @(*) )`
* **Type:** always
* **Functional Mechanics:** Evaluates bus control states immediately. If `cs` and `wr` are held high while `rtl` and `rd` are low, the 8-bit value present on the shared `data` pad pins is latched directly into the targeted `mem_array[addr]` row.

### 3. `read`

* **Trigger:** `( @(*) )`
* **Type:** always
* **Functional Mechanics:** Looks up memory cells combinationally. If the read access matrix configurations check out (`cs && !rtl && !wr && rd`), the internal signal `data_out` grabs the value mapped to `mem_array[addr]`. If the device is unselected, writing, or actively latching an address, the line safely defaults to a zero ground buffer (`8'h00`).