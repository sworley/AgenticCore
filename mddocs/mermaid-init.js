/* mermaid-init.js — Mermaid initialization for mdBook.
 * Required alongside mermaid.min.js for diagram rendering.
 */
window.addEventListener('load', function() {
  mermaid.initialize({
    startOnLoad: true,
    theme: 'default',
    securityLevel: 'loose',
  });
});
