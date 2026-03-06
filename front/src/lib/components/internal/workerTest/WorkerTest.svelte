<!--
  WorkerTest — Diagnostic component for testing Web Worker support in CEF.

  Runs all 8 Worker creation methods on mount and displays results.
  Temporary — remove after investigation.
-->
<script lang="ts">
  import { onMount } from 'svelte';
  import { runWorkerTests, type WorkerTestReport } from '$lib/utils/worker-test';
  import type { PublishFn } from '$lib/types';

  let {
    publish,
  }: {
    publish?: PublishFn;
  } = $props();

  let report = $state<WorkerTestReport | null>(null);
  let running = $state(true);
  let errorMsg = $state<string | null>(null);

  onMount(() => {
    runWorkerTests()
      .then((r) => {
        report = r;
        running = false;
        publish?.('@event/testComplete', {
          value: {
            passed: r.results.filter((t) => t.success).length,
            total: r.results.length,
            results: r.results.map((t) => ({
              method: t.method,
              success: t.success,
              error: t.error ?? null,
              durationMs: Math.round(t.durationMs),
            })),
          },
        });
      })
      .catch((err) => {
        errorMsg = String(err);
        running = false;
      });
  });

  function passed(r: WorkerTestReport): number {
    return r.results.filter((t) => t.success).length;
  }
</script>

<div class="ic-wt">
  <div class="ic-wt__header">Web Worker Capability Test</div>

  {#if running}
    <div class="ic-wt__status">Running tests...</div>
  {:else if errorMsg}
    <div class="ic-wt__status ic-wt__status--error">Error: {errorMsg}</div>
  {:else if report}
    <div class="ic-wt__meta">
      <span>Protocol: {report.protocol}</span>
      <span class="ic-wt__sep">|</span>
      <span>Passed: {passed(report)}/{report.results.length}</span>
    </div>
    <table class="ic-wt__table">
      <thead>
        <tr>
          <th>Method</th>
          <th>Result</th>
          <th>Time</th>
          <th>Error</th>
        </tr>
      </thead>
      <tbody>
        {#each report.results as result (result.method)}
          <tr class={result.success ? 'ic-wt__row--pass' : 'ic-wt__row--fail'}>
            <td class="ic-wt__method">{result.method}</td>
            <td class="ic-wt__result">{result.success ? 'PASS' : 'FAIL'}</td>
            <td class="ic-wt__time">{result.durationMs.toFixed(0)}ms</td>
            <td class="ic-wt__error">{result.error ?? '-'}</td>
          </tr>
        {/each}
      </tbody>
    </table>
  {/if}
</div>

<style>
  .ic-wt {
    font-family: var(--ic-font-mono, 'Roboto Mono', monospace);
    font-size: 12px;
    padding: 12px;
    background: var(--ic-background, #fff);
    color: var(--ic-foreground, #1a1a1a);
    border: 1px solid var(--ic-border, #ccc);
    border-radius: 2px;
  }
  .ic-wt__header {
    font-size: 14px;
    font-weight: 600;
    margin-bottom: 8px;
    padding-bottom: 6px;
    border-bottom: 1px solid var(--ic-border, #ccc);
  }
  .ic-wt__meta {
    display: flex;
    gap: 8px;
    margin-bottom: 8px;
    color: var(--ic-muted-foreground, #666);
  }
  .ic-wt__sep {
    opacity: 0.4;
  }
  .ic-wt__status {
    padding: 8px 0;
  }
  .ic-wt__status--error {
    color: var(--ic-destructive, #d33);
  }
  .ic-wt__table {
    width: 100%;
    border-collapse: collapse;
  }
  .ic-wt__table th,
  .ic-wt__table td {
    text-align: left;
    padding: 4px 8px;
    border-bottom: 1px solid var(--ic-border, #e0e0e0);
  }
  .ic-wt__table th {
    font-weight: 600;
    background: var(--ic-secondary, #f5f5f5);
  }
  .ic-wt__method {
    font-weight: 500;
  }
  .ic-wt__row--pass .ic-wt__result {
    color: var(--ic-success, #2a2);
    font-weight: 600;
  }
  .ic-wt__row--fail .ic-wt__result {
    color: var(--ic-destructive, #d33);
    font-weight: 600;
  }
  .ic-wt__time {
    font-variant-numeric: tabular-nums;
  }
  .ic-wt__error {
    max-width: 400px;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    color: var(--ic-muted-foreground, #888);
    font-size: 11px;
  }
</style>
