;; Compliance Monitoring Contract
;; Ensures quantum readiness standards compliance

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u500))
(define-constant ERR_INVALID_STATUS (err u501))
(define-constant ERR_NOT_FOUND (err u502))
(define-constant ERR_ALREADY_EXISTS (err u503))

;; Compliance statuses
(define-constant STATUS_COMPLIANT u1)
(define-constant STATUS_NON_COMPLIANT u2)
(define-constant STATUS_UNDER_REVIEW u3)
(define-constant STATUS_REMEDIATION u4)

;; Compliance frameworks
(define-constant FRAMEWORK_NIST u1)
(define-constant FRAMEWORK_ISO27001 u2)
(define-constant FRAMEWORK_PCI_DSS u3)
(define-constant FRAMEWORK_SOX u4)
(define-constant FRAMEWORK_CUSTOM u5)

;; Compliance records
(define-map compliance-records
  { institution-id: uint }
  {
    overall-status: uint,
    last-audit-date: uint,
    next-audit-date: uint,
    compliance-score: uint,
    auditor: principal,
    findings-count: uint,
    remediation-deadline: uint,
    notes: (string-ascii 500)
  }
)

;; Framework compliance
(define-map framework-compliance
  { institution-id: uint, framework: uint }
  {
    compliance-status: uint,
    last-assessment: uint,
    score: uint,
    requirements-met: uint,
    total-requirements: uint,
    assessor: principal
  }
)

;; Compliance findings
(define-map compliance-findings
  { institution-id: uint, finding-id: uint }
  {
    framework: uint,
    severity: uint,
    description: (string-ascii 300),
    remediation-plan: (string-ascii 400),
    status: uint,
    identified-date: uint,
    target-resolution: uint,
    actual-resolution: uint
  }
)

(define-data-var next-finding-id uint u1)

;; Public functions
(define-public (create-compliance-record (institution-id uint)
                                       (next-audit-date uint)
                                       (compliance-score uint)
                                       (findings-count uint)
                                       (remediation-deadline uint)
                                       (notes (string-ascii 500)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (and (<= compliance-score u100) (>= compliance-score u0)) ERR_INVALID_STATUS)

    (map-set compliance-records
      { institution-id: institution-id }
      {
        overall-status: (if (>= compliance-score u80) STATUS_COMPLIANT STATUS_NON_COMPLIANT),
        last-audit-date: block-height,
        next-audit-date: next-audit-date,
        compliance-score: compliance-score,
        auditor: tx-sender,
        findings-count: findings-count,
        remediation-deadline: remediation-deadline,
        notes: notes
      }
    )
    (ok true)
  )
)

(define-public (assess-framework-compliance (institution-id uint)
                                          (framework uint)
                                          (requirements-met uint)
                                          (total-requirements uint))
  (let ((score (if (> total-requirements u0) (/ (* requirements-met u100) total-requirements) u0))
        (status (if (>= score u80) STATUS_COMPLIANT STATUS_NON_COMPLIANT)))
    (begin
      (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
      (asserts! (<= framework FRAMEWORK_CUSTOM) ERR_INVALID_STATUS)
      (asserts! (<= requirements-met total-requirements) ERR_INVALID_STATUS)

      (map-set framework-compliance
        { institution-id: institution-id, framework: framework }
        {
          compliance-status: status,
          last-assessment: block-height,
          score: score,
          requirements-met: requirements-met,
          total-requirements: total-requirements,
          assessor: tx-sender
        }
      )
      (ok score)
    )
  )
)

(define-public (add-compliance-finding (institution-id uint)
                                     (framework uint)
                                     (severity uint)
                                     (description (string-ascii 300))
                                     (remediation-plan (string-ascii 400))
                                     (target-resolution uint))
  (let ((finding-id (var-get next-finding-id)))
    (begin
      (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
      (asserts! (<= framework FRAMEWORK_CUSTOM) ERR_INVALID_STATUS)
      (asserts! (and (<= severity u5) (>= severity u1)) ERR_INVALID_STATUS)

      (map-set compliance-findings
        { institution-id: institution-id, finding-id: finding-id }
        {
          framework: framework,
          severity: severity,
          description: description,
          remediation-plan: remediation-plan,
          status: u0,
          identified-date: block-height,
          target-resolution: target-resolution,
          actual-resolution: u0
        }
      )
      (var-set next-finding-id (+ finding-id u1))
      (ok finding-id)
    )
  )
)

(define-public (resolve-finding (institution-id uint) (finding-id uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)

    (match (map-get? compliance-findings { institution-id: institution-id, finding-id: finding-id })
      finding-data
      (begin
        (map-set compliance-findings
          { institution-id: institution-id, finding-id: finding-id }
          (merge finding-data {
            status: u1,
            actual-resolution: block-height
          })
        )
        (ok true)
      )
      ERR_NOT_FOUND
    )
  )
)

;; Read-only functions
(define-read-only (get-compliance-record (institution-id uint))
  (map-get? compliance-records { institution-id: institution-id })
)

(define-read-only (get-framework-compliance (institution-id uint) (framework uint))
  (map-get? framework-compliance { institution-id: institution-id, framework: framework })
)

(define-read-only (get-compliance-finding (institution-id uint) (finding-id uint))
  (map-get? compliance-findings { institution-id: institution-id, finding-id: finding-id })
)

(define-read-only (get-framework-name (framework uint))
  (if (is-eq framework FRAMEWORK_NIST)
    "NIST"
    (if (is-eq framework FRAMEWORK_ISO27001)
      "ISO 27001"
      (if (is-eq framework FRAMEWORK_PCI_DSS)
        "PCI DSS"
        (if (is-eq framework FRAMEWORK_SOX)
          "SOX"
          "Custom"
        )
      )
    )
  )
)

(define-read-only (get-compliance-status-name (status uint))
  (if (is-eq status STATUS_COMPLIANT)
    "Compliant"
    (if (is-eq status STATUS_NON_COMPLIANT)
      "Non-Compliant"
      (if (is-eq status STATUS_UNDER_REVIEW)
        "Under Review"
        "Remediation"
      )
    )
  )
)
