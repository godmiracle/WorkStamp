## ADDED Requirements

### Requirement: 2026 statutory holidays and adjusted workdays match the official schedule
The workday calculator SHALL encode the official 2026 mainland China schedule as follows: New Year holiday January 1–3 with adjusted workday January 4; Spring Festival holiday February 15–23 with adjusted workdays February 14 and February 28; Labour Day holiday May 1–5 with adjusted workday May 9; Mid-Autumn Festival holiday September 25–27 with adjusted workday September 20; and National Day holiday October 1–7 with adjusted workday October 10. April 26 and September 27 SHALL NOT be treated as adjusted workdays.

#### Scenario: Holiday dates are excluded when holiday exclusion is enabled
- **WHEN** a date falls within one of the listed 2026 holiday ranges and holiday exclusion is enabled
- **THEN** the date is not counted as a workday unless it is explicitly listed as an adjusted workday

#### Scenario: Every official adjusted workday is counted
- **WHEN** the calculator evaluates January 4, February 14, February 28, May 9, September 20, or October 10 with the relevant exclusion settings enabled
- **THEN** the date is counted as a workday even when it falls on a weekend

#### Scenario: Erroneous adjusted dates are not counted as workdays
- **WHEN** the calculator evaluates April 26 or September 27 as a candidate adjusted workday
- **THEN** neither date receives adjusted-workday precedence; September 27 remains a holiday and April 26 follows ordinary weekend/holiday rules

### Requirement: Adjusted workdays take precedence over weekend and holiday exclusion
The calculator SHALL apply an explicit adjusted-workday override before applying weekend or holiday exclusion, while preserving the existing setting switches that enable or disable weekend and statutory-holiday exclusion.

#### Scenario: Adjusted Saturday is counted while weekends are excluded
- **WHEN** weekend exclusion is enabled and the date is an official adjusted Saturday such as February 14 or May 9
- **THEN** the date is counted as a workday

#### Scenario: Ordinary weekend remains excluded
- **WHEN** weekend exclusion is enabled and the date is not an official adjusted workday
- **THEN** the date is excluded from workday counting unless the existing first-day rule applies

### Requirement: Attendance status has three explicit time states
The attendance status resolver SHALL return exactly one of the user-visible states “上班前”, “上班”, or “下班” for a capture date using both configured on-duty and off-duty times. Before the on-duty boundary it SHALL return “上班前”; at or after the on-duty boundary and before the off-duty boundary it SHALL return “上班”; at or after the off-duty boundary it SHALL return “下班”.

#### Scenario: Capture before on-duty time
- **WHEN** the capture time is earlier than the configured on-duty time
- **THEN** the resolved status is “上班前”

#### Scenario: Capture at or during the work interval
- **WHEN** the capture time equals the configured on-duty time or is after it but earlier than the configured off-duty time
- **THEN** the resolved status is “上班”

#### Scenario: Capture at or after off-duty time
- **WHEN** the capture time equals or is later than the configured off-duty time
- **THEN** the resolved status is “下班”

#### Scenario: Both settings affect output
- **WHEN** either the on-duty or off-duty setting changes while the capture time remains fixed
- **THEN** the resolver re-evaluates the applicable boundary and can change the returned state without introducing attendance history

### Requirement: Workday numbering preserves the configured first-day contract
The workday calculator SHALL continue to count the configured first day as day 1, then apply the selected weekend, holiday, and adjusted-workday rules to subsequent dates.

#### Scenario: Configured first day falls on an excluded date
- **WHEN** the configured first day is a weekend or statutory holiday and the calculator starts numbering from it
- **THEN** that configured first day is returned as workday 1
