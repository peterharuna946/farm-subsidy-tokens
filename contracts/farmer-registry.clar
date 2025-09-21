;; Farmer Registry Contract - Farm Subsidy Tokens System
;; Manages farmer registration, verification, and profile management
;; for transparent agricultural subsidy distribution

;; Error Constants
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_FARMER_EXISTS (err u101))
(define-constant ERR_FARMER_NOT_FOUND (err u102))
(define-constant ERR_INVALID_LAND_SIZE (err u103))
(define-constant ERR_INVALID_CROP_TYPE (err u104))
(define-constant ERR_INVALID_LOCATION (err u105))
(define-constant ERR_FARMER_NOT_VERIFIED (err u106))
(define-constant ERR_ALREADY_VERIFIED (err u107))
(define-constant ERR_INVALID_STATUS (err u108))
(define-constant ERR_REGISTRATION_CLOSED (err u109))
(define-constant ERR_INVALID_NAME (err u110))

;; Contract Owner and Admin
(define-constant CONTRACT_OWNER tx-sender)

;; Registration Status Constants
(define-constant STATUS_PENDING u0)
(define-constant STATUS_VERIFIED u1)
(define-constant STATUS_REJECTED u2)
(define-constant STATUS_SUSPENDED u3)

;; Land Size Limits (in acres)
(define-constant MIN_LAND_SIZE u1)
(define-constant MAX_LAND_SIZE u1000)

;; Maximum lengths for string fields
(define-constant MAX_NAME_LENGTH u50)
(define-constant MAX_CROP_TYPE_LENGTH u20)
(define-constant MAX_LOCATION_LENGTH u30)

;; Data Variables
(define-data-var total-farmers uint u0)
(define-data-var registration-open bool true)
(define-data-var next-farmer-id uint u1)

;; Farmer Registration Data
(define-map farmers
  { farmer-address: principal }
  {
    farmer-id: uint,
    name: (string-ascii 50),
    land-size: uint,
    crop-type: (string-ascii 20),
    location: (string-ascii 30),
    registration-date: uint,
    verification-date: (optional uint),
    status: uint,
    verified-by: (optional principal),
    subsidy-received: uint,
    last-updated: uint
  }
)

;; Farmer ID to Address mapping
(define-map farmer-ids
  { farmer-id: uint }
  { farmer-address: principal }
)

;; Authorized Verifiers
(define-map authorized-verifiers
  { verifier: principal }
  {
    authorized: bool,
    authorized-by: principal,
    authorized-at: uint,
    verifications-count: uint
  }
)

;; Location Statistics
(define-map location-stats
  { location: (string-ascii 30) }
  {
    farmer-count: uint,
    total-land: uint,
    verified-farmers: uint
  }
)

;; Crop Type Statistics
(define-map crop-stats
  { crop-type: (string-ascii 20) }
  {
    farmer-count: uint,
    total-land: uint,
    average-land-size: uint
  }
)

;; Public Functions

;; Register a new farmer
(define-public (register-farmer (name (string-ascii 50)) (land-size uint) (crop-type (string-ascii 20)) (location (string-ascii 30)))
  (let
    (
      (farmer-id (var-get next-farmer-id))
      (current-block stacks-block-height)
    )
    ;; Validate inputs
    (asserts! (var-get registration-open) ERR_REGISTRATION_CLOSED)
    (asserts! (is-none (map-get? farmers { farmer-address: tx-sender })) ERR_FARMER_EXISTS)
    (asserts! (and (>= land-size MIN_LAND_SIZE) (<= land-size MAX_LAND_SIZE)) ERR_INVALID_LAND_SIZE)
    (asserts! (> (len name) u0) ERR_INVALID_NAME)
    (asserts! (> (len crop-type) u0) ERR_INVALID_CROP_TYPE)
    (asserts! (> (len location) u0) ERR_INVALID_LOCATION)
    
    ;; Register farmer
    (map-set farmers
      { farmer-address: tx-sender }
      {
        farmer-id: farmer-id,
        name: name,
        land-size: land-size,
        crop-type: crop-type,
        location: location,
        registration-date: current-block,
        verification-date: none,
        status: STATUS_PENDING,
        verified-by: none,
        subsidy-received: u0,
        last-updated: current-block
      }
    )
    
    ;; Create farmer ID mapping
    (map-set farmer-ids
      { farmer-id: farmer-id }
      { farmer-address: tx-sender }
    )
    
    ;; Update statistics
    (update-location-stats location land-size true)
    (update-crop-stats crop-type land-size)
    
    ;; Update counters
    (var-set total-farmers (+ (var-get total-farmers) u1))
    (var-set next-farmer-id (+ farmer-id u1))
    
    (ok farmer-id)
  )
)

;; Verify a farmer (authorized verifiers only)
(define-public (verify-farmer (farmer-address principal) (approved bool))
  (let
    (
      (farmer-data (unwrap! (map-get? farmers { farmer-address: farmer-address }) ERR_FARMER_NOT_FOUND))
      (verifier-data (unwrap! (map-get? authorized-verifiers { verifier: tx-sender }) ERR_UNAUTHORIZED))
      (current-block stacks-block-height)
      (new-status (if approved STATUS_VERIFIED STATUS_REJECTED))
    )
    ;; Check authorization
    (asserts! (get authorized verifier-data) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status farmer-data) STATUS_PENDING) ERR_ALREADY_VERIFIED)
    
    ;; Update farmer verification
    (map-set farmers
      { farmer-address: farmer-address }
      (merge farmer-data
        {
          status: new-status,
          verification-date: (some current-block),
          verified-by: (some tx-sender),
          last-updated: current-block
        }
      )
    )
    
    ;; Update verifier statistics
    (map-set authorized-verifiers
      { verifier: tx-sender }
      (merge verifier-data
        { verifications-count: (+ (get verifications-count verifier-data) u1) }
      )
    )
    
    ;; Update location stats if verified
    (if approved
      (update-location-stats (get location farmer-data) u0 false)
      true
    )
    
    (ok new-status)
  )
)

;; Update farmer profile
(define-public (update-farmer-profile (new-crop-type (string-ascii 20)) (new-location (string-ascii 30)))
  (let
    (
      (farmer-data (unwrap! (map-get? farmers { farmer-address: tx-sender }) ERR_FARMER_NOT_FOUND))
      (current-block stacks-block-height)
    )
    ;; Validate inputs
    (asserts! (> (len new-crop-type) u0) ERR_INVALID_CROP_TYPE)
    (asserts! (> (len new-location) u0) ERR_INVALID_LOCATION)
    
    ;; Update farmer profile
    (map-set farmers
      { farmer-address: tx-sender }
      (merge farmer-data
        {
          crop-type: new-crop-type,
          location: new-location,
          last-updated: current-block
        }
      )
    )
    
    (ok true)
  )
)

;; Add authorized verifier (contract owner only)
(define-public (add-authorized-verifier (verifier principal))
  (let
    (
      (current-block stacks-block-height)
    )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (is-none (map-get? authorized-verifiers { verifier: verifier })) ERR_FARMER_EXISTS)
    
    (map-set authorized-verifiers
      { verifier: verifier }
      {
        authorized: true,
        authorized-by: tx-sender,
        authorized-at: current-block,
        verifications-count: u0
      }
    )
    
    (ok true)
  )
)

;; Remove authorized verifier (contract owner only)
(define-public (remove-authorized-verifier (verifier principal))
  (let
    (
      (verifier-data (unwrap! (map-get? authorized-verifiers { verifier: verifier }) ERR_FARMER_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    
    (map-set authorized-verifiers
      { verifier: verifier }
      (merge verifier-data { authorized: false })
    )
    
    (ok true)
  )
)

;; Toggle registration status (contract owner only)
(define-public (toggle-registration (open bool))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set registration-open open)
    (ok open)
  )
)

;; Update subsidy received amount (called by subsidy distribution contract)
(define-public (update-subsidy-received (farmer-address principal) (amount uint))
  (let
    (
      (farmer-data (unwrap! (map-get? farmers { farmer-address: farmer-address }) ERR_FARMER_NOT_FOUND))
    )
    ;; This function should be called by the subsidy distribution contract
    ;; For now, we'll allow any caller but in production, this should be restricted
    
    (map-set farmers
      { farmer-address: farmer-address }
      (merge farmer-data
        {
          subsidy-received: (+ (get subsidy-received farmer-data) amount),
          last-updated: stacks-block-height
        }
      )
    )
    
    (ok true)
  )
)

;; Private Functions

;; Update location statistics
(define-private (update-location-stats (location (string-ascii 30)) (land-size uint) (is-new-farmer bool))
  (let
    (
      (current-stats (default-to
        { farmer-count: u0, total-land: u0, verified-farmers: u0 }
        (map-get? location-stats { location: location })
      ))
    )
    (map-set location-stats
      { location: location }
      (if is-new-farmer
        {
          farmer-count: (+ (get farmer-count current-stats) u1),
          total-land: (+ (get total-land current-stats) land-size),
          verified-farmers: (get verified-farmers current-stats)
        }
        {
          farmer-count: (get farmer-count current-stats),
          total-land: (get total-land current-stats),
          verified-farmers: (+ (get verified-farmers current-stats) u1)
        }
      )
    )
  )
)

;; Update crop type statistics
(define-private (update-crop-stats (crop-type (string-ascii 20)) (land-size uint))
  (let
    (
      (current-stats (default-to
        { farmer-count: u0, total-land: u0, average-land-size: u0 }
        (map-get? crop-stats { crop-type: crop-type })
      ))
      (new-farmer-count (+ (get farmer-count current-stats) u1))
      (new-total-land (+ (get total-land current-stats) land-size))
    )
    (map-set crop-stats
      { crop-type: crop-type }
      {
        farmer-count: new-farmer-count,
        total-land: new-total-land,
        average-land-size: (/ new-total-land new-farmer-count)
      }
    )
  )
)

;; Read-only Functions

;; Get farmer information
(define-read-only (get-farmer (farmer-address principal))
  (map-get? farmers { farmer-address: farmer-address })
)

;; Get farmer by ID
(define-read-only (get-farmer-by-id (farmer-id uint))
  (match (map-get? farmer-ids { farmer-id: farmer-id })
    farmer-mapping (map-get? farmers { farmer-address: (get farmer-address farmer-mapping) })
    none
  )
)

;; Check if farmer is verified
(define-read-only (is-farmer-verified (farmer-address principal))
  (match (map-get? farmers { farmer-address: farmer-address })
    farmer-data (is-eq (get status farmer-data) STATUS_VERIFIED)
    false
  )
)

;; Check if verifier is authorized
(define-read-only (is-authorized-verifier (verifier principal))
  (match (map-get? authorized-verifiers { verifier: verifier })
    verifier-data (get authorized verifier-data)
    false
  )
)

;; Get total farmers
(define-read-only (get-total-farmers)
  (var-get total-farmers)
)

;; Get registration status
(define-read-only (is-registration-open)
  (var-get registration-open)
)

;; Get location statistics
(define-read-only (get-location-stats (location (string-ascii 30)))
  (map-get? location-stats { location: location })
)

;; Get crop type statistics
(define-read-only (get-crop-stats (crop-type (string-ascii 20)))
  (map-get? crop-stats { crop-type: crop-type })
)

;; Get verifier information
(define-read-only (get-verifier-info (verifier principal))
  (map-get? authorized-verifiers { verifier: verifier })
)

;; Get farmer eligibility for subsidy
(define-read-only (get-farmer-eligibility (farmer-address principal))
  (match (map-get? farmers { farmer-address: farmer-address })
    farmer-data
      {
        eligible: (is-eq (get status farmer-data) STATUS_VERIFIED),
        farmer-id: (get farmer-id farmer-data),
        land-size: (get land-size farmer-data),
        crop-type: (get crop-type farmer-data),
        location: (get location farmer-data)
      }
    {
      eligible: false,
      farmer-id: u0,
      land-size: u0,
      crop-type: "",
      location: ""
    }
  )
)

