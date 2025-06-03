;; Health Optimization Contract
;; This contract optimizes consciousness biohacking outcomes

(define-data-var admin principal tx-sender)

;; User health data
(define-map user-health-data principal
  {
    last-updated: uint,
    consciousness-score: uint,
    wellbeing-score: uint,
    cognitive-score: uint
  }
)

;; User protocol enrollments
(define-map user-protocols
  { user: principal, protocol-id: uint }
  {
    start-date: uint,
    current-step: uint,
    completed: bool
  }
)

;; User progress logs
(define-map progress-logs
  { user: principal, log-id: uint }
  {
    timestamp: uint,
    protocol-id: uint,
    step-id: uint,
    notes: (string-utf8 256),
    consciousness-delta: int,
    wellbeing-delta: int,
    cognitive-delta: int
  }
)

;; User log counter
(define-map user-log-counters principal uint)

;; Check if caller is admin
(define-private (is-admin)
  (is-eq tx-sender (var-get admin))
)

;; Get user health data
(define-read-only (get-health-data (user principal))
  (default-to
    {
      last-updated: u0,
      consciousness-score: u0,
      wellbeing-score: u0,
      cognitive-score: u0
    }
    (map-get? user-health-data user)
  )
)

;; Get user protocol enrollment
(define-read-only (get-user-protocol (user principal) (protocol-id uint))
  (map-get? user-protocols { user: user, protocol-id: protocol-id })
)

;; Enroll in a protocol
(define-public (enroll-in-protocol (protocol-id uint))
  (begin
    (asserts! (is-none (map-get? user-protocols { user: tx-sender, protocol-id: protocol-id })) (err u400)) ;; Already enrolled
    (map-set user-protocols
      { user: tx-sender, protocol-id: protocol-id }
      {
        start-date: block-height,
        current-step: u0,
        completed: false
      }
    )
    (ok true)
  )
)

;; Update health metrics
(define-public (update-health-metrics
    (consciousness-score uint)
    (wellbeing-score uint)
    (cognitive-score uint))
  (begin
    (asserts! (<= consciousness-score u100) (err u400)) ;; Score must be 0-100
    (asserts! (<= wellbeing-score u100) (err u400)) ;; Score must be 0-100
    (asserts! (<= cognitive-score u100) (err u400)) ;; Score must be 0-100
    (map-set user-health-data tx-sender
      {
        last-updated: block-height,
        consciousness-score: consciousness-score,
        wellbeing-score: wellbeing-score,
        cognitive-score: cognitive-score
      }
    )
    (ok true)
  )
)

;; Log progress in a protocol
(define-public (log-progress
    (protocol-id uint)
    (step-id uint)
    (notes (string-utf8 256))
    (consciousness-delta int)
    (wellbeing-delta int)
    (cognitive-delta int))
  (let (
    (enrollment (map-get? user-protocols { user: tx-sender, protocol-id: protocol-id }))
    (log-counter (default-to u0 (map-get? user-log-counters tx-sender)))
  )
    (asserts! (is-some enrollment) (err u404)) ;; Not enrolled
    (asserts! (is-eq (get current-step (unwrap-panic enrollment)) step-id) (err u400)) ;; Wrong step

    ;; Add progress log
    (map-set progress-logs
      { user: tx-sender, log-id: log-counter }
      {
        timestamp: block-height,
        protocol-id: protocol-id,
        step-id: step-id,
        notes: notes,
        consciousness-delta: consciousness-delta,
        wellbeing-delta: wellbeing-delta,
        cognitive-delta: cognitive-delta
      }
    )

    ;; Update log counter
    (map-set user-log-counters tx-sender (+ log-counter u1))

    (ok true)
  )
)

;; Advance to next step in protocol
(define-public (advance-protocol-step (protocol-id uint))
  (let (
    (enrollment (map-get? user-protocols { user: tx-sender, protocol-id: protocol-id }))
  )
    (asserts! (is-some enrollment) (err u404)) ;; Not enrolled
    (asserts! (not (get completed (unwrap-panic enrollment))) (err u400)) ;; Already completed

    ;; Update to next step
    (map-set user-protocols
      { user: tx-sender, protocol-id: protocol-id }
      (merge (unwrap-panic enrollment)
        { current-step: (+ (get current-step (unwrap-panic enrollment)) u1) }
      )
    )

    (ok true)
  )
)

;; Complete a protocol
(define-public (complete-protocol (protocol-id uint))
  (let (
    (enrollment (map-get? user-protocols { user: tx-sender, protocol-id: protocol-id }))
  )
    (asserts! (is-some enrollment) (err u404)) ;; Not enrolled
    (asserts! (not (get completed (unwrap-panic enrollment))) (err u400)) ;; Already completed

    ;; Mark as completed
    (map-set user-protocols
      { user: tx-sender, protocol-id: protocol-id }
      (merge (unwrap-panic enrollment) { completed: true })
    )

    (ok true)
  )
)
