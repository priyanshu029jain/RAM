# 📦 Entity: RAM8

- **File**: `RAM8.v`

The `RAM8` module implements a fully parameterized, **Protocol-Driven Half-Duplex Single-Port RAM Controller Subsystem** ($RAM\_size \times Block\_size$ words).  

Unlike standard raw memory arrays that respond continuously to floating control wires, `RAM8` wraps its memory matrix inside an integrated finite state machine (FSM). The subsystem communicates with a bus master via a strict request/acknowledge handshake protocol (`req`, `ready`, `done`). When no transactions are active, the system transitions to a low-power `idle` state, safely freezing internal address decoding logic and blocking unnecessary write-toggles to save dynamic switching power.

---

## 🗺️ Diagram

![Diagram](RAM8.svg "Architectural Schematic of the FSM-Controlled Parameterized RAM8 Subsystem")

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
| **`cs`** | input | wire | **Chip Select:** Active-high gate control signal; must be high to permit execution during a `write` state. |
| **`rst_n`** | input | wire | **Asynchronous Reset:** Active-low global clearance line forcing the controller back to the `idle` state. |
| **`req`** | input | wire | **Master Request:** Transaction initialization strobe driven by the external master engine. |
| **`clk`** | input | wire | **Master Clock:** Global synchronous edge-trigger timing line driving state transitions. |
| **`cmd`** | input | wire | **Command Select:** Operation flag payload. Driven high (`1`) for write actions; driven low (`0`) for read lookups. |
| **`addr`** | input | wire [address_width -1:0] | **Shared Address Bus:** Multi-word target address vector parsed dynamically into block and offset coordinates. |
| **`data_in`** | input | wire [data_width -1:0] | **Dedicated Data Input:** Single-word transaction payload written into the targeted cache slot. |
| **`data_out`** | output | reg [data_width -1:0] | **Dedicated Data Output:** Combinational register rail returning fetched word lines to the bus master. |
| **`ready`** | output | reg | **Controller Ready Flag:** Handshake signal showing the FSM is in an idle state and prepared to accept a new request. |
| **`done`** | output | reg | **Transaction Done Flag:** Cycle-completion strobe marking the safe resolution of a read or write operation. |

---

## 🎛️ Signals

| Name | Type | Description |
| ---------------- | --------- | ----------- |
| **`mem_array [0: RAM_size -1]`** | reg [block_width -1:0] | Fully scaled structural cache-line storage array matrix. Each row contains a combined bit-pool spanning `block_width` wide. |
| **`current_state`** | reg [1:0] | Registers tracking the active functional state machine cycle context. |
| **`next_state`** | reg [1:0] | Combinational routing vector holding the subsequent step target evaluated by the output logic. |
| **`addr_hold`** | reg [address_width -1:0] | Isolation register used to freeze the active input address during the transaction request window. |
| **`data_hold`** | reg [data_width -1:0] | Isolation register storing incoming write data packets until the scheduled clock update cycle executes. |
| **`tag`** | wire [tag_bites -1:0] | Active cache line block index extracted combinationally from the isolated `addr_hold` line. |
| **`offset`** | wire [offset_bites -1:0] | Active sub-word column index extracted combinationally from the isolated `addr_hold` line. |

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
| **`idle`** | `localparam` | `2'b00` | State defining system readiness, waiting on an external master request payload. |
| **`write`** | `localparam` | `2'b01` | State executing synchronous block sub-bit vector generation tasks. |
| **`read`** | `localparam` | `2'b10` | State isolating and latching targeted memory array content words combinationally. |
| **`data_return`** | `localparam` | `2'b11` | State asserting cycle completion strobes back up to the master interface. |

---

### ⚡ Core Hardware Design Realities & Architectural Customizations

#### 1. Handshake-Gated Bus Parameter Isolation

To isolate the inner storage blocks from any glitches or signal rippling on the long wires of an external system bus while processing, `RAM8` forces input parameter isolation using a structured register fence:

```verilog
if (req && ready) begin
    addr_hold <= addr;
    data_hold <= data_in;
end
```

By sampling inputs exclusively when a valid transaction handshake launches, the core blocks out intermediate bus shifts. This prevents address transitions from firing decoder lines during active operations, eliminating unnecessary dynamic switching power losses.

#### 2. Strict Single-Cycle Boundary Protection

By driving memory lookups and writes through a state sequencing graph, `RAM8` ensures that operations are mutually exclusive by design:
***Write Operations:** The data word is captured in `data_hold` during the `idle` phase and written to the array on the next clock edge inside the `write` state.
***Read Operations:** The target block slice is read combinationally inside the `read` state and driven out to `data_out`.

Both paths route straight to the `data_return` state, which asserts `done = 1'b1` before returning the controller to `idle`. This deterministic layout completely eliminates Read-After-Write (RAW) race conditions.

---

## 🧬 Processes

### 1. `state_transition_logic`

***Trigger:** `( @(posedge clk) )`
***Type:** always
***Functional Mechanics:** Manages synchronous state transitions and captures incoming signals. If the active-low reset line `rst_n` drops low, the controller immediately forces `current_state` back to `idle` and clears the tracking registers. On a standard clock tick, it advances the state machine context to `next_state`, samples the bus payload into isolation buffers when `req && ready` is true, and handles synchronous data writes into `mem_array` using dynamic vector part-selection when inside the `write` state.

### 2. `output_logic`

***Trigger:** `( @(*) )`
***Type:** always
***Functional Mechanics:** Evaluates system behavior using combinational logic. It sets default values for control outputs at the top of the block to prevent dangerous unintended synthesis latches. It then opens a state decoding tree: inside `idle`, it asserts `ready` and watches for incoming requests to determine the next operational path based on the `cmd` bit; inside `write`, it schedules a transition to `data_return`; inside `read`, it looks up the memory matrix slice to populate the output rail; and inside `data_return`, it pulses the `done` strobe high to cleanly close out the host handshake loop.

## 🗺️ Finite State Machine (FSM) Specification

The operational lifecycle of the `RAM8` subsystem is governed by a synchronous, protocol-driven hardware state engine. This state network decouples host bus signaling transitions from the inner memory macro blocks, enforcing structured transaction boundaries.

### FSM State Transition Diagram

```text
+-------------------+
             |     Asynchronous  |
             |      rst_n == 0   |
             +---------+---------|
                       |
                       v
             +-------------------+
  +--------->|       IDLE        |<---------+
  |          |      (2'b00)      |          |
  |          +---------+---------+          |
  |                    |                    |
  |          req == 1  |  req == 1          |
  |          cmd == 1  |  cmd == 0          |
  |          (Write)   |  (Read)            |
  |                    v                    |
  |          +-------------------+          |
  |          |    WRITE (2'b01)  |          |
  |          |  Saves data_hold  |          |
  |          +---------+---------+          |
  |                    |                    |
  |                    |                    |
  |      Unconditional |  Unconditional     |
  |                    v                    |
  |          +-------------------+          |
  |          |    READ (2'b10)   |          |
  |          |  Extracts content |          |
  |          +---------+---------+          |
  |                    |                    |
  |                    +--------------------+
  |                    |
  |                    v
  |          +-------------------+
  +----------|    DATA_RETURN    |
             |      (2'b11)      |
             |  Strobes done=1   |
             +-------------------+
```

```markdown
## 🗺️ Finite State Machine (FSM) Specification

The operational lifecycle of the `RAM8` subsystem is governed by a synchronous, protocol-driven hardware state engine. This state network decouples host bus signaling transitions from the inner memory macro blocks, enforcing structured transaction boundaries.

### FSM State Transition Diagram

```text
             +-------------------+
             |     Asynchronous  |
             |      rst_n == 0   |
             +---------+---------|
                       |
                       v
             +-------------------+
  +--------->|       IDLE        |<---------+
  |          |      (2'b00)      |          |
  |          +---------+---------+          |
  |                    |                    |
  |          req == 1  |  req == 1          |
  |          cmd == 1  |  cmd == 0          |
  |          (Write)   |  (Read)            |
  |                    v                    |
  |          +-------------------+          |
  |          |    WRITE (2'b01)  |          |
  |          |  Saves data_hold  |          |
  |          +---------+---------+          |
  |                    |                    |
  |                    |                    |
  |      Unconditional |  Unconditional     |
  |                    v                    |
  |          +-------------------+          |
  |          |    READ (2'b10)   |          |
  |          |  Extracts content |          |
  |          +---------+---------+          |
  |                    |                    |
  |                    +--------------------+
  |                    |
  |                    v
  |          +-------------------+
  +----------|    DATA_RETURN    |
             |      (2'b11)      |
             |  Strobes done=1   |
             +-------------------+

```

---

### FSM Architectural Brief Description

The `RAM8` controller leverages this 4-state topology to establish a strict handshake loop, ensuring predictable memory interfacing and minimizing dynamic power consumption:

***Low-Power Idle Stasis (`idle`):** The system parks safely inside the `idle` state as long as `req` remains deasserted (`0`). During this window, the controller asserts `ready = 1'b1` to notify the master engine that it is fully operational. Dynamic address line updates and internal bit vector decoding are held idle, dramatically cutting dynamic switching losses.
***Mutual Exclusion Execution Block (`write` / `read`):** Upon capturing an active transaction assertion (`req == 1`), the controller evaluates the master's instruction mode parameter (`cmd`).  
  *If `cmd == 1`, the FSM branches to the **`write`** state, safely clocking the word down into `mem_array` using the isolated parameter bits from `data_hold` on the subsequent rising clock edge.  
  *If `cmd == 0`, the FSM steps into the **`read`** state, instantly routing the targeted word slice via combinational bit-slicing straight to the output bus (`data_out`).
***Transactional Boundary Protection (`data_return`):** Regardless of the operational path chosen, both branches funnel directly into the common **`data_return`** state. Here, the controller pulses its transaction acknowledgement flag (`done = 1'b1`) for exactly one clock cycle, alerting the host master that the read or write request has successfully cleared the hardware pipelines. Following this strobe, the FSM transitions unconditionally back to the low-power `idle` state, protecting against Read-After-Write (RAW) circuit collisions.
