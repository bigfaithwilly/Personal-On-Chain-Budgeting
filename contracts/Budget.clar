(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_BUDGET_NOT_FOUND (err u101))
(define-constant ERR_CATEGORY_EXISTS (err u102))
(define-constant ERR_INSUFFICIENT_BUDGET (err u103))
(define-constant ERR_INVALID_AMOUNT (err u104))
(define-constant ERR_INVALID_PERIOD (err u105))
(define-constant ERR_GOAL_NOT_FOUND (err u106))
(define-constant ERR_GOAL_COMPLETED (err u107))
(define-constant ERR_DEADLINE_PASSED (err u108))
(define-constant ERR_INVALID_THRESHOLD (err u109))
(define-constant ERR_THRESHOLD_NOT_FOUND (err u110))
(define-constant ERR_THRESHOLD_ALREADY_SET (err u111))
(define-constant ERR_RECURRING_NOT_FOUND (err u112))
(define-constant ERR_RECURRING_DISABLED (err u113))
(define-constant ERR_RECURRING_NOT_DUE (err u114))
(define-constant ERR_INVALID_TRANSFER (err u115))
(define-constant ERR_INSUFFICIENT_TRANSFERABLE (err u116))
(define-constant ERR_SAME_BUDGET_TRANSFER (err u117))

(define-data-var next-budget-id uint u1)
(define-data-var next-goal-id uint u1)

(define-map budgets
  { user: principal, budget-id: uint }
  {
    name: (string-ascii 50),
    total-limit: uint,
    current-spent: uint,
    reset-period: uint,
    last-reset: uint,
    active: bool
  }
)

(define-map budget-categories
  { user: principal, budget-id: uint, category: (string-ascii 30) }
  {
    limit: uint,
    spent: uint,
    active: bool
  }
)

(define-map user-budget-count
  { user: principal }
  { count: uint }
)

(define-map expenses
  { user: principal, expense-id: uint }
  {
    budget-id: uint,
    category: (string-ascii 30),
    amount: uint,
    description: (string-ascii 100),
    timestamp: uint
  }
)

(define-data-var next-expense-id uint u1)

(define-map savings-goals
  { user: principal, goal-id: uint }
  {
    name: (string-ascii 50),
    target-amount: uint,
    current-saved: uint,
    deadline: uint,
    created: uint,
    active: bool,
    completed: bool
  }
)

(define-map goal-contributions
  { user: principal, goal-id: uint, contribution-id: uint }
  {
    amount: uint,
    timestamp: uint,
    description: (string-ascii 100)
  }
)

(define-map user-goal-count
  { user: principal }
  { count: uint }
)

(define-data-var next-contribution-id uint u1)

(define-map budget-alert-thresholds
  { user: principal, budget-id: uint, threshold-level: uint }
  { threshold-percentage: uint }
)

(define-map threshold-status
  { user: principal, budget-id: uint, threshold-level: uint }
  { crossed: bool, crossed-at: uint }
)

(define-map category-threshold-status
  { user: principal, budget-id: uint, category: (string-ascii 30), threshold-level: uint }
  { crossed: bool, crossed-at: uint }
)

(define-map recurring-expenses
  { budget-id: uint, recurring-id: uint }
  {
    name: (string-ascii 50),
    amount: uint,
    frequency: uint,
    category: (string-ascii 30),
    enabled: bool,
    last-executed: uint
  }
)

(define-data-var next-recurring-id uint u1)

(define-map budget-transfers
  { user: principal, transfer-id: uint }
  {
    from-budget-id: uint,
    to-budget-id: uint,
    amount: uint,
    timestamp: uint,
    description: (string-ascii 100)
  }
)

(define-data-var next-transfer-id uint u1)

(define-map user-transfer-count
  { user: principal }
  { count: uint }
)

(define-public (create-budget (name (string-ascii 50)) (total-limit uint) (reset-period uint))
  (let (
    (user tx-sender)
    (budget-id (var-get next-budget-id))
    (current-block stacks-block-height)
  )
    (asserts! (> total-limit u0) ERR_INVALID_AMOUNT)
    (asserts! (or (is-eq reset-period u1) (is-eq reset-period u4) (is-eq reset-period u12) (is-eq reset-period u52)) ERR_INVALID_PERIOD)
    
    (map-set budgets
      { user: user, budget-id: budget-id }
      {
        name: name,
        total-limit: total-limit,
        current-spent: u0,
        reset-period: reset-period,
        last-reset: current-block,
        active: true
      }
    )
    
    (map-set user-budget-count
      { user: user }
      { count: (+ (get-user-budget-count user) u1) }
    )
    
    (var-set next-budget-id (+ budget-id u1))
    (ok budget-id)
  )
)

(define-public (add-category (budget-id uint) (category (string-ascii 30)) (limit uint))
  (let (
    (user tx-sender)
    (budget-data (unwrap! (get-budget user budget-id) ERR_BUDGET_NOT_FOUND))
  )
    (asserts! (> limit u0) ERR_INVALID_AMOUNT)
    (asserts! (get active budget-data) ERR_BUDGET_NOT_FOUND)
    (asserts! (is-none (map-get? budget-categories { user: user, budget-id: budget-id, category: category })) ERR_CATEGORY_EXISTS)
    
    (map-set budget-categories
      { user: user, budget-id: budget-id, category: category }
      {
        limit: limit,
        spent: u0,
        active: true
      }
    )
    (ok true)
  )
)

(define-public (add-expense (budget-id uint) (category (string-ascii 30)) (amount uint) (description (string-ascii 100)))
  (let (
    (user tx-sender)
    (expense-id (var-get next-expense-id))
    (budget-data (unwrap! (get-budget user budget-id) ERR_BUDGET_NOT_FOUND))
    (category-data (unwrap! (map-get? budget-categories { user: user, budget-id: budget-id, category: category }) ERR_BUDGET_NOT_FOUND))
    (new-category-spent (+ (get spent category-data) amount))
    (new-total-spent (+ (get current-spent budget-data) amount))
    (current-block stacks-block-height)
  )
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (get active budget-data) ERR_BUDGET_NOT_FOUND)
    (asserts! (get active category-data) ERR_BUDGET_NOT_FOUND)
    (asserts! (<= new-category-spent (get limit category-data)) ERR_INSUFFICIENT_BUDGET)
    (asserts! (<= new-total-spent (get total-limit budget-data)) ERR_INSUFFICIENT_BUDGET)
    
    (map-set budget-categories
      { user: user, budget-id: budget-id, category: category }
      (merge category-data { spent: new-category-spent })
    )
    
    (map-set budgets
      { user: user, budget-id: budget-id }
      (merge budget-data { current-spent: new-total-spent })
    )
    
    (map-set expenses
      { user: user, expense-id: expense-id }
      {
        budget-id: budget-id,
        category: category,
        amount: amount,
        description: description,
        timestamp: current-block
      }
    )
    
    (var-set next-expense-id (+ expense-id u1))
    
    (if (is-ok (check-budget-threshold user budget-id new-total-spent (get total-limit budget-data))) true true)
    (if (is-ok (check-category-threshold user budget-id category new-category-spent (get limit category-data))) true true)
    
    (ok expense-id)
  )
)

(define-public (reset-budget (budget-id uint))
  (let (
    (user tx-sender)
    (budget-data (unwrap! (get-budget user budget-id) ERR_BUDGET_NOT_FOUND))
    (current-block stacks-block-height)
    (blocks-since-reset (- current-block (get last-reset budget-data)))
    (reset-period-blocks (* (get reset-period budget-data) u144))
  )
    (asserts! (get active budget-data) ERR_BUDGET_NOT_FOUND)
    (asserts! (>= blocks-since-reset reset-period-blocks) ERR_UNAUTHORIZED)
    
    (map-set budgets
      { user: user, budget-id: budget-id }
      (merge budget-data { 
        current-spent: u0,
        last-reset: current-block
      })
    )
    
    (reset-all-categories user budget-id)
  )
)

(define-public (deactivate-budget (budget-id uint))
  (let (
    (user tx-sender)
    (budget-data (unwrap! (get-budget user budget-id) ERR_BUDGET_NOT_FOUND))
  )
    (asserts! (get active budget-data) ERR_BUDGET_NOT_FOUND)
    
    (map-set budgets
      { user: user, budget-id: budget-id }
      (merge budget-data { active: false })
    )
    (ok true)
  )
)

(define-public (activate-budget (budget-id uint))
  (let (
    (user tx-sender)
    (budget-data (unwrap! (get-budget user budget-id) ERR_BUDGET_NOT_FOUND))
  )
    (asserts! (not (get active budget-data)) ERR_UNAUTHORIZED)
    
    (map-set budgets
      { user: user, budget-id: budget-id }
      (merge budget-data { active: true })
    )
    (ok true)
  )
)

(define-public (update-category-limit (budget-id uint) (category (string-ascii 30)) (new-limit uint))
  (let (
    (user tx-sender)
    (budget-data (unwrap! (get-budget user budget-id) ERR_BUDGET_NOT_FOUND))
    (category-data (unwrap! (map-get? budget-categories { user: user, budget-id: budget-id, category: category }) ERR_BUDGET_NOT_FOUND))
  )
    (asserts! (> new-limit u0) ERR_INVALID_AMOUNT)
    (asserts! (get active budget-data) ERR_BUDGET_NOT_FOUND)
    (asserts! (get active category-data) ERR_BUDGET_NOT_FOUND)
    
    (map-set budget-categories
      { user: user, budget-id: budget-id, category: category }
      (merge category-data { limit: new-limit })
    )
    (ok true)
  )
)

(define-read-only (get-budget (user principal) (budget-id uint))
  (map-get? budgets { user: user, budget-id: budget-id })
)

(define-read-only (get-category (user principal) (budget-id uint) (category (string-ascii 30)))
  (map-get? budget-categories { user: user, budget-id: budget-id, category: category })
)

(define-read-only (get-expense (user principal) (expense-id uint))
  (map-get? expenses { user: user, expense-id: expense-id })
)

(define-read-only (get-user-budget-count (user principal))
  (default-to u0 (get count (map-get? user-budget-count { user: user })))
)

(define-read-only (get-budget-remaining (user principal) (budget-id uint))
  (match (get-budget user budget-id)
    budget-data (ok (- (get total-limit budget-data) (get current-spent budget-data)))
    ERR_BUDGET_NOT_FOUND
  )
)

(define-read-only (get-category-remaining (user principal) (budget-id uint) (category (string-ascii 30)))
  (match (get-category user budget-id category)
    category-data (ok (- (get limit category-data) (get spent category-data)))
    ERR_BUDGET_NOT_FOUND
  )
)

(define-read-only (get-budget-status (user principal) (budget-id uint))
  (match (get-budget user budget-id)
    budget-data
    (let (
      (remaining (- (get total-limit budget-data) (get current-spent budget-data)))
      (percentage-used (/ (* (get current-spent budget-data) u100) (get total-limit budget-data)))
    )
      (ok {
        active: (get active budget-data),
        remaining: remaining,
        percentage-used: percentage-used,
        over-budget: (> (get current-spent budget-data) (get total-limit budget-data))
      })
    )
    ERR_BUDGET_NOT_FOUND
  )
)

(define-read-only (needs-reset (user principal) (budget-id uint))
  (match (get-budget user budget-id)
    budget-data
    (let (
      (current-block stacks-block-height)
      (blocks-since-reset (- current-block (get last-reset budget-data)))
      (reset-period-blocks (* (get reset-period budget-data) u144))
    )
      (ok (>= blocks-since-reset reset-period-blocks))
    )
    ERR_BUDGET_NOT_FOUND
  )
)

(define-private (reset-all-categories (user principal) (budget-id uint))
  (ok true)
)

(define-read-only (get-next-budget-id)
  (var-get next-budget-id)
)

(define-read-only (get-next-expense-id)
  (var-get next-expense-id)
)

(define-public (create-savings-goal (name (string-ascii 50)) (target-amount uint) (deadline-blocks uint))
  (let (
    (user tx-sender)
    (goal-id (var-get next-goal-id))
    (current-block stacks-block-height)
    (goal-deadline (+ current-block deadline-blocks))
  )
    (asserts! (> target-amount u0) ERR_INVALID_AMOUNT)
    (asserts! (> deadline-blocks u0) ERR_INVALID_PERIOD)
    
    (map-set savings-goals
      { user: user, goal-id: goal-id }
      {
        name: name,
        target-amount: target-amount,
        current-saved: u0,
        deadline: goal-deadline,
        created: current-block,
        active: true,
        completed: false
      }
    )
    
    (map-set user-goal-count
      { user: user }
      { count: (+ (get-user-goal-count user) u1) }
    )
    
    (var-set next-goal-id (+ goal-id u1))
    (ok goal-id)
  )
)

(define-public (contribute-to-goal (goal-id uint) (amount uint) (description (string-ascii 100)))
  (let (
    (user tx-sender)
    (contribution-id (var-get next-contribution-id))
    (goal-data (unwrap! (get-savings-goal user goal-id) ERR_GOAL_NOT_FOUND))
    (new-saved (+ (get current-saved goal-data) amount))
    (current-block stacks-block-height)
    (is-completed (>= new-saved (get target-amount goal-data)))
  )
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (get active goal-data) ERR_GOAL_NOT_FOUND)
    (asserts! (not (get completed goal-data)) ERR_GOAL_COMPLETED)
    (asserts! (< current-block (get deadline goal-data)) ERR_DEADLINE_PASSED)
    
    (map-set savings-goals
      { user: user, goal-id: goal-id }
      (merge goal-data { 
        current-saved: new-saved,
        completed: is-completed
      })
    )
    
    (map-set goal-contributions
      { user: user, goal-id: goal-id, contribution-id: contribution-id }
      {
        amount: amount,
        timestamp: current-block,
        description: description
      }
    )
    
    (var-set next-contribution-id (+ contribution-id u1))
    (ok { contribution-id: contribution-id, goal-completed: is-completed })
  )
)

(define-public (deactivate-savings-goal (goal-id uint))
  (let (
    (user tx-sender)
    (goal-data (unwrap! (get-savings-goal user goal-id) ERR_GOAL_NOT_FOUND))
  )
    (asserts! (get active goal-data) ERR_GOAL_NOT_FOUND)
    (asserts! (not (get completed goal-data)) ERR_GOAL_COMPLETED)
    
    (map-set savings-goals
      { user: user, goal-id: goal-id }
      (merge goal-data { active: false })
    )
    (ok true)
  )
)

(define-public (reactivate-savings-goal (goal-id uint))
  (let (
    (user tx-sender)
    (goal-data (unwrap! (get-savings-goal user goal-id) ERR_GOAL_NOT_FOUND))
    (current-block stacks-block-height)
  )
    (asserts! (not (get active goal-data)) ERR_UNAUTHORIZED)
    (asserts! (not (get completed goal-data)) ERR_GOAL_COMPLETED)
    (asserts! (< current-block (get deadline goal-data)) ERR_DEADLINE_PASSED)
    
    (map-set savings-goals
      { user: user, goal-id: goal-id }
      (merge goal-data { active: true })
    )
    (ok true)
  )
)

(define-read-only (get-savings-goal (user principal) (goal-id uint))
  (map-get? savings-goals { user: user, goal-id: goal-id })
)

(define-read-only (get-goal-contribution (user principal) (goal-id uint) (contribution-id uint))
  (map-get? goal-contributions { user: user, goal-id: goal-id, contribution-id: contribution-id })
)

(define-read-only (get-user-goal-count (user principal))
  (default-to u0 (get count (map-get? user-goal-count { user: user })))
)

(define-read-only (get-goal-progress (user principal) (goal-id uint))
  (match (get-savings-goal user goal-id)
    goal-data
    (let (
      (progress-percentage (/ (* (get current-saved goal-data) u100) (get target-amount goal-data)))
      (remaining-amount (- (get target-amount goal-data) (get current-saved goal-data)))
      (current-block stacks-block-height)
      (blocks-remaining (if (> (get deadline goal-data) current-block)
                          (- (get deadline goal-data) current-block)
                          u0))
    )
      (ok {
        progress-percentage: progress-percentage,
        remaining-amount: remaining-amount,
        blocks-remaining: blocks-remaining,
        is-completed: (get completed goal-data),
        deadline-passed: (>= current-block (get deadline goal-data))
      })
    )
    ERR_GOAL_NOT_FOUND
  )
)

(define-read-only (get-goal-status (user principal) (goal-id uint))
  (match (get-savings-goal user goal-id)
    goal-data
    (let (
      (current-block stacks-block-height)
      (deadline-passed (>= current-block (get deadline goal-data)))
      (is-overdue (and (not (get completed goal-data)) deadline-passed))
    )
      (ok {
        active: (get active goal-data),
        completed: (get completed goal-data),
        deadline-passed: deadline-passed,
        overdue: is-overdue,
        current-saved: (get current-saved goal-data),
        target-amount: (get target-amount goal-data)
      })
    )
    ERR_GOAL_NOT_FOUND
  )
)

(define-read-only (get-next-goal-id)
  (var-get next-goal-id)
)

(define-read-only (get-next-contribution-id)
  (var-get next-contribution-id)
)

(define-public (set-budget-threshold (budget-id uint) (threshold-level uint) (threshold-percentage uint))
  (let (
    (user tx-sender)
    (budget-data (unwrap! (get-budget user budget-id) ERR_BUDGET_NOT_FOUND))
  )
    (asserts! (and (>= threshold-level u1) (<= threshold-level u3)) ERR_INVALID_THRESHOLD)
    (asserts! (and (> threshold-percentage u0) (<= threshold-percentage u100)) ERR_INVALID_THRESHOLD)
    (asserts! (get active budget-data) ERR_BUDGET_NOT_FOUND)
    
    (map-set budget-alert-thresholds
      { user: user, budget-id: budget-id, threshold-level: threshold-level }
      { threshold-percentage: threshold-percentage }
    )
    (ok true)
  )
)

(define-public (initialize-default-thresholds (budget-id uint))
  (let (
    (user tx-sender)
    (budget-data (unwrap! (get-budget user budget-id) ERR_BUDGET_NOT_FOUND))
  )
    (asserts! (get active budget-data) ERR_BUDGET_NOT_FOUND)
    
    (map-set budget-alert-thresholds
      { user: user, budget-id: budget-id, threshold-level: u1 }
      { threshold-percentage: u70 }
    )
    (map-set budget-alert-thresholds
      { user: user, budget-id: budget-id, threshold-level: u2 }
      { threshold-percentage: u85 }
    )
    (map-set budget-alert-thresholds
      { user: user, budget-id: budget-id, threshold-level: u3 }
      { threshold-percentage: u95 }
    )
    (ok true)
  )
)

(define-private (check-budget-threshold (user principal) (budget-id uint) (current-spent uint) (budget-limit uint))
  (let (
    (percentage (/ (* current-spent u100) budget-limit))
    (current-block stacks-block-height)
  )
    (match (map-get? budget-alert-thresholds { user: user, budget-id: budget-id, threshold-level: u1 })
      threshold1 (if (>= percentage (get threshold-percentage threshold1))
        (map-set threshold-status
          { user: user, budget-id: budget-id, threshold-level: u1 }
          { crossed: true, crossed-at: current-block }
        )
        true
      )
      true
    )
    (match (map-get? budget-alert-thresholds { user: user, budget-id: budget-id, threshold-level: u2 })
      threshold2 (if (>= percentage (get threshold-percentage threshold2))
        (map-set threshold-status
          { user: user, budget-id: budget-id, threshold-level: u2 }
          { crossed: true, crossed-at: current-block }
        )
        true
      )
      true
    )
    (match (map-get? budget-alert-thresholds { user: user, budget-id: budget-id, threshold-level: u3 })
      threshold3 (if (>= percentage (get threshold-percentage threshold3))
        (map-set threshold-status
          { user: user, budget-id: budget-id, threshold-level: u3 }
          { crossed: true, crossed-at: current-block }
        )
        true
      )
      true
    )
    (ok true)
  )
)

(define-private (check-category-threshold (user principal) (budget-id uint) (category (string-ascii 30)) (current-spent uint) (category-limit uint))
  (let (
    (percentage (/ (* current-spent u100) category-limit))
    (current-block stacks-block-height)
  )
    (match (map-get? budget-alert-thresholds { user: user, budget-id: budget-id, threshold-level: u1 })
      threshold1 (if (>= percentage (get threshold-percentage threshold1))
        (map-set category-threshold-status
          { user: user, budget-id: budget-id, category: category, threshold-level: u1 }
          { crossed: true, crossed-at: current-block }
        )
        true
      )
      true
    )
    (ok true)
  )
)

(define-read-only (get-budget-threshold (user principal) (budget-id uint) (threshold-level uint))
  (map-get? budget-alert-thresholds { user: user, budget-id: budget-id, threshold-level: threshold-level })
)

(define-read-only (get-budget-threshold-status (user principal) (budget-id uint) (threshold-level uint))
  (match (get-budget user budget-id)
    budget-data
    (let (
      (percentage (/ (* (get current-spent budget-data) u100) (get total-limit budget-data)))
      (status (map-get? threshold-status { user: user, budget-id: budget-id, threshold-level: threshold-level }))
    )
      (ok {
        crossed: (default-to false (get crossed status)),
        crossed-at: (default-to u0 (get crossed-at status)),
        percentage: percentage
      })
    )
    ERR_BUDGET_NOT_FOUND
  )
)

(define-read-only (get-current-spending-percentage (user principal) (budget-id uint))
  (match (get-budget user budget-id)
    budget-data
    (ok (/ (* (get current-spent budget-data) u100) (get total-limit budget-data)))
    ERR_BUDGET_NOT_FOUND
  )
)

(define-public (create-recurring-expense (budget-id uint) (name (string-ascii 50)) (amount uint) (frequency uint) (category (string-ascii 30)))
  (let (
    (user tx-sender)
    (budget-data (unwrap! (get-budget user budget-id) ERR_BUDGET_NOT_FOUND))
    (recurring-id (var-get next-recurring-id))
  )
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (> frequency u0) ERR_INVALID_PERIOD)
    (asserts! (get active budget-data) ERR_BUDGET_NOT_FOUND)
    
    (map-set recurring-expenses
      { budget-id: budget-id, recurring-id: recurring-id }
      {
        name: name,
        amount: amount,
        frequency: frequency,
        category: category,
        enabled: true,
        last-executed: u0
      }
    )
    
    (var-set next-recurring-id (+ recurring-id u1))
    (ok recurring-id)
  )
)

(define-public (toggle-recurring-expense (budget-id uint) (recurring-id uint))
  (let (
    (user tx-sender)
    (budget-data (unwrap! (get-budget user budget-id) ERR_BUDGET_NOT_FOUND))
    (recurring-data (unwrap! (map-get? recurring-expenses { budget-id: budget-id, recurring-id: recurring-id }) ERR_RECURRING_NOT_FOUND))
  )
    (asserts! (get active budget-data) ERR_BUDGET_NOT_FOUND)
    
    (map-set recurring-expenses
      { budget-id: budget-id, recurring-id: recurring-id }
      (merge recurring-data { enabled: (not (get enabled recurring-data)) })
    )
    (ok true)
  )
)

(define-public (execute-recurring-expense (budget-id uint) (recurring-id uint))
  (let (
    (user tx-sender)
    (budget-data (unwrap! (get-budget user budget-id) ERR_BUDGET_NOT_FOUND))
    (recurring-data (unwrap! (map-get? recurring-expenses { budget-id: budget-id, recurring-id: recurring-id }) ERR_RECURRING_NOT_FOUND))
    (current-block stacks-block-height)
    (blocks-since-exec (- current-block (get last-executed recurring-data)))
    (expense-result (add-expense budget-id (get category recurring-data) (get amount recurring-data) (get name recurring-data)))
  )
    (asserts! (get active budget-data) ERR_BUDGET_NOT_FOUND)
    (asserts! (get enabled recurring-data) ERR_RECURRING_DISABLED)
    (asserts! (or (is-eq (get last-executed recurring-data) u0) (>= blocks-since-exec (get frequency recurring-data))) ERR_RECURRING_NOT_DUE)
    
    (map-set recurring-expenses
      { budget-id: budget-id, recurring-id: recurring-id }
      (merge recurring-data { last-executed: current-block })
    )
    
    expense-result
  )
)

(define-public (delete-recurring-expense (budget-id uint) (recurring-id uint))
  (let (
    (user tx-sender)
    (budget-data (unwrap! (get-budget user budget-id) ERR_BUDGET_NOT_FOUND))
    (recurring-data (unwrap! (map-get? recurring-expenses { budget-id: budget-id, recurring-id: recurring-id }) ERR_RECURRING_NOT_FOUND))
  )
    (asserts! (get active budget-data) ERR_BUDGET_NOT_FOUND)
    
    (map-delete recurring-expenses { budget-id: budget-id, recurring-id: recurring-id })
    (ok true)
  )
)

(define-read-only (get-recurring-expense (budget-id uint) (recurring-id uint))
  (map-get? recurring-expenses { budget-id: budget-id, recurring-id: recurring-id })
)

(define-read-only (is-recurring-due (budget-id uint) (recurring-id uint))
  (match (map-get? recurring-expenses { budget-id: budget-id, recurring-id: recurring-id })
    recurring-data
    (let (
      (current-block stacks-block-height)
      (blocks-since-exec (- current-block (get last-executed recurring-data)))
    )
      (ok (or (is-eq (get last-executed recurring-data) u0) (>= blocks-since-exec (get frequency recurring-data))))
    )
    ERR_RECURRING_NOT_FOUND
  )
)

(define-read-only (get-next-recurring-id)
  (var-get next-recurring-id)
)

(define-public (transfer-budget (from-budget-id uint) (to-budget-id uint) (amount uint) (description (string-ascii 100)))
  (let (
    (user tx-sender)
    (from-budget (unwrap! (get-budget user from-budget-id) ERR_BUDGET_NOT_FOUND))
    (to-budget (unwrap! (get-budget user to-budget-id) ERR_BUDGET_NOT_FOUND))
    (transfer-id (var-get next-transfer-id))
    (current-block stacks-block-height)
    (available-amount (- (get total-limit from-budget) (get current-spent from-budget)))
  )
    (asserts! (not (is-eq from-budget-id to-budget-id)) ERR_SAME_BUDGET_TRANSFER)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (get active from-budget) ERR_BUDGET_NOT_FOUND)
    (asserts! (get active to-budget) ERR_BUDGET_NOT_FOUND)
    (asserts! (>= available-amount amount) ERR_INSUFFICIENT_TRANSFERABLE)
    
    (map-set budgets
      { user: user, budget-id: from-budget-id }
      (merge from-budget { total-limit: (- (get total-limit from-budget) amount) })
    )
    
    (map-set budgets
      { user: user, budget-id: to-budget-id }
      (merge to-budget { total-limit: (+ (get total-limit to-budget) amount) })
    )
    
    (map-set budget-transfers
      { user: user, transfer-id: transfer-id }
      {
        from-budget-id: from-budget-id,
        to-budget-id: to-budget-id,
        amount: amount,
        timestamp: current-block,
        description: description
      }
    )
    
    (map-set user-transfer-count
      { user: user }
      { count: (+ (get-user-transfer-count user) u1) }
    )
    
    (var-set next-transfer-id (+ transfer-id u1))
    (ok transfer-id)
  )
)

(define-read-only (get-budget-transfer (user principal) (transfer-id uint))
  (map-get? budget-transfers { user: user, transfer-id: transfer-id })
)

(define-read-only (get-user-transfer-count (user principal))
  (default-to u0 (get count (map-get? user-transfer-count { user: user })))
)

(define-read-only (get-next-transfer-id)
  (var-get next-transfer-id)
)
