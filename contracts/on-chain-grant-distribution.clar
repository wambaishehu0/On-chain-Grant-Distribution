(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_PROPOSAL_NOT_FOUND (err u101))
(define-constant ERR_PROPOSAL_EXPIRED (err u102))
(define-constant ERR_PROPOSAL_ALREADY_EXECUTED (err u103))
(define-constant ERR_INSUFFICIENT_FUNDS (err u104))
(define-constant ERR_INVALID_AMOUNT (err u105))
(define-constant ERR_ALREADY_VOTED (err u106))
(define-constant ERR_VOTING_PERIOD_ENDED (err u107))
(define-constant ERR_PROPOSAL_NOT_APPROVED (err u108))
(define-constant ERR_INVALID_RECIPIENT (err u109))
(define-constant ERR_MILESTONE_NOT_FOUND (err u110))
(define-constant ERR_MILESTONE_ALREADY_COMPLETED (err u111))
(define-constant ERR_MILESTONE_NOT_APPROVED (err u112))
(define-constant ERR_ALL_MILESTONES_COMPLETED (err u113))
(define-constant ERR_INVALID_MILESTONE_COUNT (err u114))
(define-constant ERR_VETO_WINDOW_EXPIRED (err u115))
(define-constant ERR_PROPOSAL_NOT_EXECUTED (err u116))
(define-constant ERR_PROPOSAL_ALREADY_VETOED (err u117))

(define-constant CONTRACT_OWNER tx-sender)
(define-constant VOTING_PERIOD u144)
(define-constant MIN_APPROVAL_THRESHOLD u51)
(define-constant VETO_WINDOW u72)

(define-data-var proposal-counter uint u0)
(define-data-var treasury-balance uint u0)
(define-data-var milestone-counter uint u0)

(define-map proposals 
  uint 
  {
    title: (string-utf8 100),
    description: (string-utf8 500),
    recipient: principal,
    amount: uint,
    created-at: uint,
    voting-deadline: uint,
    yes-votes: uint,
    no-votes: uint,
    total-votes: uint,
    executed: bool,
    approved: bool,
    has-milestones: bool,
    total-milestones: uint,
    completed-milestones: uint
  }
)

(define-map votes 
  { proposal-id: uint, voter: principal }
  { vote: bool, voted-at: uint }
)

(define-map dao-members principal bool)

(define-map member-voting-power principal uint)

(define-map milestones 
  uint 
  {
    proposal-id: uint,
    milestone-id: uint,
    title: (string-utf8 100),
    description: (string-utf8 300),
    amount: uint,
    completed: bool,
    approved-by: (optional principal),
    completed-at: (optional uint)
  }
)

(define-map proposal-milestones
  uint
  (list 10 uint)
)

(define-map veto-windows
  uint
  {
    executed-at: uint,
    vetoed: bool,
    veto-reason: (optional (string-utf8 200))
  }
)

(define-public (add-dao-member (member principal) (voting-power uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (asserts! (> voting-power u0) ERR_INVALID_AMOUNT)
    (map-set dao-members member true)
    (map-set member-voting-power member voting-power)
    (ok true)
  )
)

(define-public (remove-dao-member (member principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (map-delete dao-members member)
    (map-delete member-voting-power member)
    (ok true)
  )
)

(define-public (deposit-funds)
  (let ((amount (stx-get-balance tx-sender)))
    (begin
      (asserts! (> amount u0) ERR_INVALID_AMOUNT)
      (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
      (var-set treasury-balance (+ (var-get treasury-balance) amount))
      (ok amount)
    )
  )
)

(define-public (create-proposal 
  (title (string-utf8 100))
  (description (string-utf8 500))
  (recipient principal)
  (amount uint)
)
  (let 
    (
      (proposal-id (+ (var-get proposal-counter) u1))
      (current-stacks-block-height stacks-block-height)
      (deadline (+ current-stacks-block-height VOTING_PERIOD))
    )
    (begin
      (asserts! (default-to false (map-get? dao-members tx-sender)) ERR_NOT_AUTHORIZED)
      (asserts! (> amount u0) ERR_INVALID_AMOUNT)
      (asserts! (not (is-eq recipient (as-contract tx-sender))) ERR_INVALID_RECIPIENT)
      (asserts! (<= amount (var-get treasury-balance)) ERR_INSUFFICIENT_FUNDS)
      
      (map-set proposals proposal-id
        {
          title: title,
          description: description,
          recipient: recipient,
          amount: amount,
          created-at: current-stacks-block-height,
          voting-deadline: deadline,
          yes-votes: u0,
          no-votes: u0,
          total-votes: u0,
          executed: false,
          approved: false,
          has-milestones: false,
          total-milestones: u0,
          completed-milestones: u0
        }
      )
      
      (var-set proposal-counter proposal-id)
      (ok proposal-id)
    )
  )
)

(define-public (vote-on-proposal (proposal-id uint) (vote-yes bool))
  (let 
    (
      (proposal (unwrap! (map-get? proposals proposal-id) ERR_PROPOSAL_NOT_FOUND))
      (voter-power (default-to u0 (map-get? member-voting-power tx-sender)))
      (current-stacks-block-height stacks-block-height)
    )
    (begin
      (asserts! (default-to false (map-get? dao-members tx-sender)) ERR_NOT_AUTHORIZED)
      (asserts! (is-none (map-get? votes { proposal-id: proposal-id, voter: tx-sender })) ERR_ALREADY_VOTED)
      (asserts! (<= current-stacks-block-height (get voting-deadline proposal)) ERR_VOTING_PERIOD_ENDED)
      (asserts! (> voter-power u0) ERR_INVALID_AMOUNT)
      
      (map-set votes 
        { proposal-id: proposal-id, voter: tx-sender }
        { vote: vote-yes, voted-at: current-stacks-block-height }
      )
      
      (if vote-yes
        (map-set proposals proposal-id
          (merge proposal { 
            yes-votes: (+ (get yes-votes proposal) voter-power),
            total-votes: (+ (get total-votes proposal) voter-power)
          })
        )
        (map-set proposals proposal-id
          (merge proposal { 
            no-votes: (+ (get no-votes proposal) voter-power),
            total-votes: (+ (get total-votes proposal) voter-power)
          })
        )
      )
      
      (ok true)
    )
  )
)

(define-public (execute-proposal (proposal-id uint))
  (let 
    (
      (proposal (unwrap! (map-get? proposals proposal-id) ERR_PROPOSAL_NOT_FOUND))
      (current-stacks-block-height stacks-block-height)
    )
    (begin
      (asserts! (default-to false (map-get? dao-members tx-sender)) ERR_NOT_AUTHORIZED)
      (asserts! (not (get executed proposal)) ERR_PROPOSAL_ALREADY_EXECUTED)
      (asserts! (> current-stacks-block-height (get voting-deadline proposal)) ERR_VOTING_PERIOD_ENDED)
      
      (let ((approval-percentage (if (> (get total-votes proposal) u0)
                                   (/ (* (get yes-votes proposal) u100) (get total-votes proposal))
                                   u0)))
        (if (>= approval-percentage MIN_APPROVAL_THRESHOLD)
          (begin
            (asserts! (>= (var-get treasury-balance) (get amount proposal)) ERR_INSUFFICIENT_FUNDS)
            (try! (as-contract (stx-transfer? (get amount proposal) tx-sender (get recipient proposal))))
            (var-set treasury-balance (- (var-get treasury-balance) (get amount proposal)))
            (map-set proposals proposal-id (merge proposal { executed: true, approved: true }))
            (map-set veto-windows proposal-id {
              executed-at: current-stacks-block-height,
              vetoed: false,
              veto-reason: none
            })
            (ok { executed: true, approved: true })
          )
          (begin
            (map-set proposals proposal-id (merge proposal { executed: true, approved: false }))
            (ok { executed: true, approved: false })
          )
        )
      )
    )
  )
)

(define-public (emergency-withdraw)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (let ((balance (var-get treasury-balance)))
      (var-set treasury-balance u0)
      (as-contract (stx-transfer? balance tx-sender CONTRACT_OWNER))
    )
  )
)

(define-read-only (get-proposal (proposal-id uint))
  (map-get? proposals proposal-id)
)

(define-read-only (get-vote (proposal-id uint) (voter principal))
  (map-get? votes { proposal-id: proposal-id, voter: voter })
)

(define-read-only (get-treasury-balance)
  (var-get treasury-balance)
)

(define-read-only (get-proposal-count)
  (var-get proposal-counter)
)

(define-read-only (is-dao-member (member principal))
  (default-to false (map-get? dao-members member))
)

(define-read-only (get-member-voting-power (member principal))
  (default-to u0 (map-get? member-voting-power member))
)

(define-read-only (get-proposal-status (proposal-id uint))
  (match (map-get? proposals proposal-id)
    proposal 
    (let 
      (
        (current-stacks-block-height stacks-block-height)
        (voting-ended (> current-stacks-block-height (get voting-deadline proposal)))
        (approval-percentage (if (> (get total-votes proposal) u0)
                               (/ (* (get yes-votes proposal) u100) (get total-votes proposal))
                               u0))
      )
      (some {
        voting-active: (not voting-ended),
        approval-percentage: approval-percentage,
        would-pass: (>= approval-percentage MIN_APPROVAL_THRESHOLD),
        executed: (get executed proposal),
        approved: (get approved proposal)
      })
    )
    none
  )
)

(define-read-only (get-all-proposals)
  (let ((count (var-get proposal-counter)))
    (map get-proposal-with-status (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10))
  )
)

(define-read-only (get-proposal-with-status (proposal-id uint))
  (match (map-get? proposals proposal-id)
    proposal 
    {
      proposal: (some proposal),
      status: (some (unwrap-panic (get-proposal-status proposal-id)))
    }
    { proposal: none, status: none }
  )
)

(define-read-only (calculate-quorum-reached (proposal-id uint))
  (match (map-get? proposals proposal-id)
    proposal 
    (let ((total-dao-power (fold + (map get-member-voting-power (list CONTRACT_OWNER)) u0)))
      (>= (get total-votes proposal) (/ total-dao-power u2))
    )
    false
  )
)

(define-public (batch-add-members (members (list 10 { member: principal, power: uint })))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (ok (map add-member-internal members))
  )
)

(define-private (add-member-internal (member-data { member: principal, power: uint }))
  (begin
    (map-set dao-members (get member member-data) true)
    (map-set member-voting-power (get member member-data) (get power member-data))
    true
  )
)

(define-public (update-voting-power (member principal) (new-power uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (asserts! (default-to false (map-get? dao-members member)) ERR_NOT_AUTHORIZED)
    (asserts! (> new-power u0) ERR_INVALID_AMOUNT)
    (map-set member-voting-power member new-power)
    (ok true)
  )
)

(define-public (delegate-vote (proposal-id uint) (delegate principal) (vote-yes bool))
  (let 
    (
      (proposal (unwrap! (map-get? proposals proposal-id) ERR_PROPOSAL_NOT_FOUND))
      (delegator-power (default-to u0 (map-get? member-voting-power tx-sender)))
      (current-stacks-block-height stacks-block-height)
    )
    (begin
      (asserts! (default-to false (map-get? dao-members tx-sender)) ERR_NOT_AUTHORIZED)
      (asserts! (default-to false (map-get? dao-members delegate)) ERR_NOT_AUTHORIZED)
      (asserts! (is-none (map-get? votes { proposal-id: proposal-id, voter: tx-sender })) ERR_ALREADY_VOTED)
      (asserts! (<= current-stacks-block-height (get voting-deadline proposal)) ERR_VOTING_PERIOD_ENDED)
      (asserts! (> delegator-power u0) ERR_INVALID_AMOUNT)
      
      (map-set votes 
        { proposal-id: proposal-id, voter: tx-sender }
        { vote: vote-yes, voted-at: current-stacks-block-height }
      )
      
      (if vote-yes
        (map-set proposals proposal-id
          (merge proposal { 
            yes-votes: (+ (get yes-votes proposal) delegator-power),
            total-votes: (+ (get total-votes proposal) delegator-power)
          })
        )
        (map-set proposals proposal-id
          (merge proposal { 
            no-votes: (+ (get no-votes proposal) delegator-power),
            total-votes: (+ (get total-votes proposal) delegator-power)
          })
        )
      )
      
      (ok true)
    )
  )
)

(define-public (create-milestone-proposal 
  (title (string-utf8 100))
  (description (string-utf8 500))
  (recipient principal)
  (total-amount uint)
  (milestone-count uint)
)
  (let 
    (
      (proposal-id (+ (var-get proposal-counter) u1))
      (current-stacks-block-height stacks-block-height)
      (deadline (+ current-stacks-block-height VOTING_PERIOD))
    )
    (begin
      (asserts! (default-to false (map-get? dao-members tx-sender)) ERR_NOT_AUTHORIZED)
      (asserts! (> total-amount u0) ERR_INVALID_AMOUNT)
      (asserts! (not (is-eq recipient (as-contract tx-sender))) ERR_INVALID_RECIPIENT)
      (asserts! (<= total-amount (var-get treasury-balance)) ERR_INSUFFICIENT_FUNDS)
      (asserts! (and (> milestone-count u0) (<= milestone-count u10)) ERR_INVALID_MILESTONE_COUNT)
      
      (map-set proposals proposal-id
        {
          title: title,
          description: description,
          recipient: recipient,
          amount: total-amount,
          created-at: current-stacks-block-height,
          voting-deadline: deadline,
          yes-votes: u0,
          no-votes: u0,
          total-votes: u0,
          executed: false,
          approved: false,
          has-milestones: true,
          total-milestones: milestone-count,
          completed-milestones: u0
        }
      )
      
      (var-set proposal-counter proposal-id)
      (ok proposal-id)
    )
  )
)

(define-public (add-milestone 
  (proposal-id uint)
  (milestone-title (string-utf8 100))
  (milestone-description (string-utf8 300))
  (amount uint)
)
  (let 
    (
      (proposal (unwrap! (map-get? proposals proposal-id) ERR_PROPOSAL_NOT_FOUND))
      (milestone-id (+ (var-get milestone-counter) u1))
    )
    (begin
      (asserts! (default-to false (map-get? dao-members tx-sender)) ERR_NOT_AUTHORIZED)
      (asserts! (not (get executed proposal)) ERR_PROPOSAL_ALREADY_EXECUTED)
      (asserts! (> amount u0) ERR_INVALID_AMOUNT)
      (asserts! (get has-milestones proposal) ERR_PROPOSAL_NOT_FOUND)
      
      (map-set milestones milestone-id
        {
          proposal-id: proposal-id,
          milestone-id: milestone-id,
          title: milestone-title,
          description: milestone-description,
          amount: amount,
          completed: false,
          approved-by: none,
          completed-at: none
        }
      )
      
      (let ((existing-milestones (default-to (list) (map-get? proposal-milestones proposal-id))))
        (map-set proposal-milestones proposal-id
          (unwrap-panic (as-max-len? (append existing-milestones milestone-id) u10))
        )
      )
      
      (var-set milestone-counter milestone-id)
      (ok milestone-id)
    )
  )
)

(define-public (complete-milestone (milestone-id uint))
  (let 
    (
      (milestone (unwrap! (map-get? milestones milestone-id) ERR_MILESTONE_NOT_FOUND))
      (proposal-id (get proposal-id milestone))
      (proposal (unwrap! (map-get? proposals proposal-id) ERR_PROPOSAL_NOT_FOUND))
    )
    (begin
      (asserts! (default-to false (map-get? dao-members tx-sender)) ERR_NOT_AUTHORIZED)
      (asserts! (not (get completed milestone)) ERR_MILESTONE_ALREADY_COMPLETED)
      (asserts! (get approved proposal) ERR_PROPOSAL_NOT_APPROVED)
      (asserts! (>= (var-get treasury-balance) (get amount milestone)) ERR_INSUFFICIENT_FUNDS)
      
      (try! (as-contract (stx-transfer? (get amount milestone) tx-sender (get recipient proposal))))
      (var-set treasury-balance (- (var-get treasury-balance) (get amount milestone)))
      
      (map-set milestones milestone-id
        (merge milestone { 
          completed: true, 
          approved-by: (some tx-sender),
          completed-at: (some stacks-block-height)
        })
      )
      
      (map-set proposals proposal-id
        (merge proposal { 
          completed-milestones: (+ (get completed-milestones proposal) u1)
        })
      )
      
      (ok true)
    )
  )
)

(define-public (extend-voting-period (proposal-id uint) (additional-blocks uint))
  (let ((proposal (unwrap! (map-get? proposals proposal-id) ERR_PROPOSAL_NOT_FOUND)))
    (begin
      (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
      (asserts! (not (get executed proposal)) ERR_PROPOSAL_ALREADY_EXECUTED)
      (asserts! (> additional-blocks u0) ERR_INVALID_AMOUNT)
      
      (map-set proposals proposal-id
        (merge proposal { 
          voting-deadline: (+ (get voting-deadline proposal) additional-blocks)
        })
      )
      
      (ok true)
    )
  )
)

(define-public (cancel-proposal (proposal-id uint))
  (let ((proposal (unwrap! (map-get? proposals proposal-id) ERR_PROPOSAL_NOT_FOUND)))
    (begin
      (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
      (asserts! (not (get executed proposal)) ERR_PROPOSAL_ALREADY_EXECUTED)

      (map-set proposals proposal-id
        (merge proposal { executed: true, approved: false })
      )

      (ok true)
    )
  )
)

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

(define-read-only (get-voting-stats (proposal-id uint))
  (match (map-get? proposals proposal-id)
    proposal 
    (some {
      yes-votes: (get yes-votes proposal),
      no-votes: (get no-votes proposal),
      total-votes: (get total-votes proposal),
      approval-percentage: (if (> (get total-votes proposal) u0)
                             (/ (* (get yes-votes proposal) u100) (get total-votes proposal))
                             u0),
      blocks-remaining: (if (> (get voting-deadline proposal) stacks-block-height)
                          (- (get voting-deadline proposal) stacks-block-height)
                          u0)
    })
    none
  )
)

(define-read-only (get-treasury-info)
  {
    balance: (var-get treasury-balance),
    total-proposals: (var-get proposal-counter),
    contract-address: (as-contract tx-sender)
  }
)

(define-read-only (can-vote (proposal-id uint) (voter principal))
  (match (map-get? proposals proposal-id)
    proposal 
    (and 
      (default-to false (map-get? dao-members voter))
      (is-none (map-get? votes { proposal-id: proposal-id, voter: voter }))
      (<= stacks-block-height (get voting-deadline proposal))
      (not (get executed proposal))
    )
    false
  )
)

(define-read-only (get-active-proposals)
  (filter is-proposal-active (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10))
)

(define-private (is-proposal-active (proposal-id uint))
  (match (map-get? proposals proposal-id)
    proposal 
    (and 
      (<= stacks-block-height (get voting-deadline proposal))
      (not (get executed proposal))
    )
    false
  )
)

(define-read-only (get-executed-proposals)
  (filter is-proposal-executed (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10))
)

(define-private (is-proposal-executed (proposal-id uint))
  (match (map-get? proposals proposal-id)
    proposal (get executed proposal)
    false
  )
)

(define-read-only (get-milestone (milestone-id uint))
  (map-get? milestones milestone-id)
)

(define-read-only (get-proposal-milestones (proposal-id uint))
  (default-to (list) (map-get? proposal-milestones proposal-id))
)

(define-read-only (get-milestone-progress (proposal-id uint))
  (match (map-get? proposals proposal-id)
    proposal 
    (if (get has-milestones proposal)
      (some {
        total-milestones: (get total-milestones proposal),
        completed-milestones: (get completed-milestones proposal),
        progress-percentage: (if (> (get total-milestones proposal) u0)
                               (/ (* (get completed-milestones proposal) u100) 
                                  (get total-milestones proposal))
                               u0),
        remaining-amount: (- (get amount proposal) 
                           (calculate-completed-milestone-amount proposal-id))
      })
      none
    )
    none
  )
)

(define-read-only (calculate-completed-milestone-amount (proposal-id uint))
  (let ((milestone-ids (default-to (list) (map-get? proposal-milestones proposal-id))))
    (fold calculate-milestone-amount milestone-ids u0)
  )
)

(define-private (calculate-milestone-amount (milestone-id uint) (acc uint))
  (match (map-get? milestones milestone-id)
    milestone 
    (if (get completed milestone)
      (+ acc (get amount milestone))
      acc
    )
    acc
  )
)

(define-read-only (get-next-milestone (proposal-id uint))
  (let ((milestone-ids (default-to (list) (map-get? proposal-milestones proposal-id))))
    (find-next-milestone milestone-ids)
  )
)

(define-private (find-next-milestone (milestone-ids (list 10 uint)))
  (fold check-milestone-completion milestone-ids none)
)

(define-private (check-milestone-completion (milestone-id uint) (acc (optional uint)))
  (if (is-some acc)
    acc
    (match (map-get? milestones milestone-id)
      milestone 
      (if (not (get completed milestone))
        (some milestone-id)
        none
      )
      none
    )
  )
)

(define-read-only (get-milestone-analytics (proposal-id uint))
  (let
    (
      (proposal (unwrap! (map-get? proposals proposal-id) (err u404)))
      (milestone-ids (default-to (list) (map-get? proposal-milestones proposal-id)))
      (completed-amount (calculate-completed-milestone-amount proposal-id))
    )
    (ok {
      has-milestones: (get has-milestones proposal),
      total-amount: (get amount proposal),
      distributed-amount: completed-amount,
      remaining-amount: (- (get amount proposal) completed-amount),
      completion-rate: (if (> (get total-milestones proposal) u0)
                        (/ (* (get completed-milestones proposal) u100)
                           (get total-milestones proposal))
                        u0),
      milestone-ids: milestone-ids
    })
  )
)

(define-read-only (get-veto-status (proposal-id uint))
  (map-get? veto-windows proposal-id)
)

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

(begin
  (map-set dao-members CONTRACT_OWNER true)
  (map-set member-voting-power CONTRACT_OWNER u100)
)
 