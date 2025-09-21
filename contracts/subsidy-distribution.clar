;; Subsidy Distribution Contract - Farm Subsidy Tokens System
;; Manages transparent distribution of agricultural subsidies and aid tokens
;; to verified farmers based on eligibility criteria and land characteristics

;; Error Constants
(define-constant ERR_UNAUTHORIZED (err u200))
(define-constant ERR_FARMER_NOT_FOUND (err u201))
(define-constant ERR_FARMER_NOT_VERIFIED (err u202))
(define-constant ERR_INSUFFICIENT_FUNDS (err u203))
(define-constant ERR_INVALID_AMOUNT (err u204))
(define-constant ERR_DISTRIBUTION_PAUSED (err u205))
(define-constant ERR_ALREADY_DISTRIBUTED (err u206))
(define-constant ERR_INVALID_PERIOD (err u207))
(define-constant ERR_MAX_SUBSIDY_EXCEEDED (err u208))
(define-constant ERR_DISTRIBUTOR_NOT_AUTHORIZED (err u209))
(define-constant ERR_INVALID_CROP_TYPE (err u210))
(define-constant ERR_INVALID_LOCATION (err u211))

;; Contract Owner and Admin
(define-constant CONTRACT_OWNER tx-sender)

;; Farmer Registry Contract Reference
(define-constant FARMER_REGISTRY_CONTRACT .farmer-registry)

;; Distribution Period Constants (in blocks)
(define-constant DISTRIBUTION_PERIOD u144) ;; Approximately 1 day in blocks
(define-constant SEASON_BLOCKS u52560)     ;; Approximately 1 year in blocks

;; Subsidy Calculation Constants
(define-constant BASE_SUBSIDY_PER_ACRE u100000000) ;; 100 STX per acre base rate
(define-constant MAX_SUBSIDY_PER_FARMER u100000000000) ;; 100,000 STX max per farmer per season
(define-constant MIN_SUBSIDY_AMOUNT u1000000) ;; 1 STX minimum

;; Crop Type Multipliers (scaled by 100 for precision)
(define-constant CROP_MULTIPLIER_WHEAT u110)     ;; 1.1x
(define-constant CROP_MULTIPLIER_CORN u120)      ;; 1.2x
(define-constant CROP_MULTIPLIER_RICE u115)      ;; 1.15x
(define-constant CROP_MULTIPLIER_SOYBEANS u105)  ;; 1.05x
(define-constant CROP_MULTIPLIER_DEFAULT u100)   ;; 1.0x

;; Data Variables
(define-data-var total-distributed uint u0)
(define-data-var distribution-paused bool false)
(define-data-var current-season uint u1)
(define-data-var season-budget uint u1000000000000) ;; 1 million STX per season
(define-data-var season-distributed uint u0)
(define-data-var next-distribution-id uint u1)

;; Distribution Records
(define-map distributions
  { distribution-id: uint }
  {
    farmer-address: principal,
    amount: uint,
    distribution-date: uint,
    season: uint,
    calculation-basis: {
      land-size: uint,
      crop-type: (string-ascii 20),
      base-rate: uint,
      multiplier: uint,
      location-adjustment: uint
    },
    distributed-by: principal,
    status: uint
  }
)

;; Farmer Season Distribution Tracking
(define-map farmer-season-distributions
  { farmer-address: principal, season: uint }
  {
    total-received: uint,
    distribution-count: uint,
    last-distribution-date: uint,
    distributions: (list 10 uint)
  }
)

;; Authorized Distributors
(define-map authorized-distributors
  { distributor: principal }
  {
    authorized: bool,
    authorized-by: principal,
    authorized-at: uint,
    distributions-made: uint,
    total-distributed: uint
  }
)

;; Season Statistics
(define-map season-stats
  { season: uint }
  {
    total-distributed: uint,
    farmers-benefited: uint,
    distributions-made: uint,
    average-distribution: uint,
    start-block: uint,
    end-block: (optional uint)
  }
)

;; Location-based Adjustments
(define-map location-adjustments
  { location: (string-ascii 30) }
  {
    adjustment-factor: uint, ;; Percentage adjustment (100 = no change)
    priority-level: uint,
    updated-by: principal,
    updated-at: uint
  }
)

;; Public Functions

;; Distribute subsidy to an eligible farmer
(define-public (distribute-subsidy (farmer-address principal) (custom-amount (optional uint)))
  (let
    (
      (distributor-data (unwrap! (map-get? authorized-distributors { distributor: tx-sender }) ERR_UNAUTHORIZED))
      (farmer-eligibility (contract-call? FARMER_REGISTRY_CONTRACT get-farmer-eligibility farmer-address))
      (current-block stacks-block-height)
      (season (get-current-season))
      (distribution-id (var-get next-distribution-id))
    )
    ;; Validate authorization and system status
    (asserts! (get authorized distributor-data) ERR_UNAUTHORIZED)
    (asserts! (not (var-get distribution-paused)) ERR_DISTRIBUTION_PAUSED)
    (asserts! (get eligible farmer-eligibility) ERR_FARMER_NOT_VERIFIED)
    
    ;; Calculate subsidy amount
    (let
      (
        (calculated-amount (calculate-subsidy-amount farmer-eligibility))
        (final-amount (default-to calculated-amount custom-amount))
        (farmer-season-data (get-farmer-season-data farmer-address season))
        (new-total (+ (get total-received farmer-season-data) final-amount))
      )
      ;; Validate amount and limits
      (asserts! (>= final-amount MIN_SUBSIDY_AMOUNT) ERR_INVALID_AMOUNT)
      (asserts! (<= new-total MAX_SUBSIDY_PER_FARMER) ERR_MAX_SUBSIDY_EXCEEDED)
      (asserts! (<= (+ (var-get season-distributed) final-amount) (var-get season-budget)) ERR_INSUFFICIENT_FUNDS)
      
      ;; Transfer subsidy tokens to farmer
      (try! (stx-transfer? final-amount (as-contract tx-sender) farmer-address))
      
      ;; Record distribution
      (map-set distributions
        { distribution-id: distribution-id }
        {
          farmer-address: farmer-address,
          amount: final-amount,
          distribution-date: current-block,
          season: season,
          calculation-basis: (get-calculation-basis farmer-eligibility final-amount),
          distributed-by: tx-sender,
          status: u1 ;; Completed
        }
      )
      
      ;; Update farmer season tracking
      (update-farmer-season-data farmer-address season final-amount distribution-id)
      
      ;; Update distributor statistics
      (map-set authorized-distributors
        { distributor: tx-sender }
        (merge distributor-data
          {
            distributions-made: (+ (get distributions-made distributor-data) u1),
            total-distributed: (+ (get total-distributed distributor-data) final-amount)
          }
        )
      )
      
      ;; Update global statistics
      (var-set total-distributed (+ (var-get total-distributed) final-amount))
      (var-set season-distributed (+ (var-get season-distributed) final-amount))
      (var-set next-distribution-id (+ distribution-id u1))
      
      ;; Update season statistics
      (update-season-stats season final-amount)
      
      ;; Update farmer registry with subsidy received
      (try! (contract-call? FARMER_REGISTRY_CONTRACT update-subsidy-received farmer-address final-amount))
      
      (ok distribution-id)
    )
  )
)

;; Add authorized distributor (contract owner only)
(define-public (add-authorized-distributor (distributor principal))
  (let
    (
      (current-block stacks-block-height)
    )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    
    (map-set authorized-distributors
      { distributor: distributor }
      {
        authorized: true,
        authorized-by: tx-sender,
        authorized-at: current-block,
        distributions-made: u0,
        total-distributed: u0
      }
    )
    
    (ok true)
  )
)

;; Remove authorized distributor (contract owner only)
(define-public (remove-authorized-distributor (distributor principal))
  (let
    (
      (distributor-data (unwrap! (map-get? authorized-distributors { distributor: distributor }) ERR_FARMER_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    
    (map-set authorized-distributors
      { distributor: distributor }
      (merge distributor-data { authorized: false })
    )
    
    (ok true)
  )
)

;; Set location adjustment (contract owner only)
(define-public (set-location-adjustment (location (string-ascii 30)) (adjustment-factor uint) (priority-level uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (and (>= adjustment-factor u50) (<= adjustment-factor u200)) ERR_INVALID_AMOUNT) ;; 50% to 200%
    
    (map-set location-adjustments
      { location: location }
      {
        adjustment-factor: adjustment-factor,
        priority-level: priority-level,
        updated-by: tx-sender,
        updated-at: stacks-block-height
      }
    )
    
    (ok true)
  )
)

;; Toggle distribution pause (contract owner only)
(define-public (toggle-distribution-pause (paused bool))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set distribution-paused paused)
    (ok paused)
  )
)

;; Start new season (contract owner only)
(define-public (start-new-season (budget uint))
  (let
    (
      (current-season-num (var-get current-season))
      (current-block stacks-block-height)
    )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    
    ;; Close current season statistics
    (let
      (
        (current-season-stats (unwrap-panic (map-get? season-stats { season: current-season-num })))
      )
      (map-set season-stats
        { season: current-season-num }
        (merge current-season-stats { end-block: (some current-block) })
      )
    )
    
    ;; Initialize new season
    (let
      (
        (new-season (+ current-season-num u1))
      )
      (var-set current-season new-season)
      (var-set season-budget budget)
      (var-set season-distributed u0)
      
      (map-set season-stats
        { season: new-season }
        {
          total-distributed: u0,
          farmers-benefited: u0,
          distributions-made: u0,
          average-distribution: u0,
          start-block: current-block,
          end-block: none
        }
      )
      
      (ok new-season)
    )
  )
)

;; Private Functions

;; Calculate subsidy amount based on farmer characteristics
(define-private (calculate-subsidy-amount (farmer-eligibility (tuple (eligible bool) (farmer-id uint) (land-size uint) (crop-type (string-ascii 20)) (location (string-ascii 30)))))
  (let
    (
      (land-size (get land-size farmer-eligibility))
      (crop-type (get crop-type farmer-eligibility))
      (location (get location farmer-eligibility))
      (base-amount (* land-size BASE_SUBSIDY_PER_ACRE))
      (crop-multiplier (get-crop-multiplier crop-type))
      (location-adjustment (get-location-adjustment location))
    )
    ;; Calculate final amount with multipliers
    (let
      (
        (crop-adjusted (* base-amount crop-multiplier))
        (location-adjusted (* crop-adjusted location-adjustment))
        (final-amount (/ location-adjusted u10000)) ;; Divide by 10000 to account for multiplier scaling
      )
      (if (> final-amount MAX_SUBSIDY_PER_FARMER)
        MAX_SUBSIDY_PER_FARMER
        (if (< final-amount MIN_SUBSIDY_AMOUNT)
          MIN_SUBSIDY_AMOUNT
          final-amount
        )
      )
    )
  )
)

;; Get crop multiplier based on crop type
(define-private (get-crop-multiplier (crop-type (string-ascii 20)))
  (if (is-eq crop-type "Wheat")
    CROP_MULTIPLIER_WHEAT
    (if (is-eq crop-type "Corn")
      CROP_MULTIPLIER_CORN
      (if (is-eq crop-type "Rice")
        CROP_MULTIPLIER_RICE
        (if (is-eq crop-type "Soybeans")
          CROP_MULTIPLIER_SOYBEANS
          CROP_MULTIPLIER_DEFAULT
        )
      )
    )
  )
)

;; Get location adjustment factor
(define-private (get-location-adjustment (location (string-ascii 30)))
  (match (map-get? location-adjustments { location: location })
    adjustment-data (get adjustment-factor adjustment-data)
    u100 ;; Default 100% (no adjustment)
  )
)

;; Get calculation basis for record keeping
(define-private (get-calculation-basis (farmer-eligibility (tuple (eligible bool) (farmer-id uint) (land-size uint) (crop-type (string-ascii 20)) (location (string-ascii 30)))) (amount uint))
  {
    land-size: (get land-size farmer-eligibility),
    crop-type: (get crop-type farmer-eligibility),
    base-rate: BASE_SUBSIDY_PER_ACRE,
    multiplier: (get-crop-multiplier (get crop-type farmer-eligibility)),
    location-adjustment: (get-location-adjustment (get location farmer-eligibility))
  }
)

;; Get farmer season data
(define-private (get-farmer-season-data (farmer-address principal) (season uint))
  (default-to
    { total-received: u0, distribution-count: u0, last-distribution-date: u0, distributions: (list) }
    (map-get? farmer-season-distributions { farmer-address: farmer-address, season: season })
  )
)

;; Update farmer season data
(define-private (update-farmer-season-data (farmer-address principal) (season uint) (amount uint) (distribution-id uint))
  (let
    (
      (current-data (get-farmer-season-data farmer-address season))
      (new-distributions (unwrap-panic (as-max-len? (append (get distributions current-data) distribution-id) u10)))
    )
    (map-set farmer-season-distributions
      { farmer-address: farmer-address, season: season }
      {
        total-received: (+ (get total-received current-data) amount),
        distribution-count: (+ (get distribution-count current-data) u1),
        last-distribution-date: stacks-block-height,
        distributions: new-distributions
      }
    )
  )
)

;; Update season statistics
(define-private (update-season-stats (season uint) (amount uint))
  (let
    (
      (current-stats (default-to
        { total-distributed: u0, farmers-benefited: u0, distributions-made: u0, average-distribution: u0, start-block: stacks-block-height, end-block: none }
        (map-get? season-stats { season: season })
      ))
      (new-total (+ (get total-distributed current-stats) amount))
      (new-count (+ (get distributions-made current-stats) u1))
    )
    (map-set season-stats
      { season: season }
      (merge current-stats
        {
          total-distributed: new-total,
          distributions-made: new-count,
          average-distribution: (/ new-total new-count)
        }
      )
    )
  )
)

;; Read-only Functions

;; Get current season
(define-read-only (get-current-season)
  (var-get current-season)
)

;; Get distribution information
(define-read-only (get-distribution (distribution-id uint))
  (map-get? distributions { distribution-id: distribution-id })
)

;; Get farmer season distributions
(define-read-only (get-farmer-season-distributions (farmer-address principal) (season uint))
  (map-get? farmer-season-distributions { farmer-address: farmer-address, season: season })
)

;; Check if distributor is authorized
(define-read-only (is-authorized-distributor (distributor principal))
  (match (map-get? authorized-distributors { distributor: distributor })
    distributor-data (get authorized distributor-data)
    false
  )
)

;; Get season statistics
(define-read-only (get-season-stats (season uint))
  (map-get? season-stats { season: season })
)

;; Get total distributed amount
(define-read-only (get-total-distributed)
  (var-get total-distributed)
)

;; Check if distribution is paused
(define-read-only (is-distribution-paused)
  (var-get distribution-paused)
)

;; Get location adjustment
(define-read-only (get-location-adjustment-info (location (string-ascii 30)))
  (map-get? location-adjustments { location: location })
)

;; Get distributor information
(define-read-only (get-distributor-info (distributor principal))
  (map-get? authorized-distributors { distributor: distributor })
)

;; Get subsidy calculation multipliers and constants
(define-read-only (get-subsidy-calculation-info)
  {
    base-rate: BASE_SUBSIDY_PER_ACRE,
    min-amount: MIN_SUBSIDY_AMOUNT,
    max-amount: MAX_SUBSIDY_PER_FARMER,
    wheat-multiplier: CROP_MULTIPLIER_WHEAT,
    corn-multiplier: CROP_MULTIPLIER_CORN,
    rice-multiplier: CROP_MULTIPLIER_RICE,
    soybeans-multiplier: CROP_MULTIPLIER_SOYBEANS,
    default-multiplier: CROP_MULTIPLIER_DEFAULT
  }
)

;; Get season budget and remaining amount
(define-read-only (get-season-budget-info)
  {
    total-budget: (var-get season-budget),
    distributed: (var-get season-distributed),
    remaining: (- (var-get season-budget) (var-get season-distributed)),
    season: (var-get current-season)
  }
)

