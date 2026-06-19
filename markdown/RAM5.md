# 📦 Entity: RAM5  

- **File**: `RAM5.v`

The `RAM5` module implements a high-performance, 8-bit **Pseudo-Dual-Port Static RAM** macro simulation cell ($1 \times 8\text{-bit}$ words). Building upon independent parallel reading (`addr_rd`) and writing (`addr_wr`) address channels, this architecture integrates **File-I/O Simulation Hardware Tasks**.  

The module automatically pre-loads its memory matrix configurations from an external hex file at startup and actively flashes its entire memory array contents back out to disk whenever a valid write cycle executes.

---

## 🗺️ Diagram

![Diagram](RAM5.svg "Diagram")

---

## 🔌 Ports

| Port name | Direction | Type | Description |
| --------- | --------- | ---------- | ----------- |
| **`cs`** | input | wire | **Chip Select:** Must be asserted high (`1`) to enable any read, write, or file-synchronization cycles within the macrocell. |
| **`clk`** | input | wire | **Master Clock:** Global system clock driving sequential write cycles and automated disk backup tasks on its rising edge. |
| **`rd`** | input | wire | **Read Enable:** Active-high control strobe that triggers a combinational data lookup from the internal storage array. |
| **`wr`** | input | wire | **Write Enable:** Active-high control strobe that validates synchronous writing and triggers a write-back to disk storage. |
| **`addr_rd`** | input | wire [3:0] | **Read Address Bus:** Independent 4-bit bus dedicated to indexing the target row for combinational read lookups. |
| **`addr_wr`** | input | wire [3:0] | **Write Address Bus:** Independent 4-bit bus dedicated to indexing the destination row for clocked write updates. |
| **`data_in`** | input | wire [7:0] | **Dedicated Data Input:** Unidirectional 8-bit bus carrying the raw write payload to be committed to the array. |
| **`data_out`** | output | [7:0] | **Dedicated Data Output:** Unidirectional 8-bit output register rail displaying the read data word or bypassed data stream. |

---

## 🎛️ Signals

| Name | Type | Description |
| ---------------- | --------- | ----------- |
| **`mem_array [0:15]`** | reg [7:0] | Core Static RAM memory matrix consisting of 16 individual byte storage registers. |

---

## ⚡ Core Hardware Design Realities & Architectural Customizations

### 1. External Memory Initialization via File System (`$readmemh`)

To eliminate the need for verbose, manual hardcoded initialization loops within simulation routines, the module handles setup via an integrated behavioral execution block:

```verilog
initial begin : initialize
    $readmemh("external_storage.mem" , mem_array);
end
```

At runtime time-step zero, the compiler parses external_storage.mem, reads the ASCII hexadecimal values line-by-line, and formats them into the rows of mem_array.

## 2. Automated Non-Volatile Disk Synchronization ($writememh)

To track execution values or bridge co-simulations with outer software environments, RAM5 features an automated runtime data snapshot dumping mechanism:

```Verilog
$writememh("weite_storage.mem" , mem_array );
```

Every time a valid synchronous write executes, the simulator intercepts the event to completely overwrite weite_storage.mem with a clean, updated hex text map of the physical registers.

## 🧬 Processes

### 1. `write`

- **Trigger:** `( @(posedge clk) )`
- **Type:** always
- **Functional Mechanics:** Monitors inputs on the rising edge of the system clock. If `cs` and `wr` are held high, `data_in` is committed to `mem_array[addr_wr]` via a non-blocking assignment (`<=`). Simultaneously, the system triggers `$writememh` to synchronize the updated state out to your external `weite_storage.mem` file.

### 2. `read`

- **Trigger:** `( @(*) )`
- **Type:** always
- **Functional Mechanics:** Executes combinationally and responds instantly to input signal transitions. If the device is selected for a read cycle (`cs && rd`), it evaluates the hazard bypass state; if a concurrent write-back is occurring on that exact same index, `data_in` is forwarded straight to `data_out`. Otherwise, it pulls from the active memory cell array. If `rd` drops low, the bus lines float to high-impedance (`8'hzz`).
