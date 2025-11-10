;; Fractional Real Estate Ownership Platform
;; Smart contract for tokenized real estate with governance and income distribution

;; <CHANGE> Renamed error constants to consistent error-* format
(define-constant error-access-denied (err u100))
(define-constant error-not-found (err u101))
(define-constant error-invalid-params (err u102))
(define-constant error-inactive (err u103))
(define-constant error-insufficient-balance (err u104))
(define-constant error-no-revenue (err u105))
(define-constant error-voting-ended (err u106))
(define-constant error-voting-active (err u107))
(define-constant error-failed (err u108))
(define-constant error-already-executed (err u109))

;; <CHANGE> Renamed contract owner constant
(define-constant contract-owner tx-sender)

;; <CHANGE> Renamed property registry and field names
(define-map property-registry
  { property-id: uint }
  {
    property-name: (string-utf8 128),
    property-location: (string-utf8 128),
    total-token-supply: uint,
    token-price-per-unit: uint,
    is-active: bool,
    property-administrator: principal,
    creation-block-height: uint
  }
)

;; <CHANGE> Renamed balance registry
(define-map balance-registry
  { property-id: uint, token-holder: principal }
  { token-balance: uint }
)

;; <CHANGE> Renamed supply registry
(define-map supply-registry
  { property-id: uint }
  { total-issued-tokens: uint }
)

;; <CHANGE> Renamed revenue registry
(define-map revenue-registry
  { property-id: uint }
  {
    accumulated-revenue: uint,
    revenue-distribution-per-token: uint,
    last-revenue-update: uint
  }
)

;; <CHANGE> Renamed claim registry
(define-map claim-registry
  { property-id: uint, revenue-claimant: principal }
  {
    claimed-revenue-per-token: uint,
    last-claim-block-height: uint
  }
)

;; <CHANGE> Renamed proposal registry
(define-map proposal-registry
  { property-id: uint, proposal-id: uint }
  {
    proposal-title: (string-utf8 128),
    proposal-description: (string-utf8 256),
    proposal-creator: principal,
    voting-start-block: uint,
    voting-end-block: uint,
    affirmative-vote-count: uint,
    negative-vote-count: uint,
    is-proposal-executed: bool,
    proposal-category: (string-ascii 32)
  }
)

;; <CHANGE> Renamed voting registry
(define-map voting-registry
  { property-id: uint, proposal-id: uint, voter-principal: principal }
  { vote-support: bool, vote-weight: uint }
)

;; <CHANGE> Renamed ID counters
(define-data-var next-property-id uint u1)
(define-map proposal-id-registry { property-id: uint } { next-proposal-id: uint })

;; Helper: Check if caller is contract admin
(define-private (check-admin)
  (is-eq tx-sender contract-owner)
)

;; Helper: Check if caller is property admin
(define-private (check-property-owner (property-id uint))
  (match (map-get? property-registry { property-id: property-id })
    property-data (is-eq tx-sender (get property-administrator property-data))
    false
  )
)

;; Helper: Get property safely
(define-private (get-property-data (property-id uint))
  (ok (unwrap! (map-get? property-registry { property-id: property-id }) error-not-found))
)

;; Helper: Get token balance
(define-private (fetch-token-balance (property-id uint) (account-principal principal))
  (default-to u0 
    (get token-balance (map-get? balance-registry { property-id: property-id, token-holder: account-principal }))
  )
)

;; Create a new tokenized property
(define-public (create-property 
                (property-name (string-utf8 128))
                (property-location (string-utf8 128))
                (total-token-supply uint)
                (token-price-per-unit uint))
  (let ((new-property-id (var-get next-property-id)))
    ;; Input validation
    (asserts! (check-admin) error-access-denied)
    (asserts! (> total-token-supply u0) error-invalid-params)
    (asserts! (> token-price-per-unit u0) error-invalid-params)
    (asserts! (> (len property-name) u0) error-invalid-params)
    (asserts! (> (len property-location) u0) error-invalid-params)
    
    ;; Register property
    (map-set property-registry
      { property-id: new-property-id }
      {
        property-name: property-name,
        property-location: property-location,
        total-token-supply: total-token-supply,
        token-price-per-unit: token-price-per-unit,
        is-active: true,
        property-administrator: tx-sender,
        creation-block-height: block-height
      }
    )
    
    ;; Initialize related data
    (map-set supply-registry { property-id: new-property-id } { total-issued-tokens: u0 })
    (map-set revenue-registry 
      { property-id: new-property-id } 
      { accumulated-revenue: u0, revenue-distribution-per-token: u0, last-revenue-update: u0 }
    )
    (map-set proposal-id-registry { property-id: new-property-id } { next-proposal-id: u0 })
    
    ;; Update counter
    (var-set next-property-id (+ new-property-id u1))
    (ok new-property-id)
  )
)

;; Purchase property tokens
(define-public (buy-tokens (property-id uint) (token-quantity uint))
  (let (
    (property-data (try! (get-property-data property-id)))
    (total-purchase-cost (* token-quantity (get token-price-per-unit property-data)))
    (current-issued-tokens (get total-issued-tokens (unwrap! (map-get? supply-registry { property-id: property-id }) error-not-found)))
    (buyer-current-balance (fetch-token-balance property-id tx-sender))
  )
    ;; Validation checks
    (asserts! (get is-active property-data) error-inactive)
    (asserts! (> token-quantity u0) error-invalid-params)
    (asserts! (<= (+ current-issued-tokens token-quantity) (get total-token-supply property-data)) error-insufficient-balance)
    
    ;; Process payment
    (try! (stx-transfer? total-purchase-cost tx-sender (as-contract tx-sender)))
    
    ;; Update token balance
    (map-set balance-registry
      { property-id: property-id, token-holder: tx-sender }
      { token-balance: (+ buyer-current-balance token-quantity) }
    )
    
    ;; Update supply counter
    (map-set supply-registry
      { property-id: property-id }
      { total-issued-tokens: (+ current-issued-tokens token-quantity) }
    )
    
    ;; Initialize claim tracking for new holders
    (if (is-eq buyer-current-balance u0)
      (map-set claim-registry
        { property-id: property-id, revenue-claimant: tx-sender }
        {
          claimed-revenue-per-token: (get revenue-distribution-per-token (unwrap-panic (map-get? revenue-registry { property-id: property-id }))),
          last-claim-block-height: block-height
        }
      )
      true
    )
    
    (ok token-quantity)
  )
)

;; Add revenue to property pool
(define-public (add-revenue (property-id uint) (revenue-amount uint))
  (let (
    (property-data (try! (get-property-data property-id)))
    (revenue-pool-data (unwrap! (map-get? revenue-registry { property-id: property-id }) error-not-found))
    (current-issued-tokens (get total-issued-tokens (unwrap! (map-get? supply-registry { property-id: property-id }) error-not-found)))
    (revenue-per-token-increment (if (> current-issued-tokens u0) (/ revenue-amount current-issued-tokens) u0))
  )
    ;; Authorization and validation
    (asserts! (get is-active property-data) error-inactive)
    (asserts! (check-property-owner property-id) error-access-denied)
    (asserts! (> revenue-amount u0) error-invalid-params)
    
    ;; Transfer revenue to contract
    (try! (stx-transfer? revenue-amount tx-sender (as-contract tx-sender)))
    
    ;; Update revenue pool
    (map-set revenue-registry
      { property-id: property-id }
      {
        accumulated-revenue: (+ (get accumulated-revenue revenue-pool-data) revenue-amount),
        revenue-distribution-per-token: (+ (get revenue-distribution-per-token revenue-pool-data) revenue-per-token-increment),
        last-revenue-update: block-height
      }
    )
    
    (ok revenue-amount)
  )
)

;; Claim accumulated revenue
(define-public (claim-revenue (property-id uint))
  (let (
    (property-data (try! (get-property-data property-id)))
    (revenue-pool-data (unwrap! (map-get? revenue-registry { property-id: property-id }) error-not-found))
    (holder-token-balance (fetch-token-balance property-id tx-sender))
    (claimant-record (default-to 
      { claimed-revenue-per-token: u0, last-claim-block-height: u0 }
      (map-get? claim-registry { property-id: property-id, revenue-claimant: tx-sender })
    ))
    (unclaimed-revenue-per-token (- (get revenue-distribution-per-token revenue-pool-data) (get claimed-revenue-per-token claimant-record)))
    (total-withdrawal-amount (* holder-token-balance unclaimed-revenue-per-token))
  )
    ;; Validation
    (asserts! (get is-active property-data) error-inactive)
    (asserts! (> holder-token-balance u0) error-insufficient-balance)
    (asserts! (> total-withdrawal-amount u0) error-no-revenue)
    
    ;; Update claim record
    (map-set claim-registry
      { property-id: property-id, revenue-claimant: tx-sender }
      {
        claimed-revenue-per-token: (get revenue-distribution-per-token revenue-pool-data),
        last-claim-block-height: block-height
      }
    )
    
    ;; Transfer revenue to claimer
    (try! (as-contract (stx-transfer? total-withdrawal-amount tx-sender tx-sender)))
    (ok total-withdrawal-amount)
  )
)

;; Submit governance proposal
(define-public (create-proposal
                (property-id uint)
                (proposal-title (string-utf8 128))
                (proposal-description (string-utf8 256))
                (voting-duration-blocks uint)
                (proposal-category (string-ascii 32)))
  (let (
    (property-data (try! (get-property-data property-id)))
    (proposer-token-balance (fetch-token-balance property-id tx-sender))
    (minimum-proposal-tokens (/ (get total-token-supply property-data) u20)) ;; 5% requirement
    (proposal-counter-data (unwrap! (map-get? proposal-id-registry { property-id: property-id }) error-not-found))
    (new-proposal-id (get next-proposal-id proposal-counter-data))
  )
    ;; Validation
    (asserts! (get is-active property-data) error-inactive)
    (asserts! (>= proposer-token-balance minimum-proposal-tokens) error-insufficient-balance)
    (asserts! (> voting-duration-blocks u0) error-invalid-params)
    (asserts! (> (len proposal-title) u0) error-invalid-params)
    
    ;; Create proposal
    (map-set proposal-registry
      { property-id: property-id, proposal-id: new-proposal-id }
      {
        proposal-title: proposal-title,
        proposal-description: proposal-description,
        proposal-creator: tx-sender,
        voting-start-block: block-height,
        voting-end-block: (+ block-height voting-duration-blocks),
        affirmative-vote-count: u0,
        negative-vote-count: u0,
        is-proposal-executed: false,
        proposal-category: proposal-category
      }
    )
    
    ;; Update counter
    (map-set proposal-id-registry { property-id: property-id } { next-proposal-id: (+ new-proposal-id u1) })
    (ok new-proposal-id)
  )
)

;; Cast vote on proposal
(define-public (cast-vote (property-id uint) (proposal-id uint) (vote-support bool))
  (let (
    (property-data (try! (get-property-data property-id)))
    (proposal-data (unwrap! (map-get? proposal-registry { property-id: property-id, proposal-id: proposal-id }) error-not-found))
    (voter-token-balance (fetch-token-balance property-id tx-sender))
    (voter-previous-vote (map-get? voting-registry { property-id: property-id, proposal-id: proposal-id, voter-principal: tx-sender }))
  )
    ;; Validation
    (asserts! (get is-active property-data) error-inactive)
    (asserts! (> voter-token-balance u0) error-insufficient-balance)
    (asserts! (< block-height (get voting-end-block proposal-data)) error-voting-ended)
    (asserts! (not (get is-proposal-executed proposal-data)) error-already-executed)
    
    ;; Remove previous vote if exists
    (match voter-previous-vote
      old-vote-data 
        (map-set proposal-registry
          { property-id: property-id, proposal-id: proposal-id }
          (if (get vote-support old-vote-data)
            (merge proposal-data { affirmative-vote-count: (- (get affirmative-vote-count proposal-data) (get vote-weight old-vote-data)) })
            (merge proposal-data { negative-vote-count: (- (get negative-vote-count proposal-data) (get vote-weight old-vote-data)) })
          )
        )
      true
    )
    
    ;; Record new vote
    (map-set voting-registry
      { property-id: property-id, proposal-id: proposal-id, voter-principal: tx-sender }
      { vote-support: vote-support, vote-weight: voter-token-balance }
    )
    
    ;; Update proposal tallies
    (map-set proposal-registry
      { property-id: property-id, proposal-id: proposal-id }
      (if vote-support
        (merge proposal-data { affirmative-vote-count: (+ (get affirmative-vote-count proposal-data) voter-token-balance) })
        (merge proposal-data { negative-vote-count: (+ (get negative-vote-count proposal-data) voter-token-balance) })
      )
    )
    
    (ok true)
  )
)

;; Execute approved proposal
(define-public (finalize-proposal (property-id uint) (proposal-id uint))
  (let (
    (property-data (try! (get-property-data property-id)))
    (proposal-data (unwrap! (map-get? proposal-registry { property-id: property-id, proposal-id: proposal-id }) error-not-found))
    (total-cast-votes (+ (get affirmative-vote-count proposal-data) (get negative-vote-count proposal-data)))
    (quorum-minimum-votes (/ (get total-token-supply property-data) u10)) ;; 10% quorum
  )
    ;; Validation
    (asserts! (get is-active property-data) error-inactive)
    (asserts! (>= block-height (get voting-end-block proposal-data)) error-voting-active)
    (asserts! (not (get is-proposal-executed proposal-data)) error-already-executed)
    (asserts! (>= total-cast-votes quorum-minimum-votes) error-failed)
    (asserts! (> (get affirmative-vote-count proposal-data) (get negative-vote-count proposal-data)) error-failed)
    
    ;; Mark as executed
    (map-set proposal-registry
      { property-id: property-id, proposal-id: proposal-id }
      (merge proposal-data { is-proposal-executed: true })
    )
    
    (ok true)
  )
)

;; Read-only: Get property information
(define-read-only (fetch-property (property-id uint))
  (map-get? property-registry { property-id: property-id })
)

;; Read-only: Get token balance
(define-read-only (fetch-token-balance-info (property-id uint) (account-principal principal))
  (fetch-token-balance property-id account-principal)
)

;; Read-only: Get proposal details
(define-read-only (fetch-proposal (property-id uint) (proposal-id uint))
  (map-get? proposal-registry { property-id: property-id, proposal-id: proposal-id })
)

;; Read-only: Calculate claimable revenue
(define-read-only (get-claimable-revenue (property-id uint) (account-principal principal))
  (match (map-get? revenue-registry { property-id: property-id })
    revenue-pool-data
      (let (
        (account-token-balance (fetch-token-balance property-id account-principal))
        (claimant-record (default-to 
          { claimed-revenue-per-token: u0, last-claim-block-height: u0 }
          (map-get? claim-registry { property-id: property-id, revenue-claimant: account-principal })
        ))
        (unclaimed-revenue-per-token (- (get revenue-distribution-per-token revenue-pool-data) (get claimed-revenue-per-token claimant-record)))
      )
        (* account-token-balance unclaimed-revenue-per-token)
      )
    u0
  )
)

;; Read-only: Get total properties count
(define-read-only (fetch-total-properties)
  (- (var-get next-property-id) u1)
)