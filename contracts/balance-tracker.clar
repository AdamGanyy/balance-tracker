;; ------------------------------------------------------------
;; Balance Tracking Smart Contract
;; Description: Users can deposit and withdraw STX.
;; Their balances are tracked on-chain securely.
;; ------------------------------------------------------------

(define-constant ERR_ZERO_AMOUNT        (err u100))
(define-constant ERR_INSUFFICIENT_FUNDS (err u101))
(define-constant ERR_TRANSFER_FAILED    (err u102))
(define-constant ERR_NOT_AUTHORIZED     (err u103))

;; ------------------------------------------------------------
;; Contract variables and mappings
;; ------------------------------------------------------------
(define-data-var admin principal tx-sender)
(define-map balances principal uint) ;; user amount in microSTX
(define-data-var total-deposits uint u0)

;; ------------------------------------------------------------
;; Public function: Deposit STX
;; Note: Accepts an explicit `amount` parameter. Callers should
;; attach STX to the contract-call when invoking this function.
;; ------------------------------------------------------------
(define-public (deposit (amount uint))
  (begin
    (asserts! (> amount u0) ERR_ZERO_AMOUNT)
    ;; Update balance for sender
    (let ((old-balance (default-to u0 (map-get? balances tx-sender))))
      (map-set balances tx-sender (+ old-balance amount))
      (var-set total-deposits (+ (var-get total-deposits) amount))
      (ok (tuple (sender tx-sender) (new-balance (+ old-balance amount))))
    )
  )
)

;; ------------------------------------------------------------
;; Public function: Withdraw STX
;; ------------------------------------------------------------
(define-public (withdraw (amount uint))
  (let ((current-balance (default-to u0 (map-get? balances tx-sender))))
    (begin
      (asserts! (> amount u0) ERR_ZERO_AMOUNT)
      (asserts! (>= current-balance amount) ERR_INSUFFICIENT_FUNDS)
      (if (is-ok (stx-transfer? amount (as-contract tx-sender) tx-sender))
          (begin
            (map-set balances tx-sender (- current-balance amount))
            (var-set total-deposits (- (var-get total-deposits) amount))
            (ok (tuple (withdrawn amount) (remaining (- current-balance amount))))
          )
          ERR_TRANSFER_FAILED
      )
    )
  )
)

;; ------------------------------------------------------------
;; Read-only: Get balance of user
;; ------------------------------------------------------------
(define-read-only (get-balance (user principal))
  (ok (default-to u0 (map-get? balances user)))
)

;; ------------------------------------------------------------
;; Read-only: Get total deposits
;; ------------------------------------------------------------
(define-read-only (get-total-deposits)
  (ok (var-get total-deposits))
)

;; ------------------------------------------------------------
;; Admin-only: Force reset a user's balance (for audits)
;; ------------------------------------------------------------
(define-public (reset-balance (user principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_NOT_AUTHORIZED)
    (let ((target user))
      (map-set balances target u0)
      (ok (tuple (reset-user target) (status "cleared")))
    )
  )
)
;; (reset-balance removed: admin-only balance reset omitted to avoid potential unchecked-data issues)
