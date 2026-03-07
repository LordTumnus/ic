/**
 * Logger - Singleton service for frontend logging with MATLAB bridge.
 *
 * When enabled (via Frame.Debug=true), logs are sent to MATLAB for inspection.
 * When disabled, logs are discarded (no buffering).
 *
 * Usage:
 *   import logger from './logger';
 *   logger.warn('Bridge', 'Error dispatching', { eventId: '...' });
 *   logger.error('Component', 'Failed to create', { id: '...' });
 */

export type LogLevel = 'debug' | 'info' | 'warn' | 'error';

export interface LogEntry {
  level: LogLevel;
  source: string;
  message: string;
  context: Record<string, unknown>;
  timestamp: number;
}

export interface LoggerConfig {
  /** Minimum level to log (default: 'debug') */
  minLevel: LogLevel;
  /** Also output to browser console when disabled (default: false) */
  consoleOutput: boolean;
}

const LEVEL_PRIORITY: Record<LogLevel, number> = {
  debug: 10,
  info: 20,
  warn: 30,
  error: 40
};

class Logger {
  private _enabled = false;
  private _config: LoggerConfig = {
    minLevel: 'debug',
    consoleOutput: false
  };
  private _publisher: ((entry: LogEntry) => void) | null = null;
  private _listeners: Set<(entry: LogEntry) => void> = new Set();

  /**
   * Enable logging to MATLAB.
   * Called when Frame.Debug becomes true.
   */
  enable(publisher: (entry: LogEntry) => void): void {
    this._enabled = true;
    this._publisher = publisher;
  }

  /**
   * Disable logging to MATLAB.
   * Called when Frame.Debug becomes false.
   */
  disable(): void {
    this._enabled = false;
    this._publisher = null;
  }

  /**
   * Add a listener that receives log entries regardless of enabled state.
   * Returns an unsubscribe function.
   */
  addListener(cb: (entry: LogEntry) => void): () => void {
    this._listeners.add(cb);
    return () => { this._listeners.delete(cb); };
  }

  /**
   * Configure logger options.
   */
  configure(options: Partial<LoggerConfig>): void {
    this._config = { ...this._config, ...options };
  }

  /**
   * Check if logging is enabled.
   */
  get isEnabled(): boolean {
    return this._enabled;
  }

  /**
   * Get current minimum log level.
   */
  get minLevel(): LogLevel {
    return this._config.minLevel;
  }

  // Core logging methods

  debug(source: string, message: string, context?: Record<string, unknown>): void {
    this._log('debug', source, message, context);
  }

  info(source: string, message: string, context?: Record<string, unknown>): void {
    this._log('info', source, message, context);
  }

  warn(source: string, message: string, context?: Record<string, unknown>): void {
    this._log('warn', source, message, context);
  }

  error(source: string, message: string, context?: Record<string, unknown>): void {
    this._log('error', source, message, context);
  }

  private _log(
    level: LogLevel,
    source: string,
    message: string,
    context?: Record<string, unknown>
  ): void {
    // Check minimum level
    if (LEVEL_PRIORITY[level] < LEVEL_PRIORITY[this._config.minLevel]) {
      return;
    }

    const entry: LogEntry = {
      level,
      source,
      message,
      context: context ?? {},
      timestamp: Date.now()
    };

    // Notify listeners regardless of enabled state (Console tab, etc.)
    for (const cb of this._listeners) cb(entry);

    if (this._enabled) {
      this._publish(entry);
    } else if (this._config.consoleOutput) {
      // Console fallback when disabled (for development)
      this._consoleOutput(entry);
    }
    // When disabled and consoleOutput=false, logs are discarded
  }

  private _publish(entry: LogEntry): void {
    if (this._publisher) {
      this._publisher(entry);
    }
  }

  private _consoleOutput(entry: LogEntry): void {
    const prefix = `[${entry.source}]`;
    const consoleMethod = console[entry.level] || console.log;
    // Only include context in console output if it has properties
    if (Object.keys(entry.context).length > 0) {
      consoleMethod(prefix, entry.message, entry.context);
    } else {
      consoleMethod(prefix, entry.message);
    }
  }

  /**
   * Reset for testing purposes.
   * @internal
   */
  _reset(): void {
    this._enabled = false;
    this._publisher = null;
    this._listeners.clear();
    this._config = {
      minLevel: 'debug',
      consoleOutput: false
    };
  }
}

// Export singleton instance
const logger = new Logger();
export default logger;
