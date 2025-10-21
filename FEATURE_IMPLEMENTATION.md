# Proposal Veto Power with Time-Lock Feature

## Feature Overview

A governance safety mechanism that allows the contract owner to reject an approved proposal within a configurable time window (72 blocks) after execution. This provides a critical safeguard against malicious proposals while maintaining democratic voting principles.

## Value Proposition

1. **Security**: Protects against proposals that pass voting but contain hidden vulnerabilities or malicious intent
2. **Governance Balance**: Maintains owner oversight without removing democratic voting power
3. **Time-Limited**: Veto window expires after 72 blocks (~6 hours), ensuring finality and preventing indefinite uncertainty
4. **Transparency**: All veto actions are recorded with reasons for audit trails
5. **Developer Experience**: Simple, intuitive API for checking veto eligibility and status

## Implementation Details

### New Constants Added

```clarity
(define-constant ERR_VETO_WINDOW_EXPIRED (err u115))
(define-constant ERR_PROPOSAL_NOT_EXECUTED (err u116))
(define-constant ERR_PROPOSAL_ALREADY_VETOED (err u117))
(define-constant VETO_WINDOW u72)
```

- `VETO_WINDOW`: 72 blocks (~6 hours on Stacks) for veto eligibility
- Error codes for veto-specific failures

### New Data Structure

```clarity
(define-map veto-windows
  uint
  {
    executed-at: uint,
    vetoed: bool,
    veto-reason: (optional (string-utf8 200))
  }
)
```

Tracks veto status for each executed proposal:
- `executed-at`: Block height when proposal was executed
- `vetoed`: Boolean flag indicating if proposal was vetoed
- `veto-reason`: Optional reason for veto (max 200 characters)

### Modified Functions

**execute-proposal**: Now records veto window when proposal is approved and executed

```clarity
(map-set veto-windows proposal-id {
  executed-at: current-stacks-block-height,
  vetoed: false,
  veto-reason: none
})
```

### New Public Functions

**veto-proposal(proposal-id: uint, reason: string-utf8 200) -> (ok bool)**

Allows contract owner to veto an approved proposal within the veto window.

Requirements:
- Caller must be contract owner
- Proposal must be approved
- Proposal must not already be vetoed
- Must be within 72 blocks of execution

Effects:
- Marks proposal as vetoed
- Records veto reason
- Sets proposal approved flag to false

### New Read-Only Functions

**get-veto-status(proposal-id: uint) -> (optional veto-window)**

Returns veto window data for a proposal:
- Execution block height
- Veto status
- Veto reason (if applicable)

**can-veto-proposal(proposal-id: uint) -> bool**

Checks if a proposal can still be vetoed:
- Returns true if proposal exists, not yet vetoed, and within veto window
- Returns false otherwise

## Usage Example

```clarity
;; Create and execute a proposal
(create-proposal "Grant" "Description" recipient u1000)
(vote-on-proposal u1 true)
(execute-proposal u1)

;; Check if veto is still possible
(can-veto-proposal u1) ;; Returns true if within 72 blocks

;; Veto the proposal if needed
(veto-proposal u1 "Suspicious recipient activity detected")

;; Check veto status
(get-veto-status u1)
;; Returns: {executed-at: 100, vetoed: true, veto-reason: "Suspicious recipient activity detected"}
```

## Compilation Status

✅ Contract compiles successfully with `clarinet check`
✅ No compilation errors
✅ 10 pre-existing warnings (unrelated to new feature)

## Integration Notes

- Feature is self-contained and does not affect existing functionality
- All existing functions remain unchanged except execute-proposal
- Backward compatible with current proposal system
- No breaking changes to existing APIs

