;; Biohacking Protocol Contract
;; This contract manages consciousness biohacking programs

(define-data-var admin principal tx-sender)

;; Protocol status: 0 = draft, 1 = active, 2 = deprecated
(define-map protocols uint
  {
    name: (string-ascii 64),
    creator: principal,
    description: (string-utf8 256),
    status: uint,
    safety-level: uint,
    created-at: uint
  }
)

;; Protocol steps
(define-map protocol-steps
  { protocol-id: uint, step-id: uint }
  {
    title: (string-ascii 64),
    description: (string-utf8 256),
    duration-days: uint
  }
)

;; Protocol counter
(define-data-var protocol-counter uint u0)

;; Check if caller is admin
(define-private (is-admin)
  (is-eq tx-sender (var-get admin))
)

;; Get protocol details
(define-read-only (get-protocol (protocol-id uint))
  (map-get? protocols protocol-id)
)

;; Get protocol step
(define-read-only (get-protocol-step (protocol-id uint) (step-id uint))
  (map-get? protocol-steps { protocol-id: protocol-id, step-id: step-id })
)

;; Create a new protocol
(define-public (create-protocol
    (name (string-ascii 64))
    (description (string-utf8 256))
    (safety-level uint))
  (let ((protocol-id (var-get protocol-counter)))
    (asserts! (<= safety-level u5) (err u400)) ;; Safety level must be between 0-5
    (map-set protocols protocol-id
      {
        name: name,
        creator: tx-sender,
        description: description,
        status: u0, ;; Draft status
        safety-level: safety-level,
        created-at: block-height
      }
    )
    (var-set protocol-counter (+ protocol-id u1))
    (ok protocol-id)
  )
)

;; Add a step to a protocol
(define-public (add-protocol-step
    (protocol-id uint)
    (step-id uint)
    (title (string-ascii 64))
    (description (string-utf8 256))
    (duration-days uint))
  (let ((protocol (map-get? protocols protocol-id)))
    (asserts! (is-some protocol) (err u404)) ;; Protocol not found
    (asserts! (is-eq (get creator (unwrap-panic protocol)) tx-sender) (err u403)) ;; Not the creator
    (asserts! (is-eq (get status (unwrap-panic protocol)) u0) (err u400)) ;; Not in draft status
    (map-set protocol-steps
      { protocol-id: protocol-id, step-id: step-id }
      {
        title: title,
        description: description,
        duration-days: duration-days
      }
    )
    (ok true)
  )
)

;; Activate a protocol
(define-public (activate-protocol (protocol-id uint))
  (let ((protocol (map-get? protocols protocol-id)))
    (asserts! (is-some protocol) (err u404)) ;; Protocol not found
    (asserts! (is-eq (get creator (unwrap-panic protocol)) tx-sender) (err u403)) ;; Not the creator
    (asserts! (is-eq (get status (unwrap-panic protocol)) u0) (err u400)) ;; Not in draft status
    (map-set protocols protocol-id
      (merge (unwrap-panic protocol) { status: u1 }) ;; Set to active
    )
    (ok true)
  )
)

;; Deprecate a protocol
(define-public (deprecate-protocol (protocol-id uint))
  (let ((protocol (map-get? protocols protocol-id)))
    (asserts! (is-some protocol) (err u404)) ;; Protocol not found
    (asserts! (or (is-eq (get creator (unwrap-panic protocol)) tx-sender) (is-admin)) (err u403)) ;; Not authorized
    (asserts! (is-eq (get status (unwrap-panic protocol)) u1) (err u400)) ;; Not active
    (map-set protocols protocol-id
      (merge (unwrap-panic protocol) { status: u2 }) ;; Set to deprecated
    )
    (ok true)
  )
)
