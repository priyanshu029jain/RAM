# 📦 Entity: RAM6  

- **File**: `RAM6.v`

The `RAM6` module implements a highly adaptable, fully parameterized **Pseudo-Dual-Port SRAM Subsystem Architecture** designed to simulate structured **Cache-Line Data Block Arrays**.  

Rather than treating memory as a simple flat sequence of individual independent registers, `RAM6` organizes its internal matrix into grouped **Block Lines**, where each block line packs multiple independent data words. By isolating read/write addressing into specific **Tag Index bits** and **Offset Slice bits**, the module can read or write individual sub-word positions within a wide physical macrocell memory line.

---

## 🗺️ Diagram

![Diagram](RAM6.svg "Diagram")

---

## ⚙️ Generics

| Generic name | Type | Value | Description |
| ------------ | ---- | ----- | ----------- |
| **`Word_size`** | `integer` | `1` | Sizing scalar dictating the number of full 8-bit bytes contained in a single word element. |
| **`Block_size`** | `integer` | `4` | Density parameter specifying how many independent word structures populate a single memory block line. |
| **`RAM_size`** | `integer` | `64` | The total row capacity (depth configuration) of the master macroblock line arrays. |

---

## 🔌 Ports

| Port name | Direction | Type | Description |
| --------- | --------- | ---------- | ----------- |
| **`cs`** | input | wire | **Chip Select:** Must be driven high (`1`) to open the core and enable lookup or clocked data routing steps. |
| **`clk`** | input | wire | **Master Clock:** Global system clock driving sequential write cycles and automated data modifications on its rising edge. |
| **`rd`** | input | wire | **Read Enable:** Active-high control strobe prompting immediate combinational multi-word sub-indexing. |
| **`wr`** | input | wire | **Write Enable:** Active-high control strobe enabling edge-triggered target bit-slicing modifications. |
| **`addr_rd`** | input | wire [address_width -1:0] | **Read Address Bus:** Complete wide coordinate vector split internally into block line indices and sub-word routing offsets. |
| **`addr_wr`** | input | wire [address_width -1:0] | **Write Address Bus:** Complete wide coordinate vector split internally to track destination block lines and write slice positions. |
| **`data_in`** | input | wire [data_width -1:0] | **Dedicated Data Input:** Custom-sized input channel carrying the single-word payload to write. |
| **`data_out`** | output | [data_width -1:0] | **Dedicated Data Output:** Custom-sized output channel presenting the looked-up or forwarded single-word payload. |

---

## 🎛️ Signals

| Name | Type | Description |
| ---------------- | --------- | ----------- |
| **`mem_array [0: RAM_size -1]`** | reg [block_width -1:0] | Fully scaled structural cache-line storage array matrix. Each row contains a combined bit-pool spanning `block_width` wide. |
| **`tag_rd`** | wire [tag_bites -1:0] | Decoded read row index slice pointing directly to a specific row block index inside the main storage macro. Derived from `addr_rd[address_width -1: offset_bites]`. |
| **`offset_rd`** | wire [offset_bites -1:0] | Decoded read block column offset routing bits targeting 1 of the available word slices inside the pulled row line. Derived from `addr_rd[offset_bites -1:0]`. |
| **`tag_wr`** | wire [tag_bites -1:0] | Decoded write row index slice directing the edge-triggered write logic to a target row block cell. Derived from `addr_wr[address_width -1: offset_bites]`. |
| **`offset_wr`** | wire [offset_bites -1:0] | Decoded write block column offset routing bits selecting the exact word slice location to update. Derived from `addr_wr[offset_bites -1:0]`. |

---

## 🔢 Constants

| Name | Type | Value | Description |
| ------------- | ---- | ----------------------- | ----------- |
| **`word_width`** | `localparam` | Word_size * `BYTE | Total bits per independent word entry (Evaluates to 8 bits by default). |
| **`data_width`** | `localparam` | word_width | Width dimension equivalent to a single word packet line. |
| **`block_width`** | `localparam` | Block_size * word_width | Total bit-width footprint of an entire cache block line row (Evaluates to 32 bits by default). |
| **`address_width`** | `localparam` | $clog2(\text{RAM\_size} \times \text{Block\_size})$ | Total resolution address bus width required to uniquely map every sub-word element across the system. |
| **`tag_bites`** | `localparam` | $clog2(\text{RAM\_size})$ | Address bits allocated strictly for row indexing decoding tasks. |
| **`offset_bites`** | `localparam` | $clog2(\text{Block\_size})$ | Address bits allocated to locate specific sub-word offsets within a block line row. |

---

## ⚡ Core Hardware Design Realities & Architectural Customizations

### 1. Dynamic Bit-Slicing Logic via Vector Part-Select (`+:`)

Because a block contains multiple grouped words, modifying a single word requires updating a precise segment of a wide bit vector without corrupting adjacent stored data. `RAM6` achieves this cleanly by using the Verilog **indexed part-select operator**:

```verilog
mem_array[tag_wr][offset_wr * data_width +: data_width] <= data_in;
```

This syntax locks the dynamic base bit starting point calculated via your runtime offset multiplication (`offset_wr * data_width`) and slices upward across a fixed, constant bit span length defined by `data_width`. This enables clean, synthesizable sub-word indexing.

#### 2. Full Physical Synthesis Verification (Removal of `$writememh`)

Unlike simulation-only variants, `RAM6` is optimized for production-ready hardware compilation:

-**`$readmemh` (Kept):** Still used inside your `initial` block to pull baseline hex images into memory. Modern synthesis environments (like Xilinx Vivado or Intel Quartus) fully support this task to pre-initialize on-chip FPGA Block RAMs (BRAMs).

-**`$writememh` (Removed):** The un-synthesizable file-dump task was stripped away. This ensures your code compiles flawlessly during downstream physical layout synthesis, completely avoiding the critical compilation failures that occur when real silicon attempts to access a simulation host operating system file interface.

---

## 🧬 Processes

### 1. `write`

-**Trigger:** `( @(posedge clk) )`
-**Type:** always
-**Functional Mechanics:** Monitors inputs on the rising edge of the system clock. If `cs` and `wr` evaluate high, the decoded pointer lines `tag_wr` isolate the correct cache row, and `offset_wr` isolates the target word bit span. The new payload `data_in` is then securely committed via a clean non-blocking assignment (`<=`).

### 2. `read`

-**Trigger:** `( @(*) )`
-**Type:** always
-**Functional Mechanics:** Executes combinationally and responds instantly to input signal transitions. If the device is selected for a read cycle (`cs && rd`), it evaluates the hazard bypass state; if a concurrent write-back is occurring on that exact same index, `data_in` is forwarded straight to `data_out`. Otherwise, it pulls from the active memory cell array using dynamic vector part-selection matching the target block row and offset coordinates. If `rd` drops low, the bus lines safely reset back to a clean logic low ground (`8'b0` or equivalent parameterized data width).
