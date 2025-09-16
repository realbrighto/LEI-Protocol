;; Legal Entity Registry - Blockchain-based LEI Management System
;;
;; A comprehensive smart contract for managing Legal Entity Identifiers (LEI) on the blockchain.
;; Provides immutable registration, ownership tracking, lifecycle management, and regulatory
;; compliance features for financial institutions and regulatory bodies.

;; Error constants for access control violations
(define-constant ERR-UNAUTHORIZED-ACCESS (err u100))
(define-constant ERR-INSUFFICIENT-PERMISSIONS (err u101))
(define-constant ERR-ADMIN-PRIVILEGES-REQUIRED (err u102))
(define-constant ERR-INVALID-ADMINISTRATOR (err u103))

;; Error constants for input validation failures
(define-constant ERR-MALFORMED-LEI-FORMAT (err u200))
(define-constant ERR-INVALID-LIFECYCLE-STATUS (err u201))
(define-constant ERR-INVALID-EXPIRATION-DATE (err u202))
(define-constant ERR-INVALID-PRINCIPAL-ADDRESS (err u203))

;; Error constants for business logic violations
(define-constant ERR-DUPLICATE-LEI-EXISTS (err u300))
(define-constant ERR-LEI-RECORD-NOT-FOUND (err u301))
(define-constant ERR-LEI-HAS-EXPIRED (err u302))
(define-constant ERR-IDENTICAL-OWNER-TRANSFER (err u303))

;; Legal entity identifier registry mapping
(define-map legal-entity-records
  { entity-identifier: (string-ascii 20) }
  {
    entity-owner: principal,
    lifecycle-status: (string-ascii 12),
    registration-block: uint,
    expiration-block: uint,
    last-modification-block: uint
  }
)

;; Owner portfolio tracking for entity management
(define-map entity-owner-portfolios
  { portfolio-owner: principal }
  { 
    total-entity-count: uint, 
    owned-entity-identifiers: (list 50 (string-ascii 20)) 
  }
)

;; Administrative privilege management
(define-map administrative-roles
  { administrator-address: principal }
  { 
    access-granted: bool, 
    administrative-level: (string-ascii 10) 
  }
)

;; Contract governance variables
(define-data-var contract-administrator principal tx-sender)
(define-data-var total-entity-registrations uint u0)

;; Validates Legal Entity Identifier format compliance
(define-private (validate-entity-identifier-format (entity-id (string-ascii 20)))
  (is-eq (len entity-id) u20)
)

;; Validates entity lifecycle status values
(define-private (validate-lifecycle-status (status-value (string-ascii 12)))
  (or (is-eq status-value "ACTIVE")
      (is-eq status-value "SUSPENDED") 
      (is-eq status-value "EXPIRED")
      (is-eq status-value "RETIRED"))
)

;; Validates principal address format
(define-private (validate-principal-address (target-address principal))
  (is-standard target-address)
)

;; Checks administrative privileges for transaction sender
(define-private (check-administrative-access)
  (let ((admin-privileges (map-get? administrative-roles { administrator-address: tx-sender })))
    (or
      (is-eq tx-sender (var-get contract-administrator))
      (and (is-some admin-privileges) 
           (get access-granted (unwrap-panic admin-privileges)))
    )
  )
)

;; Checks super administrator privileges for transaction sender
(define-private (check-super-admin-access)
  (let ((admin-privileges (map-get? administrative-roles { administrator-address: tx-sender })))
    (or
      (is-eq tx-sender (var-get contract-administrator))
      (and (is-some admin-privileges)
           (get access-granted (unwrap-panic admin-privileges))
           (is-eq (get administrative-level (unwrap-panic admin-privileges)) "SUPER"))
    )
  )
)

;; Checks modification permissions for specific entity identifier
(define-private (check-entity-modification-rights (entity-id (string-ascii 20)))
  (let ((entity-record (map-get? legal-entity-records { entity-identifier: entity-id })))
    (if (is-some entity-record)
      (let ((entity-data (unwrap-panic entity-record)))
        (or (check-administrative-access) 
            (is-eq tx-sender (get entity-owner entity-data)))
      )
      false
    )
  )
)

;; Adds entity identifier to owner's portfolio
(define-private (add-entity-to-owner-portfolio (entity-id (string-ascii 20)) (owner-address principal))
  (let ((current-portfolio (default-to 
                             { total-entity-count: u0, owned-entity-identifiers: (list) }
                             (map-get? entity-owner-portfolios { portfolio-owner: owner-address }))))
    (let ((existing-entities (get owned-entity-identifiers current-portfolio))
          (current-entity-count (get total-entity-count current-portfolio)))
      (match (as-max-len? (append existing-entities entity-id) u50)
        updated-entity-list (begin
          (map-set entity-owner-portfolios
            { portfolio-owner: owner-address }
            { 
              total-entity-count: (+ current-entity-count u1), 
              owned-entity-identifiers: updated-entity-list 
            })
          true)
        false)
    )
  )
)

;; Removes entity identifier from owner's portfolio
(define-private (remove-entity-from-owner-portfolio (entity-id (string-ascii 20)) (owner-address principal))
  (let ((current-portfolio (map-get? entity-owner-portfolios { portfolio-owner: owner-address })))
    (if (is-some current-portfolio)
      (let ((portfolio-data (unwrap-panic current-portfolio))
            (existing-entities (get owned-entity-identifiers portfolio-data))
            (current-entity-count (get total-entity-count portfolio-data)))
        (let ((filter-result (fold filter-entity-from-portfolio-list existing-entities 
                               { target-entity: entity-id, filtered-entities: (list) })))
          (map-set entity-owner-portfolios
            { portfolio-owner: owner-address }
            { 
              total-entity-count: (- current-entity-count u1), 
              owned-entity-identifiers: (get filtered-entities filter-result) 
            })
          true
        ))
      true
    )
  )
)

;; Helper function to filter entity from portfolio list
(define-private (filter-entity-from-portfolio-list 
  (current-entity (string-ascii 20))
  (accumulator { target-entity: (string-ascii 20), filtered-entities: (list 50 (string-ascii 20)) }))
  (let ((target-entity-id (get target-entity accumulator))
        (current-filtered-list (get filtered-entities accumulator)))
    (if (is-eq current-entity target-entity-id)
      accumulator
      { 
        target-entity: target-entity-id,
        filtered-entities: (default-to current-filtered-list 
                           (as-max-len? (append current-filtered-list current-entity) u50))
      }
    )
  )
)

;; Transfers contract ownership to new administrator
(define-public (transfer-contract-ownership (new-contract-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-administrator)) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (validate-principal-address new-contract-owner) ERR-INVALID-PRINCIPAL-ADDRESS)
    (asserts! (not (is-eq new-contract-owner tx-sender)) ERR-IDENTICAL-OWNER-TRANSFER)
    (ok (var-set contract-administrator new-contract-owner))
  )
)

;; Grants administrative privileges to specified address
(define-public (grant-administrative-privileges (new-admin-address principal) (admin-level (string-ascii 10)))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-administrator)) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (validate-principal-address new-admin-address) ERR-INVALID-PRINCIPAL-ADDRESS)
    (asserts! (or (is-eq admin-level "SUPER") (is-eq admin-level "BASIC")) ERR-INVALID-ADMINISTRATOR)
    (asserts! (not (is-eq new-admin-address tx-sender)) ERR-IDENTICAL-OWNER-TRANSFER)
    (ok (map-set administrative-roles 
      { administrator-address: new-admin-address } 
      { access-granted: true, administrative-level: admin-level }))
  )
)

;; Revokes administrative privileges from specified address
(define-public (revoke-administrative-privileges (target-admin-address principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-administrator)) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (validate-principal-address target-admin-address) ERR-INVALID-PRINCIPAL-ADDRESS)
    (asserts! (not (is-eq target-admin-address tx-sender)) ERR-IDENTICAL-OWNER-TRANSFER)
    (ok (map-set administrative-roles 
      { administrator-address: target-admin-address } 
      { access-granted: false, administrative-level: "NONE" }))
  )
)

;; Registers new Legal Entity Identifier with ownership and expiration
(define-public (register-legal-entity-identifier 
  (entity-id (string-ascii 20)) 
  (designated-owner principal) 
  (expiration-block-height uint))
  (begin
    (asserts! (check-administrative-access) ERR-ADMIN-PRIVILEGES-REQUIRED)
    (asserts! (validate-entity-identifier-format entity-id) ERR-MALFORMED-LEI-FORMAT)
    (asserts! (validate-principal-address designated-owner) ERR-INVALID-PRINCIPAL-ADDRESS)
    (asserts! (> expiration-block-height block-height) ERR-INVALID-EXPIRATION-DATE)
    (asserts! (is-none (map-get? legal-entity-records { entity-identifier: entity-id })) ERR-DUPLICATE-LEI-EXISTS)
    
    ;; Create entity record with initial data
    (map-set legal-entity-records
      { entity-identifier: entity-id }
      {
        entity-owner: designated-owner,
        lifecycle-status: "ACTIVE",
        registration-block: block-height,
        expiration-block: expiration-block-height,
        last-modification-block: block-height
      }
    )
    
    ;; Add entity to owner's portfolio
    (asserts! (add-entity-to-owner-portfolio entity-id designated-owner) ERR-INVALID-PRINCIPAL-ADDRESS)
    
    ;; Update registration counter
    (var-set total-entity-registrations (+ (var-get total-entity-registrations) u1))
    
    ;; Emit registration event for indexing
    (print {
      event-type: "entity-registered",
      entity-identifier: entity-id,
      entity-owner: designated-owner,
      registration-block: block-height
    })
    
    (ok true)
  )
)

;; Transfers entity ownership between principals
(define-public (transfer-entity-ownership (entity-id (string-ascii 20)) (new-entity-owner principal))
  (begin
    (asserts! (validate-entity-identifier-format entity-id) ERR-MALFORMED-LEI-FORMAT)
    (asserts! (validate-principal-address new-entity-owner) ERR-INVALID-PRINCIPAL-ADDRESS)
    (asserts! (check-entity-modification-rights entity-id) ERR-INSUFFICIENT-PERMISSIONS)
    
    (let ((entity-record (unwrap! (map-get? legal-entity-records { entity-identifier: entity-id }) ERR-LEI-RECORD-NOT-FOUND)))
      (let ((current-entity-owner (get entity-owner entity-record)))
        (asserts! (not (is-eq current-entity-owner new-entity-owner)) ERR-IDENTICAL-OWNER-TRANSFER)
        
        ;; Update entity ownership record
        (map-set legal-entity-records
          { entity-identifier: entity-id }
          (merge entity-record { 
            entity-owner: new-entity-owner, 
            last-modification-block: block-height 
          })
        )
        
        ;; Update portfolio records
        (asserts! (remove-entity-from-owner-portfolio entity-id current-entity-owner) ERR-INVALID-PRINCIPAL-ADDRESS)
        (asserts! (add-entity-to-owner-portfolio entity-id new-entity-owner) ERR-INVALID-PRINCIPAL-ADDRESS)
        
        ;; Emit ownership transfer event
        (print {
          event-type: "ownership-transferred",
          entity-identifier: entity-id,
          previous-owner: current-entity-owner,
          new-owner: new-entity-owner,
          transfer-block: block-height
        })
        
        (ok true)
      )
    )
  )
)

;; Updates entity lifecycle status
(define-public (update-entity-lifecycle-status (entity-id (string-ascii 20)) (new-status (string-ascii 12)))
  (begin
    (asserts! (check-administrative-access) ERR-ADMIN-PRIVILEGES-REQUIRED)
    (asserts! (validate-entity-identifier-format entity-id) ERR-MALFORMED-LEI-FORMAT)
    (asserts! (validate-lifecycle-status new-status) ERR-INVALID-LIFECYCLE-STATUS)
    
    (let ((entity-record (unwrap! (map-get? legal-entity-records { entity-identifier: entity-id }) ERR-LEI-RECORD-NOT-FOUND)))
      (map-set legal-entity-records
        { entity-identifier: entity-id }
        (merge entity-record { 
          lifecycle-status: new-status, 
          last-modification-block: block-height 
        })
      )
      
      ;; Emit status update event
      (print {
        event-type: "lifecycle-status-updated",
        entity-identifier: entity-id,
        new-status: new-status,
        update-block: block-height
      })
      
      (ok true)
    )
  )
)

;; Extends entity expiration date
(define-public (extend-entity-expiration (entity-id (string-ascii 20)) (new-expiration-block uint))
  (begin
    (asserts! (check-administrative-access) ERR-ADMIN-PRIVILEGES-REQUIRED)
    (asserts! (validate-entity-identifier-format entity-id) ERR-MALFORMED-LEI-FORMAT)
    (asserts! (> new-expiration-block block-height) ERR-INVALID-EXPIRATION-DATE)
    
    (let ((entity-record (unwrap! (map-get? legal-entity-records { entity-identifier: entity-id }) ERR-LEI-RECORD-NOT-FOUND)))
      (map-set legal-entity-records
        { entity-identifier: entity-id }
        (merge entity-record { 
          expiration-block: new-expiration-block,
          lifecycle-status: "ACTIVE",
          last-modification-block: block-height 
        })
      )
      
      (print {
        event-type: "expiration-extended",
        entity-identifier: entity-id,
        new-expiration-block: new-expiration-block,
        extension-block: block-height
      })
      
      (ok true)
    )
  )
)

;; Batch processes expired entities (super admin only)
(define-public (batch-process-expired-entities (entity-list (list 20 (string-ascii 20))))
  (begin
    (asserts! (check-super-admin-access) ERR-UNAUTHORIZED-ACCESS)
    (ok (map process-entity-expiration entity-list))
  )
)

;; Helper function to process individual entity expiration
(define-private (process-entity-expiration (entity-id (string-ascii 20)))
  (let ((entity-record (map-get? legal-entity-records { entity-identifier: entity-id })))
    (if (is-some entity-record)
      (let ((entity-data (unwrap-panic entity-record)))
        (if (and (< (get expiration-block entity-data) block-height)
                 (is-eq (get lifecycle-status entity-data) "ACTIVE"))
          (map-set legal-entity-records
            { entity-identifier: entity-id }
            (merge entity-data { 
              lifecycle-status: "EXPIRED", 
              last-modification-block: block-height 
            }))
          false))
      false)
  )
)

;; Retrieves complete entity record details
(define-read-only (get-entity-record-details (entity-id (string-ascii 20)))
  (ok (map-get? legal-entity-records { entity-identifier: entity-id }))
)

;; Checks if entity is currently active and valid
(define-read-only (check-entity-validity (entity-id (string-ascii 20)))
  (let ((entity-record (map-get? legal-entity-records { entity-identifier: entity-id })))
    (if (is-some entity-record)
      (let ((entity-data (unwrap-panic entity-record)))
        (ok (and (is-eq (get lifecycle-status entity-data) "ACTIVE")
                 (> (get expiration-block entity-data) block-height))))
      ERR-LEI-RECORD-NOT-FOUND
    )
  )
)

;; Retrieves owner's complete portfolio information
(define-read-only (get-owner-portfolio-details (portfolio-owner principal))
  (ok (default-to 
        { total-entity-count: u0, owned-entity-identifiers: (list) }
        (map-get? entity-owner-portfolios { portfolio-owner: portfolio-owner })))
)

;; Retrieves contract operational statistics
(define-read-only (get-contract-operational-statistics)
  (ok {
    total-registered-entities: (var-get total-entity-registrations),
    current-contract-administrator: (var-get contract-administrator),
    current-block-height: block-height
  })
)

;; Retrieves administrative information for address
(define-read-only (get-administrative-information (target-address principal))
  (let ((admin-record (map-get? administrative-roles { administrator-address: target-address })))
    (ok {
      is-contract-owner: (is-eq target-address (var-get contract-administrator)),
      has-admin-privileges: (and (is-some admin-record) 
                                 (get access-granted (unwrap-panic admin-record))),
      administrative-level: (if (is-some admin-record)
                              (get administrative-level (unwrap-panic admin-record))
                              "NONE")
    })
  )
)

;; Public helper for entity identifier format validation
(define-read-only (validate-entity-identifier-format-public (entity-id (string-ascii 20)))
  (ok (validate-entity-identifier-format entity-id))
)

;; Initialize contract with deployer as super administrator
(begin
  (map-set administrative-roles 
    { administrator-address: tx-sender } 
    { access-granted: true, administrative-level: "SUPER" })
)