;; News Vault - Digital Newspaper/Magazine Access
;; Subscription Service with Recurring Payments

;; Contract owner
(define-constant contract-owner tx-sender)

;; Error codes
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-exists (err u102))
(define-constant err-insufficient-funds (err u103))
(define-constant err-subscription-expired (err u104))
(define-constant err-invalid-duration (err u105))

;; Subscription tiers
(define-constant tier-basic u1)
(define-constant tier-premium u2)
(define-constant tier-pro u3)

;; Subscription durations (in blocks, ~10 min per block)
(define-constant duration-monthly u4320) ;; ~30 days
(define-constant duration-yearly u52560) ;; ~365 days

;; Subscription prices (in microSTX)
(define-map subscription-prices
  { tier: uint }
  { monthly-price: uint, yearly-price: uint }
)

;; User subscriptions
(define-map user-subscriptions
  { user: principal }
  { 
    tier: uint,
    start-block: uint,
    end-block: uint,
    auto-renew: bool,
    payment-amount: uint
  }
)

;; Content access mapping
(define-map content-access
  { content-id: (string-ascii 64) }
  { required-tier: uint, publisher: principal, active: bool }
)

;; Revenue tracking
(define-data-var total-revenue uint u0)

;; Initialize subscription prices
(map-set subscription-prices
  { tier: tier-basic }
  { monthly-price: u5000000, yearly-price: u50000000 } ;; 5 STX monthly, 50 STX yearly
)

(map-set subscription-prices
  { tier: tier-premium }
  { monthly-price: u10000000, yearly-price: u100000000 } ;; 10 STX monthly, 100 STX yearly
)

(map-set subscription-prices
  { tier: tier-pro }
  { monthly-price: u20000000, yearly-price: u200000000 } ;; 20 STX monthly, 200 STX yearly
)

;; Get subscription price
(define-read-only (get-subscription-price (tier uint) (is-yearly bool))
  (match (map-get? subscription-prices { tier: tier })
    price-data (if is-yearly
                  (ok (get yearly-price price-data))
                  (ok (get monthly-price price-data)))
    (err err-not-found)
  )
)

;; Subscribe to service
(define-public (subscribe (tier uint) (is-yearly bool) (auto-renew bool))
  (let (
    (duration (if is-yearly duration-yearly duration-monthly))
    (current-block block-height)
    (price (unwrap! (get-subscription-price tier is-yearly) (err err-not-found)))
  )
    (begin
      ;; Transfer payment
      (unwrap! (stx-transfer? price tx-sender contract-owner) (err err-insufficient-funds))
      
      ;; Update subscription
      (map-set user-subscriptions
        { user: tx-sender }
        {
          tier: tier,
          start-block: current-block,
          end-block: (+ current-block duration),
          auto-renew: auto-renew,
          payment-amount: price
        }
      )
      
      ;; Update revenue
      (var-set total-revenue (+ (var-get total-revenue) price))
      
      (ok true)
    )
  )
)

;; Renew subscription (for auto-renewal or manual renewal)
(define-public (renew-subscription)
  (match (map-get? user-subscriptions { user: tx-sender })
    subscription (let (
      (tier (get tier subscription))
      (current-end (get end-block subscription))
      (payment-amount (get payment-amount subscription))
      (is-yearly (>= payment-amount u50000000)) ;; Determine if yearly based on amount
      (duration (if is-yearly duration-yearly duration-monthly))
    )
      (begin
        ;; Transfer payment
        (unwrap! (stx-transfer? payment-amount tx-sender contract-owner) (err err-insufficient-funds))
        
        ;; Extend subscription
        (map-set user-subscriptions
          { user: tx-sender }
          (merge subscription { end-block: (+ current-end duration) })
        )
        
        ;; Update revenue
        (var-set total-revenue (+ (var-get total-revenue) payment-amount))
        
        (ok true)
      )
    )
    (err err-not-found)
  )
)

;; Cancel subscription (disable auto-renew)
(define-public (cancel-subscription)
  (match (map-get? user-subscriptions { user: tx-sender })
    subscription (begin
      (map-set user-subscriptions
        { user: tx-sender }
        (merge subscription { auto-renew: false })
      )
      (ok true)
    )
    (err err-not-found)
  )
)

;; Check if user has active subscription
(define-read-only (has-active-subscription (user principal))
  (match (map-get? user-subscriptions { user: user })
    subscription (ok (>= (get end-block subscription) block-height))
    (ok false)
  )
)

;; Get user subscription details
(define-read-only (get-user-subscription (user principal))
  (map-get? user-subscriptions { user: user })
)

;; Check content access
(define-read-only (can-access-content (user principal) (content-id (string-ascii 64)))
  (match (map-get? content-access { content-id: content-id })
    content (match (map-get? user-subscriptions { user: user })
      subscription (ok (and 
        (get active content)
        (>= (get tier subscription) (get required-tier content))
        (>= (get end-block subscription) block-height)
      ))
      (ok false)
    )
    (ok false)
  )
)

;; Add content (owner only)
(define-public (add-content (content-id (string-ascii 64)) (required-tier uint) (publisher principal))
  (if (is-eq tx-sender contract-owner)
    (if (<= required-tier tier-pro)
      (begin
        (map-set content-access
          { content-id: content-id }
          { required-tier: required-tier, publisher: publisher, active: true }
        )
        (ok true)
      )
      (err err-invalid-duration)
    )
    (err err-owner-only)
  )
)

;; Deactivate content (owner only)
(define-public (deactivate-content (content-id (string-ascii 64)))
  (if (is-eq tx-sender contract-owner)
    (match (map-get? content-access { content-id: content-id })
      content (begin
        (map-set content-access
          { content-id: content-id }
          (merge content { active: false })
        )
        (ok true)
      )
      (err err-not-found)
    )
    (err err-owner-only)
  )
)

;; Update subscription prices (owner only)
(define-public (update-prices (tier uint) (monthly-price uint) (yearly-price uint))
  (if (is-eq tx-sender contract-owner)
    (begin
      (map-set subscription-prices
        { tier: tier }
        { monthly-price: monthly-price, yearly-price: yearly-price }
      )
      (ok true)
    )
    (err err-owner-only)
  )
)

;; Get total revenue
(define-read-only (get-total-revenue)
  (var-get total-revenue)
)

;; Emergency functions for expired auto-renew subscriptions
(define-public (process-auto-renewal (user principal))
  (match (map-get? user-subscriptions { user: user })
    subscription (if (and 
      (get auto-renew subscription)
      (< (get end-block subscription) block-height)
    )
      ;; This would typically integrate with an off-chain service
      ;; For now, it just marks the subscription as needing renewal
      (ok true)
      (ok false)
    )
    (err err-not-found)
  )
)

;; Withdraw revenue (owner only)
(define-public (withdraw-revenue (amount uint))
  (if (is-eq tx-sender contract-owner)
    (match (stx-transfer? amount (as-contract tx-sender) contract-owner)
      success (ok true)
      error (err err-insufficient-funds)
    )
    (err err-owner-only)
  )
)