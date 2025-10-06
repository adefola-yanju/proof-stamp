;; Title: ProofStamp
;;
;; Summary:
;; A trustless timestamping protocol that embeds cryptographic proofs into
;; Bitcoin's immutable ledger through Stacks, enabling anyone to prove when
;; a document existed without revealing its contents-ideal for establishing
;; prior art, securing digital rights, and creating tamper-proof audit trails.
;;
;; Description:
;; ProofStamp reimagines document notarization for the blockchain era. Instead
;; of relying on centralized authorities, it harnesses Bitcoin's battle-tested
;; security to create permanent, independently verifiable timestamps for any
;; digital content. Users submit SHA-256 fingerprints of their documents,
;; which are anchored to specific Bitcoin block heights via Stacks smart
;; contracts-establishing mathematical proof of existence that cannot be
;; backdated or forged. The privacy-preserving architecture ensures sensitive
;; information never touches the blockchain; only cryptographic hashes are
;; stored, allowing unlimited verification without exposure. Perfect for
;; creators protecting copyright claims, researchers establishing discovery
;; dates, businesses maintaining compliance records, and legal professionals
;; building evidence chains. Each proof carries the full weight of Bitcoin's
;; computational security while remaining accessible to anyone with the
;; original document. No middlemen, no subscriptions, no trust required.

;; CONSTANTS & ERROR CODES

(define-constant CONTRACT_OWNER tx-sender)
(define-constant NULL_ADDRESS 'SP000000000000000000002Q6VF78)

(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_PROOF_NOT_FOUND (err u101))
(define-constant ERR_INVALID_HASH (err u102))
(define-constant ERR_INVALID_RECIPIENT (err u103))
(define-constant ERR_INVALID_VERSION (err u104))
(define-constant ERR_SELF_REFERENCE (err u105))
(define-constant ERR_INVALID_PROOF_ID (err u106))

;; DATA VARIABLES

(define-data-var total-proofs uint u0)
(define-data-var protocol-version uint u1)

;; DATA MAPS

;; Core proof registry - immutable timestamp records
(define-map proofs
  { proof-id: uint }
  {
    creator: principal,
    recipient: principal,
    content-hash: (buff 32),
    timestamp: uint,
    block-height: uint,
    verified: bool
  }
)

;; User activity index
(define-map user-proof-count
  { user: principal }
  { count: uint }
)

;; Hash lookup index - enables reverse searches
(define-map hash-registry
  { content-hash: (buff 32) }
  { 
    proof-id: uint,
    verification-count: uint
  }
)

;; PRIVATE HELPER FUNCTIONS

(define-private (is-valid-hash (hash (buff 32)))
  (> (len hash) u0)
)

(define-private (is-valid-principal (user principal))
  (not (is-eq user NULL_ADDRESS))
)

(define-private (increment-user-count (user principal))
  (let 
    (
      (current-count (default-to u0 
        (get count (map-get? user-proof-count { user: user }))
      ))
    )
    (map-set user-proof-count 
      { user: user }
      { count: (+ current-count u1) }
    )
  )
)

;; PUBLIC CORE FUNCTIONS

;; Creates an immutable timestamp proof anchored to Bitcoin
;; 
;; @desc: Registers a cryptographic fingerprint on-chain, establishing
;;        verifiable proof that a document existed at a specific block height.
;;        The hash is permanently recorded with creator/recipient metadata,
;;        creating an unforgeable chain of custody without exposing content.
;;
;; @param recipient: Principal who can access/verify this proof
;; @param content-hash: SHA-256 hash of the document being timestamped
;; 
;; @returns: (response uint uint) - Unique proof ID on success
;;
;; Security: Prevents self-proofs, validates inputs before storage
(define-public (create-proof 
  (recipient principal) 
  (content-hash (buff 32))
)
  (let 
    (
      (proof-id (+ (var-get total-proofs) u1))
      (current-block stacks-block-height)
    )
    ;; Validate inputs
    (asserts! (is-valid-principal recipient) ERR_INVALID_RECIPIENT)
    (asserts! (is-valid-hash content-hash) ERR_INVALID_HASH)
    (asserts! (not (is-eq tx-sender recipient)) ERR_SELF_REFERENCE)
    
    ;; Store proof record
    (map-set proofs
      { proof-id: proof-id }
      {
        creator: tx-sender,
        recipient: recipient,
        content-hash: content-hash,
        timestamp: current-block,
        block-height: current-block,
        verified: false
      }
    )
    
    ;; Index hash for lookups
    (map-set hash-registry
      { content-hash: content-hash }
      {
        proof-id: proof-id,
        verification-count: u0
      }
    )
    
    ;; Update counters
    (var-set total-proofs proof-id)
    (increment-user-count tx-sender)
    
    (ok proof-id)
  )
)

;; Verifies document authenticity via cryptographic comparison
;;
;; @desc: Performs zero-knowledge verification by comparing a provided hash
;;        against the stored proof. Successful matches update verification
;;        status and increment the audit counter. This proves document
;;        integrity without accessing the original file.
;;
;; @param proof-id: Identifier of the proof to verify
;; @param provided-hash: Hash to validate against stored record
;;
;; @returns: (response bool uint) - true if valid, false if mismatch
;;
;; Security: Validates proof existence before comparison
(define-public (verify-proof 
  (proof-id uint) 
  (provided-hash (buff 32))
)
  (let 
    (
      (proof-record (unwrap! 
        (map-get? proofs { proof-id: proof-id }) 
        ERR_PROOF_NOT_FOUND
      ))
      (stored-hash (get content-hash proof-record))
    )
    ;; Validate inputs
    (asserts! (is-valid-hash provided-hash) ERR_INVALID_HASH)
    (asserts! (> proof-id u0) ERR_INVALID_PROOF_ID)
    
    (if (is-eq stored-hash provided-hash)
      (begin
        ;; Mark as verified
        (map-set proofs
          { proof-id: proof-id }
          (merge proof-record { verified: true })
        )
        
        ;; Increment verification counter
        (let 
          (
            (registry-entry (default-to 
              { proof-id: u0, verification-count: u0 } 
              (map-get? hash-registry { content-hash: provided-hash })
            ))
          )
          (map-set hash-registry
            { content-hash: provided-hash }
            {
              proof-id: proof-id,
              verification-count: (+ (get verification-count registry-entry) u1)
            }
          )
        )
        (ok true)
      )
      (ok false)
    )
  )
)

;; READ-ONLY QUERY FUNCTIONS

;; Retrieves complete proof record with metadata
;;
;; @param proof-id: Target proof identifier
;; @returns: (response (optional proof-data) uint)
(define-read-only (get-proof-details (proof-id uint))
  (begin
    (asserts! (> proof-id u0) ERR_INVALID_PROOF_ID)
    (ok (map-get? proofs { proof-id: proof-id }))
  )
)

;; Returns number of proofs created by a user
;;
;; @param user: Principal to query
;; @returns: (response uint uint)
(define-read-only (get-user-proof-count (user principal))
  (begin
    (asserts! (is-valid-principal user) ERR_INVALID_RECIPIENT)
    (ok (default-to u0 
      (get count (map-get? user-proof-count { user: user }))
    ))
  )
)

;; Returns global proof counter
;;
;; @returns: (response uint uint)
(define-read-only (get-total-proofs)
  (ok (var-get total-proofs))
)

;; Returns current protocol version
;;
;; @returns: (response uint uint)
(define-read-only (get-protocol-version)
  (ok (var-get protocol-version))
)

;; Checks if a hash exists in the registry
;;
;; @param hash: SHA-256 hash to lookup
;; @returns: (response bool uint)
(define-read-only (hash-exists (hash (buff 32)))
  (begin
    (asserts! (is-valid-hash hash) ERR_INVALID_HASH)
    (ok (is-some (map-get? hash-registry { content-hash: hash })))
  )
)

;; Returns verification count for a hash
;;
;; @param hash: Content hash to query
;; @returns: (response uint uint)
(define-read-only (get-verification-count (hash (buff 32)))
  (begin
    (asserts! (is-valid-hash hash) ERR_INVALID_HASH)
    (ok (default-to u0 
      (get verification-count 
        (map-get? hash-registry { content-hash: hash })
      )
    ))
  )
)

;; ADMINISTRATIVE FUNCTIONS

;; Updates protocol version (owner only)
;;
;; @param new-version: New version number
;; @returns: (response bool uint)
;;
;; Security: Restricted to contract owner, enforces version increment
(define-public (update-protocol-version (new-version uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (> new-version (var-get protocol-version)) ERR_INVALID_VERSION)
    (var-set protocol-version new-version)
    (ok true)
  )
)