Feature: Next Read Deck Experience, Dual Persona Acceptance & HDDL Task Calculus

  Background:
    Given the library database is seeded with real catalog books and circulation records
    And the Next Read web interface is running at "/next-read"

  Scenario: Render dual-persona split view
    Then the header displays "Next Read" and "Dual Experience Live Harness"
    And the Student Window and Librarian Advisory Desk are both visible
    And the proof sequence status shows "01 ranked"

  Scenario: Expand HDDL Task Calculus and epistemic receipts drawer
    When the user clicks the "HDDL Task Calculus" toggle in the header
    Then the HDDL Task Calculus drawer slides open
    And the domain confirms "next-read" from "docs/hddl/next-read.hddl"
    And the active compound task displays "NEXT-READ-DUAL-PERSONA-EXPERIENCE"

  Scenario: Expand grounded explainability drawer
    When the student clicks "Why This?" on the top recommendation
    Then the grounded explainability drawer appears
    And the drawer explains the historical reading connection
    And the composite factor weights display "collaborative", "semantic", and "grade fit"

  Scenario: Librarian curates title with instant PubSub broadcast
    When the librarian toggles the pin on a candidate book
    Then the title receives the staff spotlight badge
    And the PubSub curation broadcast is recorded

  Scenario: Student completes checkout and updates circulation statistics
    When the student checks out their top recommended title
    Then a success flash banner confirms the checkout
    And the Librarian Advisory Desk updates the "Checked Out Today" circulation counter

  Scenario: Librarian executes semantic search with ranker telemetry
    When the librarian enters the query "Show accessible science-fiction alternatives for students who liked The Wildwater Signal"
    And clicks the "Ask Catalog" button
    Then the assistant displays matching thematic alternatives
    And the telemetry confirms candidate admission from the vector ranker
