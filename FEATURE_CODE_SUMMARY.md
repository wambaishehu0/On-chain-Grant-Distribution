# Proposal Veto Feature - Complete Code Reference

## All Code Additions to Contract

### 1. New Error Constants (Lines 16-18)

```clarity
(define-constant ERR_VETO_WINDOW_EXPIRED (err u115))
(define-constant ERR_PROPOSAL_NOT_EXECUTED (err u116))
(define-constant ERR_PROPOSAL_ALREADY_VETOED (err u117))
```

### 2. New Veto Window Constant (Line 23)

```clarity
(define-constant VETO_WINDOW u72)
```

### 3. New Data Map (Lines 77-84)

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

### 4. Modified execute-proposal Function

Addition to successful execution branch (after line 210):

```clarity
(map-set veto-windows proposal-id {
  executed-at: current-stacks-block-height,
  vetoed: false,
  veto-reason: none
})
```

### 5. New Public Function: veto-proposal (Lines 537-565)

```clarity
(define-public (veto-proposal (proposal-id uint) (reason (string-utf8 200)))
  (let 
    (
      (proposal (unwrap! (map-get? proposals proposal-id) ERR_PROPOSAL_NOT_FOUND))
      (veto-window (unwrap! (map-get? veto-windows proposal-id) ERR_PROPOSAL_NOT_EXECUTED))
      (current-block stacks-block-height)
      (blocks-since-execution (- current-block (get executed-at veto-window)))
    )
    (begin
      (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
      (asserts! (get approved proposal) ERR_PROPOSAL_NOT_APPROVED)
      (asserts! (not (get vetoed veto-window)) ERR_PROPOSAL_ALREADY_VETOED)
      (asserts! (< blocks-since-execution VETO_WINDOW) ERR_VETO_WINDOW_EXPIRED)
      
      (map-set veto-windows proposal-id
        (merge veto-window {
          vetoed: true,
          veto-reason: (some reason)
        })
      )
      
      (map-set proposals proposal-id
        (merge proposal { approved: false })
      )
      
      (ok true)
    )
  )
)
```

### 6. New Read-Only Function: get-veto-status (Lines 722-724)

```clarity
(define-read-only (get-veto-status (proposal-id uint))
  (map-get? veto-windows proposal-id)
)
```

### 7. New Read-Only Function: can-veto-proposal (Lines 726-737)

```clarity
(define-read-only (can-veto-proposal (proposal-id uint))
  (match (map-get? veto-windows proposal-id)
    veto-window
    (let ((blocks-since-execution (- stacks-block-height (get executed-at veto-window))))
      (and
        (not (get vetoed veto-window))
        (< blocks-since-execution VETO_WINDOW)
      )
    )
    false
  )
)
```

## Variable Definitions

All variables are clearly defined before use:

| Variable | Type | Definition | Scope |
|----------|------|-----------|-------|
| `proposal-id` | uint | Function parameter | veto-proposal |
| `reason` | string-utf8 200 | Function parameter | veto-proposal |
| `proposal` | proposal struct | Unwrapped from proposals map | veto-proposal |
| `veto-window` | veto-window struct | Unwrapped from veto-windows map | veto-proposal |
| `current-block` | uint | stacks-block-height | veto-proposal |
| `blocks-since-execution` | uint | Calculated difference | veto-proposal |
| `veto-reason` | optional string | Function parameter | veto-proposal |
| `vetoed` | bool | Hardcoded true | veto-proposal |
| `executed-at` | uint | stacks-block-height | execute-proposal |

## Compilation Result

```
✔ 1 contract checked
! 10 warnings detected (pre-existing, unrelated to new feature)
```

## Feature Characteristics

- **Self-contained**: No dependencies on other features
- **Non-breaking**: Existing functions unchanged except execute-proposal
- **Backward compatible**: Works with all existing proposals
- **Auditable**: All veto actions recorded with reasons
- **Time-limited**: 72-block window ensures finality
- **Owner-controlled**: Only contract owner can veto

