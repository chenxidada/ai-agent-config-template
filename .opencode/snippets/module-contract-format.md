# Module Contract Format

This is the shared format for defining module contracts. Used by both `requirements-output.md` and `master-spec.md`.

When defining a module contract, follow this structure:

```markdown
### M01: <Module Name>

#### Hard Interface Definitions

Define the exact interface that consumers depend on. Include struct layouts, function signatures, and API shapes that other modules call.

```rust
// Example: Message format consumed by downstream modules
#[derive(Debug, Clone, Serialize, Deserialize)]
struct MessageHeader {
    version: u8,          // Protocol version
    msg_type: u16,        // Message type identifier
    payload_length: u32,  // Length of payload in bytes
    timestamp: u64,       // Unix timestamp in milliseconds
}
```

#### Compile-Time Acceptance Criteria

Interface changes that should be caught at compile time, e.g.:
- `static_assert(sizeof(MessageHeader) == 15, "MessageHeader size must be 15 bytes");`
- Enum variant additions that downstream exhaustiveness checks will catch

#### Runtime Acceptance Criteria

Behaviors that can only be verified at runtime, e.g.:
- `version` field must be `1` for all Phase-1 consumers
- `payload_length` must not exceed `MAX_PAYLOAD_SIZE` (1MB)

#### Downstream Commitments

What downstream consumers are guaranteed, e.g.:
- `MessageHeader` layout is fixed for Phase 1-2; will not change until Phase 3
- `msg_type` values 0x00-0x7F are reserved for system messages

#### Source Traceability

| Field / Rule | Source Document | Section |
|--------------|----------------|---------|
| MessageHeader.version | v1.2 Design Doc | §3.1 |
| MAX_PAYLOAD_SIZE = 1MB | requirements.md | §Performance |
```

#### Interface Freeze Order

Phases where interfaces are frozen (cannot be changed without a Correction):

| Freeze Group | Phase | Interfaces Frozen |
|:------------:|:-----:|-------------------|
| FG-1 | Phase 1 | M01.base, M02.query |
| FG-2 | Phase 2 | M01.extended, M03.export |
| FG-3 | Phase 3 | All previously frozen + M04.dashboard |
