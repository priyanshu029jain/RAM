# 📦 Entity: RAM4
  
- **File**: `RAM4.v`

The `RAM4` module implements a high-performance, 8-bit **Pseudo-Dual-Port Static RAM** macro cell ($6 \times 8\text{-bit}$ words). Unlike standard single-port memories, this architecture provides completely separate, parallel address channels for read operations (`addr_rd`) and write operations (`addr_wr`). This dual-bus layout allows simultaneous reading and writing within the exact same execution window.  

To prevent read-after-write structural data hazards during simultaneous access to the identical memory row, the core features an integrated combinatorial **Write-First forwarding bypass network**.

---

## 🗺️ Diagram

![Diagram](RAM4.svg "Diagram")

---

## 🔌 Ports

| Port name | Direction | Type | Description |
| --------- | --------- | ---------- | ----------- |
| **`cs`** | input | wire | **Chip Select:** Must be asserted high (`1`) to enable any read or write memory cycles within the macrocell. |
| **`clk`** | input | wire | **Master Clock:** Global system clock driving the sequential write port on its positive edge. |
| **`rd`** | input | wire | **Read Enable:** Active-high control strobe that triggers a combinational data lookup from the internal storage array. |
| **`wr`** | input | wire | **Write Enable:** Active-high control strobe that validates a synchronous data write cycle. |
| **`addr_rd`** | input | wire [3:0] | **Read Address Bus:** Independent 4-bit bus dedicated to indexing the target row for combinational read lookups. |
| **`addr_wr`** | input | wire [3:0] | **Write Address Bus:** Independent 4-bit bus dedicated to indexing the destination row for clocked write updates. |
| **`data_in`** | input | wire [7:0] | **Dedicated Data Input:** Unidirectional 8-bit bus carrying the raw write payload to be saved into the array. |
| **`data_out`** | output | [7:0] | **Dedicated Data Output:** Unidirectional 8-bit output register rail displaying the read data word or bypassed data stream. |

---

## 🎛️ Signals

| Name | Type | Description |
| ---------------- | --------- | ----------- |
| **`mem_array [0:15]`** | reg [7:0] | Core Static RAM memory matrix consisting of 16 individual byte storage registers. |

---

## ⚡ Core Hardware Design Realities & Architectural Customizations

### 1. Synchronous Write Stability (Fixed Latch Issues)

Unlike `RAM1`, `RAM2`, and `RAM3`, which relied on hazardous unclocked combinational blocks for memory updates, `RAM4` introduces a **clock-edge synchronized design**:

```verilog
always @(posedge clk) begin : write
    if (cs && wr) begin
        mem_array[addr_wr] = data_in; 
    end
end
```

By binding writes to @(posedge clk), the synthesis tool maps your memory matrix to actual, stable edge-triggered D-type Flip-Flops (or structural block memory slices) rather than transparency latches. This completely removes the risk of infinite feedback timing loops and prevents random input glitches from corrupting data.

### 2. Write-First Forwarding Bypass Network

When a system attempts to write data to a specific address using addr_wr while simultaneously reading from that exact same address using addr_rd, a structural race condition occurs. Since the write event takes a full clock cycle to update the physical register cells, a standard read would return stale, old data.

RAM4 avoids this data hazard entirely by using an on-chip address comparator bypass network:

```verilog
data_out = (addr_rd == addr_wr) ? data_in : mem_array[addr_rd];
```

If an address match collision is caught (addr_rd == addr_wr), the internal routing multiplexer intercepts the path. It bypasses the slower memory matrix entirely, forwarding the fresh, incoming data_in payload straight to the data_out rail within the exact same clock cycle.

## 🧬 Processes

### 1. `write`

* **Trigger:** `( @(posedge clk) )`
* **Type:** always
* **Functional Mechanics:** Evaluates control states on the rising edge of the system clock. If `cs` and `wr` are captured high, the current data payload on the `data_in` bus lines is latched and written permanently into `mem_array[addr_wr]`.

### 2. `read`

* **Trigger:** `( @(*) )`
* **Type:** always
* **Functional Mechanics:** Executes combinationally and responds instantly to any shifts on your inputs. If the device is selected for a read cycle (`cs && rd`), it checks for an address collision. If the read and write addresses match, it outputs `data_in` immediately. Otherwise, it extracts the stable byte sitting inside `mem_array[addr_rd]`. If `rd` is low, the bus floats into a high-impedance state (`8'hzz`).