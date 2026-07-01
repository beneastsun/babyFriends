package com.qiaoqiao.qiaoqiao_companion.monitor

/**
 * Represents the current state of the EnforcementEngine.
 *
 * State transitions:
 *   IDLE -> COUNTDOWN (when a monitored app is detected)
 *   COUNTDOWN -> REST (when countdown reaches zero or a blocking rule is hit)
 *   COUNTDOWN -> IDLE (when the user leaves the monitored app long enough)
 *   REST -> IDLE (when the user dismisses the overlay or rest ends while away)
 */
enum class EngineState {
    /** No monitored app is in the foreground */
    IDLE,
    /** Countdown overlay is showing, approaching time limit */
    COUNTDOWN,
    /** Forced rest period in progress */
    REST
}
