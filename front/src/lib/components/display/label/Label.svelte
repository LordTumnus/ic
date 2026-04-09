<script lang="ts">
  let {
    id = '',
    text = $bindable(''),
    variant = $bindable('body'),
    size = $bindable('md'),
    weight = $bindable('normal'),
    align = $bindable('left'),
    color = $bindable('default'),
    truncate = $bindable(false),
    selectable = $bindable(true),
  }: {
    id?: string;
    text?: string;
    variant?: string;
    size?: string;
    weight?: string;
    align?: string;
    color?: string;
    truncate?: boolean;
    selectable?: boolean;
  } = $props();
</script>

<span
  {id}
  class="ic-label ic-label--{variant} ic-label--{size} ic-label--{weight} ic-label--{color}"
  class:ic-label--truncate={truncate}
  class:ic-label--no-select={!selectable}
  style:text-align={align}
>
  {text}
</span>

<style>
  .ic-label {
    display: inline-block;
    line-height: 1.4;
    font-family: inherit;
    font-variant-numeric: tabular-nums;
    max-width: 100%;
  }

  /* ── Variants ─────────────────────────────── */
  .ic-label--heading {
    font-weight: 600;
    line-height: 1.2;
    letter-spacing: -0.01em;
  }

  .ic-label--caption {
    line-height: 1.3;
    letter-spacing: 0.01em;
  }

  .ic-label--code {
    background-color: var(--ic-secondary);
    padding: 0.1em 0.35em;
    border-radius: 2px;
    box-shadow: inset 0 1px 2px rgba(0, 0, 0, 0.08);
  }

  .ic-label--overline {
    text-transform: uppercase;
    letter-spacing: 0.08em;
    font-weight: 600;
    line-height: 1.2;
  }

  /* ── Sizes ────────────────────────────────── */
  .ic-label--xs  { font-size: 0.625rem; }
  .ic-label--sm  { font-size: 0.75rem; }
  .ic-label--md  { font-size: 0.875rem; }
  .ic-label--lg  { font-size: 1rem; }
  .ic-label--xl  { font-size: 1.25rem; }
  .ic-label--2xl { font-size: 1.5rem; }
  .ic-label--3xl { font-size: 2rem; }

  /* ── Weights ──────────────────────────────── */
  .ic-label--normal   { font-weight: 400; }
  .ic-label--medium   { font-weight: 500; }
  .ic-label--semibold { font-weight: 600; }
  .ic-label--bold     { font-weight: 700; }

  /* ── Colors ───────────────────────────────── */
  .ic-label--default     { color: var(--ic-foreground); }
  .ic-label--muted       { color: var(--ic-muted-foreground); }
  .ic-label--primary     { color: var(--ic-primary); }
  .ic-label--destructive { color: var(--ic-destructive); }
  .ic-label--success     { color: var(--ic-success); }
  .ic-label--warning     { color: var(--ic-warning); }

  /* ── Modifiers ────────────────────────────── */
  .ic-label--truncate {
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .ic-label--no-select {
    user-select: none;
  }

</style>
