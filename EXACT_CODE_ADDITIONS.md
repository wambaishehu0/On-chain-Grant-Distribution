# Exact Code Additions - Copy/Paste Ready

## 1. Error Constants (Add after line 15)

```clarity
(define-constant ERR_VETO_WINDOW_EXPIRED (err u115))
(define-constant ERR_PROPOSAL_NOT_EXECUTED (err u116))
(define-constant ERR_PROPOSAL_ALREADY_VETOED (err u117))
```

## 2. Veto Window Constant (Add after line 22)

```clarity
(define-constant VETO_WINDOW u72)
```

## 3. Veto Windows Data Map (Add after proposal-milestones map)

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

## 4. Modification to execute-proposal Function

**Location**: Inside the successful execution branch, after transferring funds

**Original Code**:
```clarity
(map-set proposals proposal-id (merge proposal { executed: true, approved: true }))
(ok { executed: true, approved: true })
```

**Updated Code**:
```clarity
(map-set proposals proposal-id (merge proposal { executed: true, approved: true }))
(map-set veto-windows proposal-id {
  executed-at: current-stacks-block-height,
  vetoed: false,
  veto-reason: none
})
(ok { executed: true, approved: true })
```

## 5. New Public Function: veto-proposal

**Add after cancel-proposal function**:

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

## 6. New Read-Only Function: get-veto-status

**Add after get-milestone-analytics function**:

```clarity
(define-read-only (get-veto-status (proposal-id uint))
  (map-get? veto-windows proposal-id)
)
```

## 7. New Read-Only Function: can-veto-proposal

**Add after get-veto-status function**:

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

---

## Variable Reference

### In veto-proposal Function

| Variable | Type | Source | Purpose |
|----------|------|--------|---------|
| proposal-id | uint | Parameter | Identifies proposal to veto |
| reason | string-utf8 200 | Parameter | Reason for veto |
| proposal | struct | map-get? proposals | Current proposal data |
| veto-window | struct | map-get? veto-windows | Veto tracking data |
| current-block | uint | stacks-block-height | Current block height |
| blocks-since-execution | uint | Calculated | Time elapsed since execution |

### In execute-proposal Function (Addition)

| Variable | Type | Source | Purpose |
|----------|------|--------|---------|
| current-stacks-block-height | uint | stacks-block-height | Block when proposal executed |
| proposal-id | uint | Calculated | Proposal identifier |

### In can-veto-proposal Function

| Variable | Type | Source | Purpose |
|----------|------|--------|---------|
| veto-window | struct | map-get? veto-windows | Veto tracking data |
| blocks-since-execution | uint | Calculated | Time elapsed since execution |

---

## Compilation Verification

```bash
$ clarinet check
✔ 1 contract checked
! 10 warnings detected (pre-existing)
```

**Result**: ✅ No errors, ready for deployment

---

## Testing Scenarios

### Scenario 1: Successful Veto
1. Create proposal
2. Vote and approve
3. Execute proposal
4. Call veto-proposal within 72 blocks
5. Verify proposal.approved = false

### Scenario 2: Veto Window Expired
1. Create proposal
2. Vote and approve
3. Execute proposal
4. Wait 72+ blocks
5. Call veto-proposal
6. Expect ERR_VETO_WINDOW_EXPIRED

### Scenario 3: Double Veto Prevention
1. Create proposal
2. Vote and approve
3. Execute proposal
4. Call veto-proposal (succeeds)
5. Call veto-proposal again
6. Expect ERR_PROPOSAL_ALREADY_VETOED

### Scenario 4: Check Veto Eligibility
1. Create proposal
2. Vote and approve
3. Execute proposal
4. Call can-veto-proposal
5. Verify returns true
6. Wait 72+ blocks
7. Call can-veto-proposal
8. Verify returns false

