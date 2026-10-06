// Copyright (C) 2026 Matt Comeione
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Prints the manual's HTML to a Letter-size PDF with page numbers, using
// Playwright's bundled Chromium. Run by scripts/render-manual.sh:
//   node render.js <manual.html> <out.pdf> <version>
const { chromium } = require('playwright');

(async () => {
  const [html, out, version] = process.argv.slice(2);
  const browser = await chromium.launch();
  const page = await browser.newPage();
  await page.goto('file://' + html);
  await page.pdf({
    path: out,
    format: 'Letter',
    printBackground: true,
    displayHeaderFooter: true,
    headerTemplate: '<span></span>',
    footerTemplate: '<div style="font-size:8pt;color:#6e6e73;width:100%;text-align:center;font-family:-apple-system,Helvetica">'
      + `fauxtoe ${version} User Manual · <span class="pageNumber"></span> of <span class="totalPages"></span></div>`,
    margin: { top: '0.8in', bottom: '0.9in', left: '0.85in', right: '0.85in' },
  });
  await browser.close();
})();
