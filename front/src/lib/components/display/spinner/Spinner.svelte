<script lang="ts">
  let {
    kind = $bindable('ring'),
    size = $bindable('md'),
    variant = $bindable('primary'),
    speed = $bindable('normal'),
  }: {
    kind?: string;
    size?: string;
    variant?: string;
    speed?: string;
  } = $props();

  /* ── Size → pixel map ── */
  const sizeMap: Record<string, number> = { sm: 20, md: 32, lg: 48 };
  const px = $derived(sizeMap[size] ?? sizeMap.md);

  /* ── Speed → duration multiplier ── */
  const speedMap: Record<string, number> = { slow: 1.5, normal: 1, fast: 0.6 };
  const mult = $derived(speedMap[speed] ?? 1);

  /* ── Base durations per variant (seconds) ── */
  const baseDurations: Record<string, number> = {
    bars: 1.0,
    'dots-wave': 0.8,
    'dots-line': 1.0,
    ring: 0.85,
    pulse: 1.4,
    orbit: 1.0,
    grid: 1.2,
    'dual-ring': 1.0,
    cube: 2.0,
  };
  const dur = $derived((baseDurations[kind] ?? 1) * mult);

  /* ── Cube: half-size for translateZ ── */
  const cubeDepth = $derived(px * 0.275);

  /* ── Bars: 12 radial bars ── */
  const barCount = 12;
  const bars = Array.from({ length: barCount }, (_, i) => i);
</script>

<div
  class="ic-spinner"
  class:ic-spinner--primary={variant === 'primary'}
  class:ic-spinner--secondary={variant === 'secondary'}
  class:ic-spinner--success={variant === 'success'}
  class:ic-spinner--warning={variant === 'warning'}
  class:ic-spinner--destructive={variant === 'destructive'}
  style:width="{px}px"
  style:height="{px}px"
  style:--spinner-dur="{dur}s"
  role="status"
  aria-label="Loading"
>
  <!-- ════════════ bars ════════════ -->
  {#if kind === 'bars'}
    <div class="ic-spinner__bars">
      {#each bars as i (i)}
        <div
          class="ic-spinner__bar"
          style:transform="rotate({i * 30}deg) translateY(-130%)"
          style:animation-delay="{-((barCount - i) / barCount) * dur}s"
          style:animation-duration="{dur}s"
        ></div>
      {/each}
    </div>

  <!-- ════════════ dots-wave ════════════ -->
  {:else if kind === 'dots-wave'}
    <div class="ic-spinner__dots-wave">
      <div class="ic-spinner__dot" style:animation-delay="0s" style:animation-duration="{dur}s"></div>
      <div class="ic-spinner__dot" style:animation-delay="{dur * 0.2}s" style:animation-duration="{dur}s"></div>
      <div class="ic-spinner__dot" style:animation-delay="{dur * 0.4}s" style:animation-duration="{dur}s"></div>
    </div>

  <!-- ════════════ dots-line ════════════ -->
  {:else if kind === 'dots-line'}
    <div class="ic-spinner__dots-line">
      {#each [0, 1, 2, 3, 4] as i (i)}
        <div
          class="ic-spinner__dot-line"
          style:animation-delay="{i * (dur / 5)}s"
          style:animation-duration="{dur}s"
        ></div>
      {/each}
    </div>

  <!-- ════════════ ring ════════════ -->
  {:else if kind === 'ring'}
    <div class="ic-spinner__ring" style:animation-duration="{dur}s">
      <div class="ic-spinner__ring-arc"></div>
      <div class="ic-spinner__ring-trail"></div>
    </div>

  <!-- ════════════ pulse ════════════ -->
  {:else if kind === 'pulse'}
    <div class="ic-spinner__pulse">
      <div class="ic-spinner__pulse-ring" style:animation-duration="{dur}s" style:animation-delay="0s"></div>
      <div class="ic-spinner__pulse-ring" style:animation-duration="{dur}s" style:animation-delay="{dur * 0.5}s"></div>
    </div>

  <!-- ════════════ orbit ════════════ -->
  {:else if kind === 'orbit'}
    <div class="ic-spinner__orbit">
      <div class="ic-spinner__orbit-track"></div>
      <div class="ic-spinner__orbit-wrapper" style:animation-duration="{dur}s">
        <div class="ic-spinner__orbit-dot"></div>
      </div>
    </div>

  <!-- ════════════ grid ════════════ -->
  {:else if kind === 'grid'}
    <div class="ic-spinner__grid">
      {#each [0, 1, 2, 3, 4, 5, 6, 7, 8] as i (i)}
        <div
          class="ic-spinner__grid-cell"
          style:animation-delay="{(Math.floor(i / 3) + (i % 3)) * (dur / 6)}s"
          style:animation-duration="{dur}s"
        ></div>
      {/each}
    </div>

  <!-- ════════════ dual-ring ════════════ -->
  {:else if kind === 'dual-ring'}
    <div class="ic-spinner__dual-ring">
      <div class="ic-spinner__dual-outer" style:animation-duration="{dur}s"></div>
      <div class="ic-spinner__dual-inner" style:animation-duration="{dur * 0.75}s"></div>
    </div>

  <!-- ════════════ cube ════════════ -->
  {:else if kind === 'cube'}
    <div class="ic-spinner__cube" style:animation-duration="{dur}s" style:--cube-depth="{cubeDepth}px">
      <div class="ic-spinner__cube-face"></div>
      <div class="ic-spinner__cube-face"></div>
      <div class="ic-spinner__cube-face"></div>
      <div class="ic-spinner__cube-face"></div>
      <div class="ic-spinner__cube-face"></div>
      <div class="ic-spinner__cube-face"></div>
    </div>
  {/if}
</div>

<style>
  /* ── Root container ── */
  .ic-spinner {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    position: relative;
    overflow: hidden;
    --spinner-color: var(--ic-primary);
  }

  /* ── Color variants ── */
  .ic-spinner--primary  { --spinner-color: var(--ic-primary); }
  .ic-spinner--secondary { --spinner-color: var(--ic-muted-foreground); }
  .ic-spinner--success  { --spinner-color: var(--ic-success); }
  .ic-spinner--warning  { --spinner-color: var(--ic-warning); }
  .ic-spinner--destructive { --spinner-color: var(--ic-destructive); }

  /* ════════════════════════════════════════
     BARS — 12 radial bars (iOS-style)
     ════════════════════════════════════════ */
  .ic-spinner__bars {
    position: relative;
    width: 100%;
    height: 100%;
  }

  .ic-spinner__bar {
    position: absolute;
    left: calc(50% - 1.5px);
    top: 50%;
    width: 3px;
    height: 22%;
    border-radius: 2px;
    background-color: var(--spinner-color);
    transform-origin: center top;
    animation: ic-spinner-bar-fade linear infinite;
    will-change: opacity;
  }

  @keyframes ic-spinner-bar-fade {
    0%, 100% { opacity: 0.15; }
    8%       { opacity: 1; }
    50%      { opacity: 0.15; }
  }

  /* ════════════════════════════════════════
     DOTS-WAVE — 3 bouncing dots
     ════════════════════════════════════════ */
  .ic-spinner__dots-wave {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 15%;
    width: 100%;
    height: 100%;
  }

  .ic-spinner__dot {
    width: 24%;
    height: 24%;
    border-radius: 50%;
    background-color: var(--spinner-color);
    animation: ic-spinner-bounce ease-in-out infinite;
    will-change: transform;
  }

  @keyframes ic-spinner-bounce {
    0%, 100% { transform: translateY(0); }
    50%      { transform: translateY(-60%); }
  }

  /* ════════════════════════════════════════
     DOTS-LINE — 5 pulsing dots
     ════════════════════════════════════════ */
  .ic-spinner__dots-line {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 8%;
    width: 100%;
    height: 100%;
  }

  .ic-spinner__dot-line {
    width: 14%;
    height: 14%;
    border-radius: 50%;
    background-color: var(--spinner-color);
    animation: ic-spinner-dot-pulse ease-in-out infinite;
    will-change: transform, opacity;
  }

  @keyframes ic-spinner-dot-pulse {
    0%, 100% { transform: scale(0.4); opacity: 0.25; }
    40%      { transform: scale(1);   opacity: 1; }
  }

  /* ════════════════════════════════════════
     RING — Arc spinning with trail
     ════════════════════════════════════════ */
  .ic-spinner__ring {
    position: relative;
    width: 100%;
    height: 100%;
    animation: ic-spinner-rotate linear infinite;
  }

  .ic-spinner__ring-arc,
  .ic-spinner__ring-trail {
    position: absolute;
    inset: 0;
    border-radius: 50%;
    border-style: solid;
  }

  .ic-spinner__ring-trail {
    border-width: 2.5px;
    border-color: var(--spinner-color);
    opacity: 0.15;
    box-shadow: inset 0 1px 2px rgba(0, 0, 0, 0.12);
  }

  .ic-spinner__ring-arc {
    border-width: 2.5px;
    border-color: var(--spinner-color) transparent transparent transparent;
    opacity: 0.9;
  }

  @keyframes ic-spinner-rotate {
    from { transform: rotate(0deg); }
    to   { transform: rotate(360deg); }
  }

  /* ════════════════════════════════════════
     PULSE — Expanding rings
     ════════════════════════════════════════ */
  .ic-spinner__pulse {
    position: relative;
    width: 100%;
    height: 100%;
  }

  .ic-spinner__pulse-ring {
    position: absolute;
    inset: 0;
    border-radius: 50%;
    border: 2px solid var(--spinner-color);
    animation: ic-spinner-pulse-expand ease-out infinite;
    will-change: transform, opacity;
  }

  @keyframes ic-spinner-pulse-expand {
    0%   { transform: scale(0.2); opacity: 0.9; }
    100% { transform: scale(1.0); opacity: 0; }
  }

  /* ════════════════════════════════════════
     ORBIT — Dot circling a track
     ════════════════════════════════════════ */
  .ic-spinner__orbit {
    position: relative;
    width: 100%;
    height: 100%;
  }

  .ic-spinner__orbit-track {
    position: absolute;
    inset: 10%;
    border-radius: 50%;
    border: 1.5px solid var(--spinner-color);
    opacity: 0.15;
    box-shadow: inset 0 1px 2px rgba(0, 0, 0, 0.12);
  }

  .ic-spinner__orbit-wrapper {
    position: absolute;
    inset: 10%;
    animation: ic-spinner-rotate linear infinite;
  }

  .ic-spinner__orbit-dot {
    position: absolute;
    top: -4%;
    left: 50%;
    width: 18%;
    height: 18%;
    margin-left: -9%;
    border-radius: 50%;
    background-color: var(--spinner-color);
    box-shadow:
      0 1px 3px rgba(0, 0, 0, 0.2),
      inset 0 1px 0 rgba(255, 255, 255, 0.15);
  }

  /* ════════════════════════════════════════
     GRID — 3x3 pulsing squares
     ════════════════════════════════════════ */
  .ic-spinner__grid {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 8%;
    width: 80%;
    height: 80%;
  }

  .ic-spinner__grid-cell {
    border-radius: 2px;
    background-color: var(--spinner-color);
    animation: ic-spinner-grid-pulse ease-in-out infinite;
    will-change: transform, opacity;
  }

  @keyframes ic-spinner-grid-pulse {
    0%, 100% { transform: scale(0.55); opacity: 0.2; }
    40%      { transform: scale(1);    opacity: 0.85; }
  }

  /* ════════════════════════════════════════
     DUAL-RING — Counter-rotating rings
     ════════════════════════════════════════ */
  .ic-spinner__dual-ring {
    position: relative;
    width: 100%;
    height: 100%;
  }

  .ic-spinner__dual-outer {
    position: absolute;
    inset: 0;
    border-radius: 50%;
    border: 2.5px solid transparent;
    border-top-color: var(--spinner-color);
    border-right-color: var(--spinner-color);
    opacity: 0.85;
    animation: ic-spinner-rotate linear infinite;
  }

  .ic-spinner__dual-inner {
    position: absolute;
    inset: 20%;
    border-radius: 50%;
    border: 2px solid transparent;
    border-bottom-color: var(--spinner-color);
    border-left-color: var(--spinner-color);
    opacity: 0.6;
    animation: ic-spinner-rotate linear infinite reverse;
  }

  /* ════════════════════════════════════════
     CUBE — 3D rotating wireframe cube
     ════════════════════════════════════════ */
  .ic-spinner__cube {
    width: 55%;
    height: 55%;
    transform-style: preserve-3d;
    animation: ic-spinner-cube-rotate ease infinite;
  }

  .ic-spinner__cube-face {
    position: absolute;
    width: 100%;
    height: 100%;
    border: 2px solid var(--spinner-color);
    border-radius: 2px;
  }

  /* Semi-transparent fill via pseudo-element (keeps border at full opacity) */
  .ic-spinner__cube-face::before {
    content: '';
    position: absolute;
    inset: 0;
    background-color: var(--spinner-color);
    opacity: 0.12;
  }

  .ic-spinner__cube-face:nth-child(1) {
    transform: translateZ(calc(-1 * var(--cube-depth))) rotateY(180deg);
  }
  .ic-spinner__cube-face:nth-child(2) {
    transform: rotateY(-270deg) translateX(50%);
    transform-origin: top right;
  }
  .ic-spinner__cube-face:nth-child(3) {
    transform: rotateY(270deg) translateX(-50%);
    transform-origin: center left;
  }
  .ic-spinner__cube-face:nth-child(4) {
    transform: rotateX(90deg) translateY(-50%);
    transform-origin: top center;
  }
  .ic-spinner__cube-face:nth-child(5) {
    transform: rotateX(-90deg) translateY(50%);
    transform-origin: bottom center;
  }
  .ic-spinner__cube-face:nth-child(6) {
    transform: translateZ(var(--cube-depth));
  }

  @keyframes ic-spinner-cube-rotate {
    0%   { transform: rotate(45deg) rotateX(-25deg) rotateY(25deg); }
    50%  { transform: rotate(45deg) rotateX(-385deg) rotateY(25deg); }
    100% { transform: rotate(45deg) rotateX(-385deg) rotateY(385deg); }
  }
</style>
