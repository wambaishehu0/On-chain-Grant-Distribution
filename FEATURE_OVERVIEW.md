# Proposal Veto Feature - Complete Overview

## 🎯 Feature Name
**Proposal Veto Power with Time-Lock**

## 📋 Quick Summary

A governance safety mechanism that allows the contract owner to reject approved proposals within a 72-block window (~6 hours) after execution. This provides critical protection against malicious proposals while maintaining democratic voting principles.

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────┐
│         Proposal Execution Flow with Veto               │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  1. Proposal Created                                    │
│     ↓                                                   │
│  2. DAO Members Vote                                    │
│     ↓                                                   │
│  3. Voting Period Ends                                  │
│     ↓                                                   │
│  4. Execute Proposal (if approved)                      │
│     ├─ Transfer funds to recipient                      │
│     └─ Record veto window (72 blocks)                   │
│     ↓                                                   │
│  5. Veto Window Open (72 blocks)                        │
│     ├─ Owner can call veto-proposal                     │
│     ├─ Veto reason recorded                             │
│     └─ Proposal marked as not approved                  │
│     ↓                                                   │
│  6. Veto Window Closed                                  │
│     └─ Proposal becomes immutable                       │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## 📊 Data Structure

### veto-windows Map

```clarity
{
  proposal-id: uint,
  data: {
    executed-at: uint,           // Block height of execution
    vetoed: bool,                // Whether proposal was vetoed
    veto-reason: optional string // Reason for veto (if any)
  }
}
```

---

## 🔧 API Reference

### Public Functions

#### veto-proposal
```clarity
(veto-proposal (proposal-id uint) (reason (string-utf8 200))) -> (ok bool)
```

**Purpose**: Veto an approved proposal within the veto window

**Parameters**:
- `proposal-id`: ID of proposal to veto
- `reason`: Reason for veto (max 200 characters)

**Requirements**:
- Caller must be contract owner
- Proposal must be approved
- Proposal must be executed
- Must be within 72 blocks of execution
- Proposal must not already be vetoed

**Returns**: `(ok true)` on success, error otherwise

---

### Read-Only Functions

#### get-veto-status
```clarity
(get-veto-status (proposal-id uint)) -> (optional veto-window)
```

**Purpose**: Query veto information for a proposal

**Returns**: Veto window data or none if proposal not executed

**Example Response**:
```clarity
{
  executed-at: 1000,
  vetoed: true,
  veto-reason: "Suspicious recipient activity"
}
```

---

#### can-veto-proposal
```clarity
(can-veto-proposal (proposal-id uint)) -> bool
```

**Purpose**: Check if a proposal can still be vetoed

**Returns**: 
- `true` if proposal exists, not vetoed, and within 72-block window
- `false` otherwise

---

## ⚠️ Error Codes

| Code | Constant | Meaning |
|------|----------|---------|
| u115 | ERR_VETO_WINDOW_EXPIRED | Veto window has closed |
| u116 | ERR_PROPOSAL_NOT_EXECUTED | Proposal not yet executed |
| u117 | ERR_PROPOSAL_ALREADY_VETOED | Proposal already vetoed |

---

## 📈 Constants

| Name | Value | Purpose |
|------|-------|---------|
| VETO_WINDOW | u72 | Blocks available for veto (~6 hours) |

---

## 🔐 Security Features

1. **Owner-Only**: Only contract owner can veto
2. **Time-Limited**: 72-block window prevents indefinite uncertainty
3. **Immutable After Window**: Proposals become final after veto window closes
4. **Audit Trail**: All veto actions recorded with reasons
5. **Idempotent**: Cannot veto same proposal twice

---

## 💡 Use Cases

### Use Case 1: Malicious Recipient Detection
```
Scenario: Proposal passes voting, but recipient is discovered to be malicious
Action: Owner calls veto-proposal with reason "Recipient flagged as malicious"
Result: Proposal marked as not approved, funds not transferred
```

### Use Case 2: Vulnerability Discovery
```
Scenario: Proposal executes, but vulnerability found in recipient contract
Action: Owner calls veto-proposal with reason "Recipient contract vulnerability"
Result: Proposal vetoed, preventing further fund transfers
```

### Use Case 3: Governance Check
```
Scenario: Owner wants to verify veto eligibility before taking action
Action: Owner calls can-veto-proposal
Result: Returns true/false based on veto window status
```

---

## ✅ Validation Checklist

- ✅ All variables defined before use
- ✅ Code is clean and simple
- ✅ No unnecessary complexity
- ✅ Self-contained feature
- ✅ No dependencies on other features
- ✅ Compiles without errors
- ✅ Backward compatible
- ✅ Non-breaking changes

---

## 📦 Deployment Information

**File Modified**: `contracts/on-chain-grant-distribution.clar`

**Lines Added**: ~80

**Breaking Changes**: None

**Database Migrations**: None

**Backward Compatibility**: 100%

---

## 🚀 Deployment Steps

1. Review feature implementation
2. Run `clarinet check` ✅
3. Commit with provided message
4. Create PR with provided title/description
5. Deploy to testnet
6. Deploy to mainnet

---

## 📝 Commit Information

**Message**:
```
Introduce proposal veto mechanism with 72-block time-lock for enhanced governance safety
```

**PR Title**:
```
Enhance governance with time-locked proposal veto power
```

---

## 🎓 Learning Resources

- Clarity Documentation: https://docs.stacks.co/clarity
- Stacks Smart Contracts: https://www.stacks.co/
- Clarinet Testing: https://docs.hiro.so/stacks/clarinet-js-sdk

---

## 📞 Support

For questions or issues:
1. Review FEATURE_IMPLEMENTATION.md for detailed documentation
2. Check EXACT_CODE_ADDITIONS.md for code reference
3. See GIT_COMMIT_INFO.md for commit details

