# 📦 Entity: RAM7
  
- **File**: `RAM7.v`

The `RAM7` module implements a highly advanced, parameterized **Time-Division Multiplexed (TDM) Single-Port RAM Subsystem** ($RAM\_size \times Block\_size$ words).  

Rather than utilizing physical dual-port storage macros (which double the silicon footprint area on an ASIC/FPGA), `RAM7` structurally splits a single CPU clock cycle into independent **Write** and **Read** execution slots. By running the internal storage matrix on a high-speed clock (`clk_ram`) that is at least twice the frequency of the processor clock (`clk_cpu`), the core resolves structural data hazards entirely within the time domain. From the CPU's perspective, both a read and a write execute simultaneously within a single clock cycle.

---

## 🗺️ Diagram

![Diagram](RAM7.svg "Diagram")

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
| **`cs`** | input | wire | **Chip Select:** Must be driven high (`1`) to unlock the high-speed synchronous control paths. |
| **`clk_cpu`** | input | wire | **CPU System Clock:** Low-speed reference clock tracking the host processor's macro operating windows. |
| **`clk_ram`** | input | wire | **High-Speed RAM Clock:** Fast execution clock running at $\ge 2\times$ the speed of `clk_cpu` to drive the inner state engine. |
| **`rd`** | input | wire | **Read Enable:** Host read intent strobe, steered combinationally to the read execution window. |
| **`wr`** | input | wire | **Write Enable:** Host write intent strobe, steered combinationally to the write execution window. |
| **`addr_rd`** | input | wire [address_width -1:0] | **Read Address Bus:** Incoming target read coordinate mapped out by the host CPU processor. |
| **`addr_wr`** | input | wire [address_width -1:0] | **Write Address Bus:** Incoming target write coordinate mapped out by the host CPU processor. |
| **`data_in`** | input | wire [data_width -1:0] | **Dedicated Data Input:** Custom-sized input channel carrying the single-word payload to write. |
| **`data_out`** | output | [data_width -1:0] | **Dedicated Data Output:** Synchronous register rail capturing and holding active data lookups. |

---

## 🎛️ Signals

| Name | Type | Description |
| ---------------- | --------- | ----------- |
| **`mem_array [0: RAM_size -1]`** | reg [block_width -1:0] | Fully scaled structural cache-line storage array matrix. Each row contains a combined bit-pool spanning `block_width` wide. |
| **`muxed_addr`** | reg [address_width -1:0] | Time-shared address line outputted by the TDM steering network to drive structural decoding. |
| **`muxed_rd`** | reg | Gated read strobe routed dynamically based on the active phase of the `clk_cpu` level. |
| **`muxed_wr`** | reg | Gated write strobe routed dynamically based on the active phase of the `clk_cpu` level. |
| **`tag`** | wire [tag_bites -1:0] | Active cache line block index extracted combinationally from the time-shared `muxed_addr` line. |
| **`offset`** | wire [offset_bites -1:0] | Active sub-word column index extracted combinationally from the time-shared `muxed_addr` line. |

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

### ⚡ Core Hardware Design Realities & Architectural Customizations

#### 1. Time-Division Multiplexed (TDM) Bus Steering

By shifting multiplexing duties entirely into the time domain, `RAM7` avoids structural read-write port conflicts without adding forwarding multiplexer networks or complex address comparators:
***Phase A (`clk_cpu == 1`):** The internal bus routes `addr_wr` and `wr` straight to the storage macro. The memory array locks into a write-only window. Any read request is locked to idle.
***Phase B (`clk_cpu == 0`):** The internal bus switches channels instantly to route `addr_rd` and `rd`. The core locks into a read-only window. Any write request is locked to idle.

Because the internal clock (`clk_ram`) transitions at double the rate, the memory array captures at least one active edge during each separate phase, executing both tasks within a single CPU cycle transparently.

#### 2. Synchronous Read Data Hold Window

Unlike previous implementations that dropped output tracks to `8'h00` or high-impedance `8'hzz` the moment a control line flinched, `RAM7` locks its output data path down into an edge-triggered synchronous structure (`always @(posedge clk_ram)`):

```verilog
if (muxed_rd) begin : read_execute
    data_out <= mem_array[tag][offset * data_width +: data_width];
end
```

If `muxed_rd` drops low (such as during the alternate CPU clock write-back phase), the module omits an `else` constraint for active operations. This acts as an automated synchronous hold property; `data_out` reliably retains the last successfully fetched word packet on the bus until a brand new valid read cycle is explicitly processed.

---

## 🧬 Processes

### 1. `TDM_logic`

***Trigger:** `( @(*) )`
***Type:** always
***Functional Mechanics:** Monitors the state of the host CPU clock level combinationally. If `clk_cpu` is high, the internal bus control signals and address paths are dedicated entirely to the write port channel while forcing the read path to an idle zero ground state. If `clk_cpu` drops low, the bus architecture instantly switches states to route the read address pointers and enable lines while forcing the write command lines to zero.

### 2. `ram_operation`

***Trigger:** `( @(posedge clk_ram) )`
***Type:** always
***Functional Mechanics:** Evaluates system control states on the high-speed rising edge of the internal RAM clock. If `cs` is asserted, it evaluates the time-multiplexed control signals. If `muxed_wr` is hot, it leverages dynamic vector part-selection to commit `data_in` directly to the decoded cache block row and column offsets. If `muxed_rd` is hot, it extracts the target data bit-slice and synchronizes it to the `data_out` register rail. If `cs` drops low, the output pins are immediately disconnected and driven to a floating high-impedance state (`8'hzz`).
