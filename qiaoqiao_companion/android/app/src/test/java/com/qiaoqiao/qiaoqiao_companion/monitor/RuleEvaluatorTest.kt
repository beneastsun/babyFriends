package com.qiaoqiao.qiaoqiao_companion.monitor

import org.junit.jupiter.api.Assertions.*
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.DisplayName
import org.junit.jupiter.api.Nested
import org.junit.jupiter.api.Test
import org.mockito.Mockito.*
import com.qiaoqiao.qiaoqiao_companion.monitor.NativeRuleRepository.*

/**
 * TDD tests for RuleEvaluator — a pure, stateless rule evaluator.
 *
 * All data comes from the mocked NativeRuleRepository.
 * The `now` parameter is passed explicitly so tests are deterministic.
 */
class RuleEvaluatorTest {

    private lateinit var repository: NativeRuleRepository
    private lateinit var evaluator: RuleEvaluator

    @BeforeEach
    fun setUp() {
        repository = mock(NativeRuleRepository::class.java)
        evaluator = RuleEvaluator(repository)
    }

    // ── Helpers ───────────────────────────────────────────────────
    private fun monitoredApp(pkg: String, dailyLimit: Int? = null) =
        MonitoredApp(pkg, dailyLimit)

    private fun timePeriod(mode: String, start: String, end: String, days: String = "[1,2,3,4,5,6,7]") =
        TimePeriod(mode, start, end, days)

    /** Stub the common "no forced rest" + "monitored app" setup. */
    private fun stubNoRestAndMonitored(app: MonitoredApp) {
        `when`(repository.getActiveRestRemainingSeconds()).thenReturn(0L)
        `when`(repository.getMonitoredApps()).thenReturn(listOf(app))
    }

    // ══════════════════════════════════════════════════════════════
    //  1. Non-monitored app is not blocked
    // ══════════════════════════════════════════════════════════════
    @Test
    @DisplayName("Non-monitored app is not blocked")
    fun nonMonitoredApp_notBlocked() {
        `when`(repository.getActiveRestRemainingSeconds()).thenReturn(0L)
        `when`(repository.getMonitoredApps()).thenReturn(emptyList())

        val result = evaluator.evaluate("com.example.unmonitored", 0L)

        assertFalse(result.blocked)
        assertEquals("", result.reason)
        assertEquals("", result.ruleType)
    }

    // ══════════════════════════════════════════════════════════════
    //  2. Monitored app during forced rest is blocked
    // ══════════════════════════════════════════════════════════════
    @Test
    @DisplayName("Monitored app during forced rest is blocked")
    fun monitoredApp_forcedRest_blocked() {
        `when`(repository.getActiveRestRemainingSeconds()).thenReturn(300L)

        val result = evaluator.evaluate("com.game.app", 0L)

        assertTrue(result.blocked)
        assertEquals("forced_rest", result.ruleType)
        // Verify that getMonitoredApps was never called since forced rest short-circuits
        verify(repository, never()).getMonitoredApps()
    }

    // ══════════════════════════════════════════════════════════════
    //  3. Monitored app blocked by time period (blocked mode)
    // ══════════════════════════════════════════════════════════════
    @Test
    @DisplayName("Monitored app blocked by blocked time period")
    fun monitoredApp_blockedTimePeriod_blocked() {
        stubNoRestAndMonitored(monitoredApp("com.game.app"))
        `when`(repository.getTimePeriods()).thenReturn(listOf(timePeriod("blocked", "08:00", "18:00")))
        `when`(repository.getCurrentTimeStr()).thenReturn("12:00")
        `when`(repository.getDayOfWeek()).thenReturn(2) // Tuesday

        val result = evaluator.evaluate("com.game.app", 0L)

        assertTrue(result.blocked)
        assertEquals("time_period", result.ruleType)
    }

    // ══════════════════════════════════════════════════════════════
    //  4. Monitored app NOT blocked when outside blocked time period
    // ══════════════════════════════════════════════════════════════
    @Test
    @DisplayName("Monitored app NOT blocked when outside blocked time period")
    fun monitoredApp_outsideBlockedTimePeriod_notBlocked() {
        stubNoRestAndMonitored(monitoredApp("com.game.app"))
        `when`(repository.getTimePeriods()).thenReturn(listOf(timePeriod("blocked", "08:00", "18:00")))
        `when`(repository.getCurrentTimeStr()).thenReturn("20:00")
        `when`(repository.getDayOfWeek()).thenReturn(2)
        `when`(repository.getTotalTimeRule()).thenReturn(null)

        val result = evaluator.evaluate("com.game.app", 0L)

        assertFalse(result.blocked)
    }

    // ══════════════════════════════════════════════════════════════
    //  5. Monitored app blocked by total time limit
    // ══════════════════════════════════════════════════════════════
    @Test
    @DisplayName("Monitored app blocked by total time limit")
    fun monitoredApp_totalTimeLimit_blocked() {
        stubNoRestAndMonitored(monitoredApp("com.game.app"))
        `when`(repository.getTimePeriods()).thenReturn(emptyList())
        `when`(repository.getTotalTimeRule()).thenReturn(TotalTimeRule(weekdayLimit = 60, weekendLimit = 120))
        `when`(repository.isWeekend()).thenReturn(false)
        // 61 minutes used = 3_660_000 ms, limit is 60 min
        `when`(repository.getTodayTotalUsageMs(setOf("com.game.app"))).thenReturn(3_660_000L)

        val result = evaluator.evaluate("com.game.app", 0L)

        assertTrue(result.blocked)
        assertEquals("total_time_limit", result.ruleType)
    }

    // ══════════════════════════════════════════════════════════════
    //  6. Monitored app blocked by per-app daily limit
    // ══════════════════════════════════════════════════════════════
    @Test
    @DisplayName("Monitored app blocked by per-app daily limit")
    fun monitoredApp_perAppDailyLimit_blocked() {
        stubNoRestAndMonitored(monitoredApp("com.game.app", dailyLimit = 30))
        `when`(repository.getTimePeriods()).thenReturn(emptyList())
        `when`(repository.getTotalTimeRule()).thenReturn(null)
        // 31 minutes used = 1_860_000 ms, limit is 30 min
        `when`(repository.getTodayAppUsageMs("com.game.app")).thenReturn(1_860_000L)

        val result = evaluator.evaluate("com.game.app", 0L)

        assertTrue(result.blocked)
        assertEquals("app_daily_limit", result.ruleType)
    }

    // ══════════════════════════════════════════════════════════════
    //  7. Monitored app allowed when no rules violated
    // ══════════════════════════════════════════════════════════════
    @Test
    @DisplayName("Monitored app allowed when no rules violated")
    fun monitoredApp_noRulesViolated_allowed() {
        stubNoRestAndMonitored(monitoredApp("com.game.app", dailyLimit = 60))
        `when`(repository.getTimePeriods()).thenReturn(emptyList())
        `when`(repository.getTotalTimeRule()).thenReturn(TotalTimeRule(weekdayLimit = 120, weekendLimit = 180))
        `when`(repository.isWeekend()).thenReturn(false)
        // 30 min total used out of 120 min limit
        `when`(repository.getTodayTotalUsageMs(setOf("com.game.app"))).thenReturn(1_800_000L)
        // 15 min app used out of 60 min limit
        `when`(repository.getTodayAppUsageMs("com.game.app")).thenReturn(900_000L)

        val result = evaluator.evaluate("com.game.app", 0L)

        assertFalse(result.blocked)
        assertEquals("", result.reason)
        assertEquals("", result.ruleType)
    }

    // ══════════════════════════════════════════════════════════════
    //  8. "allowed" time period mode — blocked when NOT in any allowed period
    // ══════════════════════════════════════════════════════════════
    @Test
    @DisplayName("Allowed mode: blocked when NOT in any allowed period")
    fun monitoredApp_allowedMode_notInAllowedPeriod_blocked() {
        stubNoRestAndMonitored(monitoredApp("com.game.app"))
        `when`(repository.getTimePeriods()).thenReturn(listOf(timePeriod("allowed", "10:00", "12:00")))
        `when`(repository.getCurrentTimeStr()).thenReturn("14:00")
        `when`(repository.getDayOfWeek()).thenReturn(3) // Wednesday

        val result = evaluator.evaluate("com.game.app", 0L)

        assertTrue(result.blocked)
        assertEquals("time_period", result.ruleType)
    }

    // ══════════════════════════════════════════════════════════════
    //  9. "allowed" time period mode — allowed when IN an allowed period
    // ══════════════════════════════════════════════════════════════
    @Test
    @DisplayName("Allowed mode: allowed when IN an allowed period")
    fun monitoredApp_allowedMode_inAllowedPeriod_allowed() {
        stubNoRestAndMonitored(monitoredApp("com.game.app"))
        `when`(repository.getTimePeriods()).thenReturn(listOf(timePeriod("allowed", "10:00", "16:00")))
        `when`(repository.getCurrentTimeStr()).thenReturn("13:00")
        `when`(repository.getDayOfWeek()).thenReturn(3)
        `when`(repository.getTotalTimeRule()).thenReturn(null)

        val result = evaluator.evaluate("com.game.app", 0L)

        assertFalse(result.blocked)
    }

    // ══════════════════════════════════════════════════════════════
    //  Additional edge-case tests
    // ══════════════════════════════════════════════════════════════

    @Nested
    @DisplayName("Time period day matching")
    inner class DayMatching {

        @Test
        @DisplayName("Blocked period does not apply on non-matching day")
        fun blockedPeriod_wrongDay_notBlocked() {
            stubNoRestAndMonitored(monitoredApp("com.game.app"))
            // Only weekdays — Calendar convention: 1=Sun,2=Mon,...,7=Sat
            // Using [2,3,4,5,6] for Mon-Fri in Calendar convention
            `when`(repository.getTimePeriods()).thenReturn(
                listOf(timePeriod("blocked", "08:00", "18:00", "[2,3,4,5,6]"))
            )
            `when`(repository.getCurrentTimeStr()).thenReturn("12:00")
            `when`(repository.getDayOfWeek()).thenReturn(1) // Sunday — not in [2,3,4,5,6]
            `when`(repository.getTotalTimeRule()).thenReturn(null)

            val result = evaluator.evaluate("com.game.app", 0L)

            assertFalse(result.blocked)
        }

        @Test
        @DisplayName("Blocked period applies on matching day")
        fun blockedPeriod_matchingDay_blocked() {
            stubNoRestAndMonitored(monitoredApp("com.game.app"))
            `when`(repository.getTimePeriods()).thenReturn(
                listOf(timePeriod("blocked", "08:00", "18:00", "[2,3,4,5,6]"))
            )
            `when`(repository.getCurrentTimeStr()).thenReturn("12:00")
            `when`(repository.getDayOfWeek()).thenReturn(3) // Tuesday — in [2,3,4,5,6]

            val result = evaluator.evaluate("com.game.app", 0L)

            assertTrue(result.blocked)
            assertEquals("time_period", result.ruleType)
        }
    }

    @Nested
    @DisplayName("Total time limit with weekend/weekday distinction")
    inner class TotalTimeLimitWeekend {

        @Test
        @DisplayName("Weekend limit applies on Saturday")
        fun totalTimeLimit_weekend_blocked() {
            stubNoRestAndMonitored(monitoredApp("com.game.app"))
            `when`(repository.getTimePeriods()).thenReturn(emptyList())
            `when`(repository.getTotalTimeRule()).thenReturn(TotalTimeRule(weekdayLimit = 60, weekendLimit = 90))
            `when`(repository.isWeekend()).thenReturn(true)
            // 91 min used > 90 min weekend limit
            `when`(repository.getTodayTotalUsageMs(setOf("com.game.app"))).thenReturn(5_460_000L)

            val result = evaluator.evaluate("com.game.app", 0L)

            assertTrue(result.blocked)
            assertEquals("total_time_limit", result.ruleType)
        }

        @Test
        @DisplayName("Weekday limit applies on Monday")
        fun totalTimeLimit_weekday_notBlocked() {
            stubNoRestAndMonitored(monitoredApp("com.game.app"))
            `when`(repository.getTimePeriods()).thenReturn(emptyList())
            `when`(repository.getTotalTimeRule()).thenReturn(TotalTimeRule(weekdayLimit = 60, weekendLimit = 90))
            `when`(repository.isWeekend()).thenReturn(false)
            // 30 min used < 60 min weekday limit
            `when`(repository.getTodayTotalUsageMs(setOf("com.game.app"))).thenReturn(1_800_000L)
            `when`(repository.getTodayAppUsageMs("com.game.app")).thenReturn(1_800_000L)

            val result = evaluator.evaluate("com.game.app", 0L)

            assertFalse(result.blocked)
        }
    }

    @Nested
    @DisplayName("Priority order: forced rest > monitored check > time period > total time > per-app")
    inner class PriorityOrder {

        @Test
        @DisplayName("Forced rest takes priority over all other rules")
        fun forcedRest_highestPriority() {
            `when`(repository.getActiveRestRemainingSeconds()).thenReturn(120L)

            val result = evaluator.evaluate("com.game.app", 0L)

            assertTrue(result.blocked)
            assertEquals("forced_rest", result.ruleType)
            // Verify that getMonitoredApps was never called since forced rest short-circuits
            verify(repository, never()).getMonitoredApps()
        }

        @Test
        @DisplayName("Time period takes priority over total time limit")
        fun timePeriod_beforeTotalTime() {
            stubNoRestAndMonitored(monitoredApp("com.game.app"))
            `when`(repository.getTimePeriods()).thenReturn(listOf(timePeriod("blocked", "08:00", "18:00")))
            `when`(repository.getCurrentTimeStr()).thenReturn("10:00")
            `when`(repository.getDayOfWeek()).thenReturn(2)

            val result = evaluator.evaluate("com.game.app", 0L)

            assertTrue(result.blocked)
            assertEquals("time_period", result.ruleType)
            // Total time rule should NOT be queried since time period already blocked
            verify(repository, never()).getTotalTimeRule()
        }

        @Test
        @DisplayName("Total time limit takes priority over per-app daily limit")
        fun totalTime_beforePerAppLimit() {
            stubNoRestAndMonitored(monitoredApp("com.game.app", dailyLimit = 30))
            `when`(repository.getTimePeriods()).thenReturn(emptyList())
            `when`(repository.getTotalTimeRule()).thenReturn(TotalTimeRule(weekdayLimit = 60, weekendLimit = 120))
            `when`(repository.isWeekend()).thenReturn(false)
            // Total time exceeded
            `when`(repository.getTodayTotalUsageMs(setOf("com.game.app"))).thenReturn(3_660_000L)

            val result = evaluator.evaluate("com.game.app", 0L)

            assertTrue(result.blocked)
            assertEquals("total_time_limit", result.ruleType)
            // Per-app usage should NOT be queried since total time already blocked
            verify(repository, never()).getTodayAppUsageMs("com.game.app")
        }
    }

    @Nested
    @DisplayName("Cross-midnight time period")
    inner class CrossMidnight {

        @Test
        @DisplayName("Blocked period spanning midnight (22:00-06:00) blocks at 23:00")
        fun crossMidnight_blockedPeriod_beforeMidnight() {
            stubNoRestAndMonitored(monitoredApp("com.game.app"))
            `when`(repository.getTimePeriods()).thenReturn(listOf(timePeriod("blocked", "22:00", "06:00")))
            `when`(repository.getCurrentTimeStr()).thenReturn("23:00")
            `when`(repository.getDayOfWeek()).thenReturn(2)

            val result = evaluator.evaluate("com.game.app", 0L)

            assertTrue(result.blocked)
            assertEquals("time_period", result.ruleType)
        }

        @Test
        @DisplayName("Blocked period spanning midnight (22:00-06:00) blocks at 03:00")
        fun crossMidnight_blockedPeriod_afterMidnight() {
            stubNoRestAndMonitored(monitoredApp("com.game.app"))
            `when`(repository.getTimePeriods()).thenReturn(listOf(timePeriod("blocked", "22:00", "06:00")))
            `when`(repository.getCurrentTimeStr()).thenReturn("03:00")
            `when`(repository.getDayOfWeek()).thenReturn(2)

            val result = evaluator.evaluate("com.game.app", 0L)

            assertTrue(result.blocked)
            assertEquals("time_period", result.ruleType)
        }

        @Test
        @DisplayName("Blocked period spanning midnight (22:00-06:00) does NOT block at 10:00")
        fun crossMidnight_blockedPeriod_outsideRange() {
            stubNoRestAndMonitored(monitoredApp("com.game.app"))
            `when`(repository.getTimePeriods()).thenReturn(listOf(timePeriod("blocked", "22:00", "06:00")))
            `when`(repository.getCurrentTimeStr()).thenReturn("10:00")
            `when`(repository.getDayOfWeek()).thenReturn(2)
            `when`(repository.getTotalTimeRule()).thenReturn(null)

            val result = evaluator.evaluate("com.game.app", 0L)

            assertFalse(result.blocked)
        }
    }

    @Nested
    @DisplayName("Per-app daily limit edge cases")
    inner class PerAppDailyLimit {

        @Test
        @DisplayName("App with null dailyLimit is not blocked by per-app limit")
        fun nullDailyLimit_notBlockedByPerApp() {
            stubNoRestAndMonitored(monitoredApp("com.game.app", dailyLimit = null))
            `when`(repository.getTimePeriods()).thenReturn(emptyList())
            `when`(repository.getTotalTimeRule()).thenReturn(null)

            val result = evaluator.evaluate("com.game.app", 0L)

            assertFalse(result.blocked)
            // getTodayAppUsageMs should NOT be called when dailyLimit is null
            verify(repository, never()).getTodayAppUsageMs("com.game.app")
        }

        @Test
        @DisplayName("App with zero dailyLimit is not blocked by per-app limit")
        fun zeroDailyLimit_notBlockedByPerApp() {
            stubNoRestAndMonitored(monitoredApp("com.game.app", dailyLimit = 0))
            `when`(repository.getTimePeriods()).thenReturn(emptyList())
            `when`(repository.getTotalTimeRule()).thenReturn(null)

            val result = evaluator.evaluate("com.game.app", 0L)

            assertFalse(result.blocked)
            verify(repository, never()).getTodayAppUsageMs("com.game.app")
        }

        @Test
        @DisplayName("App exactly at daily limit is blocked")
        fun exactlyAtDailyLimit_blocked() {
            stubNoRestAndMonitored(monitoredApp("com.game.app", dailyLimit = 30))
            `when`(repository.getTimePeriods()).thenReturn(emptyList())
            `when`(repository.getTotalTimeRule()).thenReturn(null)
            // Exactly 30 min = 1_800_000 ms
            `when`(repository.getTodayAppUsageMs("com.game.app")).thenReturn(1_800_000L)

            val result = evaluator.evaluate("com.game.app", 0L)

            assertTrue(result.blocked)
            assertEquals("app_daily_limit", result.ruleType)
        }
    }

    @Nested
    @DisplayName("Total time rule edge cases")
    inner class TotalTimeRuleEdgeCases {

        @Test
        @DisplayName("No total time rule means no total time block")
        fun noTotalTimeRule_notBlocked() {
            stubNoRestAndMonitored(monitoredApp("com.game.app"))
            `when`(repository.getTimePeriods()).thenReturn(emptyList())
            `when`(repository.getTotalTimeRule()).thenReturn(null)

            val result = evaluator.evaluate("com.game.app", 0L)

            assertFalse(result.blocked)
        }

        @Test
        @DisplayName("Total time rule with null limits means no total time block")
        fun totalTimeRule_nullLimits_notBlocked() {
            stubNoRestAndMonitored(monitoredApp("com.game.app"))
            `when`(repository.getTimePeriods()).thenReturn(emptyList())
            `when`(repository.getTotalTimeRule()).thenReturn(TotalTimeRule(null, null))
            `when`(repository.isWeekend()).thenReturn(false)

            val result = evaluator.evaluate("com.game.app", 0L)

            assertFalse(result.blocked)
        }

        @Test
        @DisplayName("Total time rule with zero limit means no total time block")
        fun totalTimeRule_zeroLimit_notBlocked() {
            stubNoRestAndMonitored(monitoredApp("com.game.app"))
            `when`(repository.getTimePeriods()).thenReturn(emptyList())
            `when`(repository.getTotalTimeRule()).thenReturn(TotalTimeRule(weekdayLimit = 0, weekendLimit = 0))
            `when`(repository.isWeekend()).thenReturn(false)

            val result = evaluator.evaluate("com.game.app", 0L)

            assertFalse(result.blocked)
        }
    }

    @Nested
    @DisplayName("Mixed blocked + allowed time periods")
    inner class MixedTimePeriods {

        @Test
        @DisplayName("Blocked period takes precedence over allowed period when both match")
        fun blockedOverridesAllowed_whenBothMatch() {
            stubNoRestAndMonitored(monitoredApp("com.game.app"))
            `when`(repository.getTimePeriods()).thenReturn(
                listOf(
                    timePeriod("allowed", "08:00", "20:00"),
                    timePeriod("blocked", "12:00", "14:00")
                )
            )
            `when`(repository.getCurrentTimeStr()).thenReturn("13:00")
            `when`(repository.getDayOfWeek()).thenReturn(2)

            val result = evaluator.evaluate("com.game.app", 0L)

            assertTrue(result.blocked)
            assertEquals("time_period", result.ruleType)
        }

        @Test
        @DisplayName("Allowed period permits when no blocked period matches but outside allowed = blocked")
        fun allowedPermits_whenNoBlockedMatches() {
            stubNoRestAndMonitored(monitoredApp("com.game.app"))
            `when`(repository.getTimePeriods()).thenReturn(
                listOf(
                    timePeriod("allowed", "10:00", "18:00"),
                    timePeriod("blocked", "12:00", "13:00")
                )
            )
            `when`(repository.getCurrentTimeStr()).thenReturn("09:00")
            `when`(repository.getDayOfWeek()).thenReturn(2)

            val result = evaluator.evaluate("com.game.app", 0L)

            // 09:00 is not in allowed period and not in blocked period
            // Since there IS an allowed period defined, being outside it means blocked
            assertTrue(result.blocked)
            assertEquals("time_period", result.ruleType)
        }
    }

    // ══════════════════════════════════════════════════════════════
    //  Time parsing utility tests (no mock interaction needed)
    // ══════════════════════════════════════════════════════════════

    @Nested
    @DisplayName("Time parsing utilities")
    inner class TimeParsing {

        @Test
        @DisplayName("timeToMinutes parses HH:mm correctly")
        fun timeToMinutes_correct() {
            assertEquals(0, evaluator.timeToMinutes("00:00"))
            assertEquals(480, evaluator.timeToMinutes("08:00"))
            assertEquals(720, evaluator.timeToMinutes("12:00"))
            assertEquals(1080, evaluator.timeToMinutes("18:00"))
            assertEquals(1380, evaluator.timeToMinutes("23:00"))
        }

        @Test
        @DisplayName("isTimeInRange for normal range (08:00-18:00)")
        fun isTimeInRange_normalRange() {
            assertTrue(evaluator.isTimeInRange("08:00", "08:00", "18:00"))
            assertTrue(evaluator.isTimeInRange("12:00", "08:00", "18:00"))
            assertTrue(evaluator.isTimeInRange("18:00", "08:00", "18:00"))
            assertFalse(evaluator.isTimeInRange("07:59", "08:00", "18:00"))
            assertFalse(evaluator.isTimeInRange("18:01", "08:00", "18:00"))
        }

        @Test
        @DisplayName("isTimeInRange for cross-midnight range (22:00-06:00)")
        fun isTimeInRange_crossMidnight() {
            assertTrue(evaluator.isTimeInRange("22:00", "22:00", "06:00"))
            assertTrue(evaluator.isTimeInRange("23:30", "22:00", "06:00"))
            assertTrue(evaluator.isTimeInRange("00:00", "22:00", "06:00"))
            assertTrue(evaluator.isTimeInRange("03:00", "22:00", "06:00"))
            assertTrue(evaluator.isTimeInRange("06:00", "22:00", "06:00"))
            assertFalse(evaluator.isTimeInRange("10:00", "22:00", "06:00"))
            assertFalse(evaluator.isTimeInRange("21:59", "22:00", "06:00"))
        }

        @Test
        @DisplayName("isDayMatch for JSON array format")
        fun isDayMatch_jsonArray() {
            assertTrue(evaluator.isDayMatch("[1,2,3,4,5,6,7]", 2))
            assertFalse(evaluator.isDayMatch("[1,7]", 2))
            assertTrue(evaluator.isDayMatch("[1,7]", 1))
        }

        @Test
        @DisplayName("isDayMatch for comma-separated format")
        fun isDayMatch_commaSeparated() {
            assertTrue(evaluator.isDayMatch("1,2,3,4,5,6,7", 3))
            assertFalse(evaluator.isDayMatch("1,7", 3))
        }

        @Test
        @DisplayName("isDayMatch defaults to true on parse failure")
        fun isDayMatch_parseFailure_defaultsTrue() {
            assertTrue(evaluator.isDayMatch("invalid", 2))
        }
    }
}
