/* mermaid-init.js — Client-side Mermaid rendering for mdBook.
 * mdBook emits fenced `` ```mermaid `` blocks as `<pre><code class="language-mermaid">`.
 * This script finds those blocks and replaces each with the rendered SVG using the
 * mermaid bundle loaded from `mermaid.min.js` (see book.toml `additional-js`).
 *
 * The `base` theme with light node fills and dark text keeps diagrams readable on
 * both light and dark page backgrounds.
 */
window.addEventListener('load', function () {
  if (typeof mermaid === 'undefined') return;

  mermaid.initialize({
    startOnLoad: false,
    theme: 'base',
    themeVariables: {
      primaryColor: '#ffffff',
      primaryTextColor: '#1f2933',
      primaryBorderColor: '#52606d',
      lineColor: '#3e4c59',
      secondaryColor: '#f5f7fa',
      tertiaryColor: '#e4e7eb',
      clusterBkg: '#f5f7fa',
      clusterBorder: '#9aa5b1',
      fontFamily: 'ui-sans-serif, system-ui, sans-serif',
      fontSize: '16px',
    },
  });

  var blocks = document.querySelectorAll('pre > code.language-mermaid');
  blocks.forEach(function (node, i) {
    var pre = node.parentElement;
    var source = node.textContent.trim();
    var id = 'mermaid-figure-' + i;
    mermaid.render(id, source).then(function (result) {
      pre.outerHTML = result.svg;
    }).catch(function (err) {
      console.error('mermaid render failed for ' + id, err);
    });
  });
});
