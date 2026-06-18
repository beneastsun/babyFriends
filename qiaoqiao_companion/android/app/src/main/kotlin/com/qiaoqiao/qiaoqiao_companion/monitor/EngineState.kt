package com.qiaoqiao.qiaoqiao_companion.monitor

/**
 * Represents the current state of the EnforcementEngine.
 *
 * State transitions:
 *   IDLE -> MONITORING (when a monitored app is detected)
 *   MONITORING -> COUNTDOWN (when continuous usage approaches limit)
 *   MONITORING -> AT_LIMIT (when total time limit is reached)
 *   COUNTDOWN -> AT_LIMIT (when countdown reaches zero)
 *   AT_LIMIT -> REST (when forced rest period begins)
 *   REST -> IDLE (when rest period ends)
 *   Any -> IDLE (when app switches away or monitor stops)
 */
enum class EngineState {
    /** No monitored app is in the foreground */
    IDLE,
    /** A monitored app is being tracked, within allowed time */
    MONITORING,
    /** Countdown overlay is showing, approaching time limit */
    COUNTDOWN,
    /** Time limit reached, lock overlay should be shown */
    AT_LIMIT,
    /** Forced rest period in progress */
    REST
}
