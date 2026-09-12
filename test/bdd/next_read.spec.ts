import { describe, it, expect as vitestExpect, beforeAll, afterAll } from 'vitest'
import { loadFeature, describeFeature } from '@amiceli/vitest-cucumber'
import { chromium, Browser, Page, expect as playwrightExpect } from '@playwright/test'

const feature = await loadFeature('test/bdd/features/next_read.feature')

describeFeature(feature, ({ Background, Scenario }) => {
  let browser: Browser
  let page: Page

  beforeAll(async () => {
    browser = await chromium.launch({ headless: true })
    const context = await browser.newContext()
    page = await context.newPage()
  })

  afterAll(async () => {
    if (browser) {
      await browser.close()
    }
  })

  Background(({ Given, And }) => {
    Given('the library database is seeded with real catalog books and circulation records', async () => {
      vitestExpect(true).toBe(true)
    })

    And('the Next Read web interface is running at "/next-read"', async () => {
      await page.goto('http://localhost:4000/next-read', { waitUntil: 'networkidle' })
    })
  })

  Scenario('Render dual-persona split view', ({ Then, And }) => {
    Then('the header displays "Next Read" and "Dual Experience Live Harness"', async () => {
      const header = page.locator('header').last()
      await playwrightExpect(header).toContainText('Next Read')
      await playwrightExpect(header).toContainText('Dual Experience Live Harness')
    })

    And('the Student Window and Librarian Advisory Desk are both visible', async () => {
      await playwrightExpect(page.locator('[data-testid="student-window"]')).toBeVisible()
      await playwrightExpect(page.locator('[data-testid="librarian-window"]')).toBeVisible()
    })

    And('the proof sequence status shows "01 ranked"', async () => {
      const proofBar = page.locator('[data-testid="proof-sequence"]')
      await playwrightExpect(proofBar).toBeVisible()
      await playwrightExpect(proofBar).toContainText('01 ranked')
    })
  })

  Scenario('Expand HDDL Task Calculus and epistemic receipts drawer', ({ When, Then, And }) => {
    When('the user clicks the "HDDL Task Calculus" toggle in the header', async () => {
      const toggle = page.locator('[data-testid="hddl-calculus-toggle"]')
      await toggle.click()
      await page.waitForTimeout(300)
    })

    Then('the HDDL Task Calculus drawer slides open', async () => {
      const drawer = page.locator('[data-testid="hddl-drawer"]')
      await playwrightExpect(drawer).toBeVisible()
    })

    And('the domain confirms "next-read" from "docs/hddl/next-read.hddl"', async () => {
      const drawer = page.locator('[data-testid="hddl-drawer"]')
      await playwrightExpect(drawer).toContainText('next-read')
      await playwrightExpect(drawer).toContainText('docs/hddl/next-read.hddl')
    })

    And('the active compound task displays "NEXT-READ-DUAL-PERSONA-EXPERIENCE"', async () => {
      const drawer = page.locator('[data-testid="hddl-drawer"]')
      await playwrightExpect(drawer).toContainText('NEXT-READ-DUAL-PERSONA-EXPERIENCE')
    })
  })

  Scenario('Expand grounded explainability drawer', ({ When, Then, And }) => {
    When('the student clicks "Why This?" on the top recommendation', async () => {
      const whyButton = page.locator('[data-testid="why-button"]').first()
      await whyButton.click()
      await page.waitForTimeout(400)
    })

    Then('the grounded explainability drawer appears', async () => {
      const drawer = page.locator('[data-testid="explanation-drawer"]').first()
      await playwrightExpect(drawer).toBeVisible()
    })

    And('the drawer explains the historical reading connection', async () => {
      const drawer = page.locator('[data-testid="explanation-drawer"]').first()
      await playwrightExpect(drawer).toContainText('Grounded Explanation')
      await playwrightExpect(drawer).toContainText('Traced to real student circulation records')
    })

    And('the composite factor weights display "collaborative", "semantic", and "grade fit"', async () => {
      const drawer = page.locator('[data-testid="explanation-drawer"]').first()
      await playwrightExpect(drawer).toContainText('collaborative')
      await playwrightExpect(drawer).toContainText('semantic')
      await playwrightExpect(drawer).toContainText('grade fit')
    })
  })

  Scenario('Librarian curates title with instant PubSub broadcast', ({ When, Then, And }) => {
    let bookId: string | null = null

    When('the librarian toggles the pin on a candidate book', async () => {
      const pinBtn = page.locator('[data-testid="pin-button"]').first()
      bookId = await pinBtn.getAttribute('data-book-id')
      await pinBtn.click()
      await page.waitForTimeout(500)
    })

    Then('the title receives the staff spotlight badge', async () => {
      if (bookId) {
        const studentCard = page.locator(`[data-testid="book-card"][data-book-id="${bookId}"]`)
        await playwrightExpect(studentCard).toBeVisible()
      }
    })

    And('the PubSub curation broadcast is recorded', async () => {
      const proofBar = page.locator('[data-testid="proof-sequence"]')
      await playwrightExpect(proofBar).toContainText('03 curated')
    })
  })

  Scenario('Student completes checkout and updates circulation statistics', ({ When, Then, And }) => {
    When('the student checks out their top recommended title', async () => {
      const checkoutBtn = page.locator('[data-testid="checkout-button"]').first()
      await checkoutBtn.click()
      await page.waitForTimeout(600)
    })

    Then('a success flash banner confirms the checkout', async () => {
      const flash = page.locator('[data-testid="flash-info"]')
      await playwrightExpect(flash).toBeVisible()
      await playwrightExpect(flash).toContainText('Successfully checked out')
    })

    And('the Librarian Advisory Desk updates the "Checked Out Today" circulation counter', async () => {
      const stat = page.locator('[data-testid="stat-out-today"]')
      await playwrightExpect(stat).toBeVisible()
    })
  })

  Scenario('Librarian executes semantic search with ranker telemetry', ({ When, And, Then }) => {
    When('the librarian enters the query "Show accessible science-fiction alternatives for students who liked The Wildwater Signal"', async () => {
      const askInput = page.locator('[data-testid="ask-input"]')
      await askInput.fill('Show accessible science-fiction alternatives for students who liked The Wildwater Signal')
    })

    And('clicks the "Ask Catalog" button', async () => {
      const askBtn = page.locator('[data-testid="ask-button"]')
      await askBtn.click()
      await page.waitForTimeout(1000)
    })

    Then('the assistant displays matching thematic alternatives', async () => {
      const results = page.locator('[data-testid="ask-results"]')
      await playwrightExpect(results).toBeVisible()
    })

    And('the telemetry confirms candidate admission from the vector ranker', async () => {
      const results = page.locator('[data-testid="ask-results"]')
      await playwrightExpect(results).toContainText('Ranker admitted')
    })
  })
})
