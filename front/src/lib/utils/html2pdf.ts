/**
 * html2pdf — Shared utility for exporting an HTML element to PDF (base64).
 *
 * Uses html2canvas to rasterize the element, then jsPDF to paginate it
 * onto A4 pages. Returns a base64-encoded PDF string ready to send to
 * MATLAB for file writing.
 *
 * Usage:
 *   const base64 = await htmlToPdfBase64(element, { title: 'My Doc' });
 */
// Lazy-loaded to avoid bundling ~400KB into components that never export PDF
const loadHtml2Canvas = () => import('html2canvas').then((m) => m.default);
const loadJsPDF = () => import('jspdf').then((m) => m.jsPDF);

export interface HtmlToPdfOptions {
  /** PDF document title (metadata). */
  title?: string;
  /** Page margin in mm (default 10). */
  margin?: number;
  /** Canvas render scale factor (default 2 for retina-quality). */
  scale?: number;
  /** Page orientation (default 'portrait'). */
  orientation?: 'portrait' | 'landscape';
}

/**
 * Render an HTML element to a multi-page A4 PDF and return it as a
 * base64-encoded string (without the `data:` prefix).
 */
export async function htmlToPdfBase64(
  element: HTMLElement,
  options: HtmlToPdfOptions = {},
): Promise<string> {
  const {
    title = 'Document',
    margin = 10,
    scale = 2,
    orientation = 'portrait',
  } = options;

  // ── Clone element off-screen so we get the full unclipped content ──
  const clone = element.cloneNode(true) as HTMLElement;

  // Resolve CSS variables — the off-screen clone won't inherit them
  const computed = getComputedStyle(element);
  const vars = Array.from(computed).filter((p) => p.startsWith('--'));
  for (const v of vars) {
    clone.style.setProperty(v, computed.getPropertyValue(v));
  }

  // Ensure content is fully expanded (no overflow: hidden/clip, no scroll)
  clone.style.position = 'absolute';
  clone.style.left = '-9999px';
  clone.style.top = '0';
  clone.style.width = `${element.scrollWidth}px`;
  clone.style.height = 'auto';
  clone.style.overflow = 'visible';
  clone.style.maxHeight = 'none';

  document.body.appendChild(clone);

  try {
    // ── Lazy-load heavy dependencies ─────────────────────────────────
    const [html2canvas, JsPDF] = await Promise.all([loadHtml2Canvas(), loadJsPDF()]);

    // ── Rasterize to canvas ──────────────────────────────────────────
    const canvas = await html2canvas(clone, {
      scale,
      useCORS: true,
      logging: false,
      backgroundColor: computed.getPropertyValue('--ic-background') || '#ffffff',
    });

    // ── Build PDF from canvas ────────────────────────────────────────
    const pdf = new JsPDF({
      orientation,
      unit: 'mm',
      format: 'a4',
    });

    pdf.setProperties({ title });

    const pageW = pdf.internal.pageSize.getWidth();
    const pageH = pdf.internal.pageSize.getHeight();
    const contentW = pageW - margin * 2;
    const contentH = pageH - margin * 2;

    // Scale canvas image to fit page width
    const imgW = contentW;
    const imgH = (canvas.height / canvas.width) * contentW;

    // How many pages we need
    const totalPages = Math.ceil(imgH / contentH);

    for (let page = 0; page < totalPages; page++) {
      if (page > 0) pdf.addPage();

      // Slice the source canvas for this page
      const srcY = page * (contentH / imgH) * canvas.height;
      const srcH = Math.min(
        (contentH / imgH) * canvas.height,
        canvas.height - srcY,
      );

      const sliceCanvas = document.createElement('canvas');
      sliceCanvas.width = canvas.width;
      sliceCanvas.height = Math.ceil(srcH);

      const ctx = sliceCanvas.getContext('2d')!;
      ctx.drawImage(
        canvas,
        0, srcY, canvas.width, srcH,
        0, 0, canvas.width, srcH,
      );

      const sliceData = sliceCanvas.toDataURL('image/png');
      const sliceImgH = (srcH / canvas.height) * imgH;

      pdf.addImage(sliceData, 'PNG', margin, margin, imgW, sliceImgH);
    }

    // ── Extract base64 ───────────────────────────────────────────────
    // pdf.output('datauristring') returns "data:application/pdf;base64,..."
    // We want just the base64 part.
    const dataUri = pdf.output('datauristring');
    const base64 = dataUri.split(',')[1];
    return base64;
  } finally {
    document.body.removeChild(clone);
  }
}
