# 📦 Entity: RAM1

* **Source Core File**: `rtl design/RAM_1.v`

The `RAM1` module is a high-performance Single-Port Synchronous/Asynchronous Static RAM (SRAM) macro simulation block modeling an integrated 128-bit storage matrix ($16 \times 8\text{-bit}$ words). The module utilizes an industry-standard shared bidirectional inout datapath mesh gated by structural high-impedance tristate drivers, ensuring exclusive mutual exclusion between read and write operations on a single bus line.

---

## 🗺️ Architectural Logic Diagram

![Diagram](RAM1.svg "Structural RTL Block Diagram of the Shared Bus Tristate RAM1 Module")

---

## 🔌 Boundary Interface Ports

| Port Name | Direction | Type | Description |
| :--- | :---: | :---: | :--- |
| **`cs`** | Input | `wire` | Chip Select control bit. Must be asserted high to enable any read or write access memory cycle operations. |
| **`rd`** | Input | `wire` | Read Enable control strobe. Activates the internal data read output path to drive the shared data bus. |
| **`wr`** | Input | `wire` | Write Enable strobe. Dictates a synchronized hardware sample event to modify the internal core storage cells. |
| **`addr`** | Input | `wire [3:0]` | 4-bit synchronous parallel address input vector used to decode and target 1 of the 16 available byte rows. |
| **`data`** | Inout | `wire [7:0]` | Shared 8-bit bidirectional tristate system data bus rail carrying instruction payloads into and out of the macro cell. |

---

## 🎛️ Internal Signals & Silicon Structures

| Signal Name | Type | Bit/Array Bounds | Description |
| :--- | :---: | :---: | :--- |
| **`mem_array`** | `reg` | `[7:0] [0:15]` | High-density internal latch register storage array storing the 16 bytes of data. |
| **`data_out`** | `reg` | `[7:0]` | Internal dedicated hold buffer holding targeted combinational read data words prior to driving the tristate bus. |

---

## ⚡ Core Hardware Design Realities & Architectural Caveats

### 1. Tristate Shared Bus Control Mechanics

To prevent destructive bus contention scenarios on the bidirectional `data` pins, the core isolates its read logic using a hard-coded conditional continuous assignment operator:

```verilog
assign data = (cs && rd && !wr) ? data_out : 8'bz;
```

When a valid read operation is not actively occurring, the output buffer disconnects completely from the shared pad lines by floating into a high-impedance state (8'bz). This leaves the external data bus line safe for external masters to securely drive incoming data payloads without experiencing dynamic current short-circuits.

## 🧬 Behavioral Processes Breakdown

### 1. `write` — Combinational Write Latch Layer

* **Execution Trigger:** Active combinationally when any input line in the environment changes values (`@(*)`).
* **Functional Mechanics:** Evaluates control states immediately. If `cs` and `wr` are held high while `rd` is kept low, the data vector active on the inout bi-directional pins is written into the internal memory register array at the slot mapped out by `addr`.

### 2. `read` — Fully Combinational Memory-Out Read Path

* **Execution Trigger:** Asynchronous execution tracking continuous transitions (`@(*)`).
* **Functional Mechanics:** Monitors the address decode paths instantaneously. If the chip access parameters are met (`cs && !wr && rd`), `data_out` grabs the value sitting inside the targeted address cell. If the device is unselected or writing, the buffer defaults back to a clean logic ground (`8'h00`).