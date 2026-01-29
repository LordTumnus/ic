/**
 * Unit tests for the Logger service.
 *
 * Tests the Logger's behavior:
 * - Discarding logs when disabled
 * - Publishing logs when enabled
 * - Log level filtering
 * - Console fallback option
 */

import { describe, it, expect, beforeEach, vi } from 'vitest';
import logger from '$lib/core/logger';

describe('Logger', () => {
  beforeEach(() => {
    logger._reset();
  });

  describe('when disabled (default)', () => {
    it('discards logs by default', () => {
      const publisher = vi.fn();

      logger.info('Test', 'this should be discarded');

      // Enable after logging - publisher should not receive past logs
      logger.enable(publisher);
      expect(publisher).not.toHaveBeenCalled();
    });

    it('does not output to console by default', () => {
      const consoleSpy = vi.spyOn(console, 'info').mockImplementation(() => {});

      logger.info('Test', 'no console output');

      expect(consoleSpy).not.toHaveBeenCalled();
      consoleSpy.mockRestore();
    });

    it('outputs to console when consoleOutput is enabled', () => {
      const consoleSpy = vi.spyOn(console, 'warn').mockImplementation(() => {});

      logger.configure({ consoleOutput: true });
      logger.warn('Test', 'console warning');

      expect(consoleSpy).toHaveBeenCalledWith('[Test]', 'console warning');
      consoleSpy.mockRestore();
    });

    it('includes context in console output', () => {
      const consoleSpy = vi.spyOn(console, 'error').mockImplementation(() => {});

      logger.configure({ consoleOutput: true });
      logger.error('Test', 'error with context', { code: 42 });

      expect(consoleSpy).toHaveBeenCalledWith('[Test]', 'error with context', { code: 42 });
      consoleSpy.mockRestore();
    });
  });

  describe('when enabled', () => {
    it('publishes log entries', () => {
      const publisher = vi.fn();
      logger.enable(publisher);

      logger.warn('Bridge', 'test warning');

      expect(publisher).toHaveBeenCalledTimes(1);
      expect(publisher).toHaveBeenCalledWith(
        expect.objectContaining({
          level: 'warn',
          source: 'Bridge',
          message: 'test warning'
        })
      );
    });

    it('includes context in published entries', () => {
      const publisher = vi.fn();
      logger.enable(publisher);

      logger.error('Component', 'error message', { componentId: 'btn1', type: 'Button' });

      expect(publisher).toHaveBeenCalledWith(
        expect.objectContaining({
          level: 'error',
          context: { componentId: 'btn1', type: 'Button' }
        })
      );
    });

    it('includes timestamp in published entries', () => {
      const publisher = vi.fn();
      const before = Date.now();
      logger.enable(publisher);

      logger.info('Test', 'timestamped');

      const after = Date.now();
      const entry = publisher.mock.calls[0][0];
      expect(entry.timestamp).toBeGreaterThanOrEqual(before);
      expect(entry.timestamp).toBeLessThanOrEqual(after);
    });

    it('publishes all log levels', () => {
      const publisher = vi.fn();
      logger.enable(publisher);

      logger.debug('Test', 'debug message');
      logger.info('Test', 'info message');
      logger.warn('Test', 'warn message');
      logger.error('Test', 'error message');

      expect(publisher).toHaveBeenCalledTimes(4);
      expect(publisher.mock.calls[0][0].level).toBe('debug');
      expect(publisher.mock.calls[1][0].level).toBe('info');
      expect(publisher.mock.calls[2][0].level).toBe('warn');
      expect(publisher.mock.calls[3][0].level).toBe('error');
    });
  });

  describe('log level filtering', () => {
    it('respects minLevel configuration', () => {
      const publisher = vi.fn();
      logger.configure({ minLevel: 'warn' });
      logger.enable(publisher);

      logger.debug('Test', 'debug - filtered');
      logger.info('Test', 'info - filtered');
      logger.warn('Test', 'warn - included');
      logger.error('Test', 'error - included');

      expect(publisher).toHaveBeenCalledTimes(2);
      expect(publisher.mock.calls[0][0].level).toBe('warn');
      expect(publisher.mock.calls[1][0].level).toBe('error');
    });

    it('can change minLevel at runtime', () => {
      const publisher = vi.fn();
      logger.enable(publisher);

      logger.debug('Test', 'debug 1');
      logger.configure({ minLevel: 'error' });
      logger.debug('Test', 'debug 2 - filtered');
      logger.warn('Test', 'warn - filtered');
      logger.error('Test', 'error - included');

      expect(publisher).toHaveBeenCalledTimes(2);
      expect(publisher.mock.calls[0][0].message).toBe('debug 1');
      expect(publisher.mock.calls[1][0].message).toBe('error - included');
    });

    it('filters console output based on minLevel', () => {
      const debugSpy = vi.spyOn(console, 'debug').mockImplementation(() => {});
      const warnSpy = vi.spyOn(console, 'warn').mockImplementation(() => {});

      logger.configure({ consoleOutput: true, minLevel: 'warn' });

      logger.debug('Test', 'debug');
      logger.warn('Test', 'warn');

      expect(debugSpy).not.toHaveBeenCalled();
      expect(warnSpy).toHaveBeenCalled();

      debugSpy.mockRestore();
      warnSpy.mockRestore();
    });
  });

  describe('enable/disable', () => {
    it('isEnabled returns correct state', () => {
      expect(logger.isEnabled).toBe(false);

      logger.enable(() => {});
      expect(logger.isEnabled).toBe(true);

      logger.disable();
      expect(logger.isEnabled).toBe(false);
    });

    it('stops publishing after disable', () => {
      const publisher = vi.fn();
      logger.enable(publisher);

      logger.info('Test', 'before disable');
      logger.disable();
      logger.info('Test', 'after disable');

      expect(publisher).toHaveBeenCalledTimes(1);
    });

    it('can be re-enabled with new publisher', () => {
      const publisher1 = vi.fn();
      const publisher2 = vi.fn();

      logger.enable(publisher1);
      logger.info('Test', 'to publisher1');
      logger.disable();

      logger.enable(publisher2);
      logger.info('Test', 'to publisher2');

      expect(publisher1).toHaveBeenCalledTimes(1);
      expect(publisher2).toHaveBeenCalledTimes(1);
    });
  });

  describe('minLevel getter', () => {
    it('returns current minLevel', () => {
      expect(logger.minLevel).toBe('debug');

      logger.configure({ minLevel: 'error' });
      expect(logger.minLevel).toBe('error');
    });
  });
});
