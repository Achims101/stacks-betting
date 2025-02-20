;; Sports Betting Contract

;; Error Constants
(define-constant contract-administrator tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_DUPLICATE_EVENT (err u101))
(define-constant ERR_EVENT_NOT_FOUND (err u102))
(define-constant ERR_BETTING_CLOSED (err u103))
(define-constant ERR_BALANCE_TOO_LOW (err u104))
(define-constant ERR_EVENT_ALREADY_RESOLVED (err u105))
(define-constant ERR_PREMATURE_CLOSURE (err u106))
(define-constant ERR_PREMATURE_CANCELLATION (err u107))
(define-constant ERR_INSUFFICIENT_BETTING_OPTIONS (err u108))
(define-constant ERR_INVALID_END_BLOCK (err u109))
(define-constant ERR_UNSUPPORTED_BET_TYPE (err u110))
(define-constant ERR_ODDS_REQUIRED (err u111))
(define-constant ERR_INVALID_OPTION_SELECTION (err u112))
(define-constant ERR_EVENT_TIME_ELAPSED (err u113))
(define-constant ERR_NO_WINNERS_DECLARED (err u114))
(define-constant ERR_TOO_MANY_WINNERS (err u115))
(define-constant ERR_WINNER_SELECTION_INVALID (err u116))
(define-constant ERR_NOT_A_WINNING_BET (err u117))
(define-constant ERR_REFUND_FAILED (err u118))
(define-constant ERR_REFUND_PROCESSING (err u119))
(define-constant ERR_EMPTY_EVENT_DESCRIPTION (err u120))
(define-constant ERR_INVALID_BET_AMOUNT (err u121))

;; Data variables
(define-data-var event-counter uint u0)

;; Betting types
(define-data-var supported-bet-types (list 10 (string-ascii 20)) (list "winner-take-all" "proportional" "fixed-odds"))

;; Define betting event structure
(define-map sports-events
  { event-id: uint }
  {
    organizer-address: principal,
    event-details: (string-ascii 256),
    betting-options: (list 10 (string-ascii 64)),
    total-betting-pool: uint,
    bets-active: bool,
    winning-selections: (list 5 uint),
    event-end-block: uint,
    payout-mechanism: (string-ascii 20),
    option-odds: (optional (list 10 uint))
  }
)

;; Define participant stakes structure
(define-map bettor-positions
  { event-id: uint, bettor-address: principal }
  { chosen-option: uint, bet-amount: uint }
)

;; Read-only functions

(define-read-only (get-event-details (event-id uint))
  (map-get? sports-events { event-id: event-id })
)

(define-read-only (get-bettor-position (event-id uint) (bettor-address principal))
  (map-get? bettor-positions { event-id: event-id, bettor-address: bettor-address })
)

(define-read-only (get-current-block-height)
  block-height
)

;; Private functions

(define-private (calculate-payout (event-data { organizer-address: principal, event-details: (string-ascii 256), betting-options: (list 10 (string-ascii 64)), total-betting-pool: uint, bets-active: bool, winning-selections: (list 5 uint), event-end-block: uint, payout-mechanism: (string-ascii 20), option-odds: (optional (list 10 uint)) }) (bettor-data { chosen-option: uint, bet-amount: uint }) (winning-options (list 5 uint)))
  (let
    (
      (payout-type (get payout-mechanism event-data))
      (total-pool (get total-betting-pool event-data))
      (stake-amount (get bet-amount bettor-data))
    )
    (if (is-eq payout-type "winner-take-all")
      ;; For winner-take-all, divide total pot by number of winning options
      (/ total-pool (len winning-options))
      (if (is-eq payout-type "proportional")
        ;; For proportional, payout based on stake ratio
        (/ (* stake-amount total-pool) total-pool)
        ;; Fixed-odds payout
        (let
          (
            (odds-list (unwrap! (get option-odds event-data) u0))
            (selected-odds (unwrap! (element-at odds-list (- (get chosen-option bettor-data) u1)) u0))
          )
          (+ stake-amount (* stake-amount (/ selected-odds u100)))
        )
      )
    )
  )
)

(define-private (get-option-stake-amount (option-id uint) (event-id uint))
  (let
    (
      (bettor-position (get-bettor-position event-id tx-sender))
    )
    (if (is-some bettor-position)
      (let
        ((position-details (unwrap! bettor-position u0)))
        (if (is-eq (get chosen-option position-details) option-id)
          (get bet-amount position-details)
          u0
        )
      )
      u0
    )
  )
)

(define-private (get-total-option-stakes (option-id uint))
  (get-option-stake-amount option-id (var-get event-counter))
)

(define-private (process-bet-refunds (event-id uint))
  (let
    ((bettor-position (get-bettor-position event-id tx-sender)))
    (match bettor-position
      position-details (match (as-contract (stx-transfer? (get bet-amount position-details) tx-sender tx-sender))
        success (begin
          (map-delete bettor-positions { event-id: event-id, bettor-address: tx-sender })
          (ok true)
        )
        error ERR_REFUND_FAILED
      )
      ERR_REFUND_PROCESSING
    )
  )
)

(define-private (validate-winner-selections (options (list 5 uint)) (max-valid-option uint))
  (let
    (
      (first-winner (element-at options u0))
      (second-winner (element-at options u1))
      (third-winner (element-at options u2))
      (fourth-winner (element-at options u3))
      (fifth-winner (element-at options u4))
    )
    (and
      ;; Check if first option exists and is valid
      (match first-winner
        value (and (> value u0) (<= value max-valid-option))
        true)
      ;; For remaining options, they're either valid or none
      (match second-winner
        value (and (> value u0) (<= value max-valid-option))
        true)
      (match third-winner
        value (and (> value u0) (<= value max-valid-option))
        true)
      (match fourth-winner
        value (and (> value u0) (<= value max-valid-option))
        true)
      (match fifth-winner
        value (and (> value u0) (<= value max-valid-option))
        true)
    )
  )
)

;; Public functions

(define-public (create-event (event-details (string-ascii 256)) (betting-options (list 10 (string-ascii 64))) (event-end-block uint) (payout-mechanism (string-ascii 20)) (option-odds (optional (list 10 uint))))
  (let
    (
      (new-event-id (var-get event-counter))
    )
    (asserts! (> (len event-details) u0) ERR_EMPTY_EVENT_DESCRIPTION)
    (asserts! (> (len betting-options) u1) ERR_INSUFFICIENT_BETTING_OPTIONS)
    (asserts! (> event-end-block block-height) ERR_INVALID_END_BLOCK)
    (asserts! (is-some (index-of (var-get supported-bet-types) payout-mechanism)) ERR_UNSUPPORTED_BET_TYPE)
    (asserts! (or (is-eq payout-mechanism "winner-take-all") (is-eq payout-mechanism "proportional") (is-some option-odds)) ERR_ODDS_REQUIRED)
    (map-set sports-events
      { event-id: new-event-id }
      {
        organizer-address: tx-sender,
        event-details: event-details,
        betting-options: betting-options,
        total-betting-pool: u0,
        bets-active: true,
        winning-selections: (list),
        event-end-block: event-end-block,
        payout-mechanism: payout-mechanism,
        option-odds: option-odds
      }
    )
    (var-set event-counter (+ new-event-id u1))
    (ok new-event-id)
  )
)

(define-public (place-bet (event-id uint) (chosen-option uint) (bet-amount uint))
  (let
    (
      (event-data (unwrap! (get-event-details event-id) ERR_EVENT_NOT_FOUND))
      (existing-position (default-to { chosen-option: u0, bet-amount: u0 } (get-bettor-position event-id tx-sender)))
    )
    (asserts! (> bet-amount u0) ERR_INVALID_BET_AMOUNT)
    (asserts! (get bets-active event-data) ERR_BETTING_CLOSED)
    (asserts! (>= (len (get betting-options event-data)) chosen-option) ERR_INVALID_OPTION_SELECTION)
    (asserts! (< block-height (get event-end-block event-data)) ERR_EVENT_TIME_ELAPSED)
    (try! (stx-transfer? bet-amount tx-sender (as-contract tx-sender)))
    (map-set bettor-positions
      { event-id: event-id, bettor-address: tx-sender }
      {
        chosen-option: chosen-option,
        bet-amount: (+ bet-amount (get bet-amount existing-position))
      }
    )
    (map-set sports-events
      { event-id: event-id }
      (merge event-data { total-betting-pool: (+ (get total-betting-pool event-data) bet-amount) })
    )
    (ok true)
  )
)

(define-public (close-event (event-id uint))
  (let
    (
      (event-data (unwrap! (get-event-details event-id) ERR_EVENT_NOT_FOUND))
    )
    (asserts! (or (is-eq (get organizer-address event-data) tx-sender) (is-eq contract-administrator tx-sender)) ERR_NOT_AUTHORIZED)
    (asserts! (get bets-active event-data) ERR_BETTING_CLOSED)
    (asserts! (>= block-height (get event-end-block event-data)) ERR_PREMATURE_CLOSURE)
    (map-set sports-events
      { event-id: event-id }
      (merge event-data { bets-active: false })
    )
    (ok true)
  )
)

(define-public (cancel-event (event-id uint))
  (let
    (
      (event-data (unwrap! (get-event-details event-id) ERR_EVENT_NOT_FOUND))
    )
    (asserts! (is-eq (get organizer-address event-data) tx-sender) ERR_NOT_AUTHORIZED)
    (asserts! (get bets-active event-data) ERR_BETTING_CLOSED)
    (asserts! (< block-height (get event-end-block event-data)) ERR_PREMATURE_CANCELLATION)
    
    ;; First set the event as closed
    (map-set sports-events
      { event-id: event-id }
      (merge event-data { bets-active: false })
    )
    
    ;; Then process refunds
    (process-bet-refunds event-id)
  )
)

(define-public (claim-winnings (event-id uint))
  (let
    (
      (event-data (unwrap! (get-event-details event-id) ERR_EVENT_NOT_FOUND))
      (bettor-position (unwrap! (get-bettor-position event-id tx-sender) ERR_EVENT_NOT_FOUND))
      (winning-selections (get winning-selections event-data))
    )
    (asserts! (is-some (index-of winning-selections (get chosen-option bettor-position))) ERR_NOT_A_WINNING_BET)
    (let
      (
        (payout-amount (calculate-payout event-data bettor-position winning-selections))
      )
      (try! (as-contract (stx-transfer? payout-amount tx-sender tx-sender)))
      (map-delete bettor-positions { event-id: event-id, bettor-address: tx-sender })
      (ok payout-amount)
    )
  )
)

(define-public (resolve-event (event-id uint) (winning-selections (list 5 uint)))
  (let
    (
      (event-data (unwrap! (get-event-details event-id) ERR_EVENT_NOT_FOUND))
    )
    (asserts! (is-eq contract-administrator tx-sender) ERR_NOT_AUTHORIZED)
    (asserts! (not (get bets-active event-data)) ERR_BETTING_CLOSED)
    (asserts! (is-eq (len (get winning-selections event-data)) u0) ERR_EVENT_ALREADY_RESOLVED)
    (asserts! (> (len winning-selections) u0) ERR_NO_WINNERS_DECLARED)
    (asserts! (<= (len winning-selections) u5) ERR_TOO_MANY_WINNERS)
    
    ;; Validate each winning option
    (asserts! (validate-winner-selections winning-selections (len (get betting-options event-data))) ERR_WINNER_SELECTION_INVALID)
    
    (map-set sports-events
      { event-id: event-id }
      (merge event-data { winning-selections: winning-selections })
    )
    (ok true)
  )
)

;; Contract initialization
(begin
  (var-set event-counter u0)
)

;; Export the Component function
(define-public (Component)
  (ok true))