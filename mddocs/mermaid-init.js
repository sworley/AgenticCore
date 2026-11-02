/* mermaid-init.js — Client-side Mermaid rendering for mdBook.
 * mdBook emits fenced `` ```mermaid `` blocks as `<pre><code class="language-mermaid">`.
 * This script finds those blocks and replaces each with the rendered SVG using the
 * mermaid bundle loaded from `mermaid.min.js` (see book.toml `additional-js`).
 */
window.addEventListener('load', function () {
  if (typeof mermaid === 'undefined') return;

  mermaid.initialize({
    startOnLoad: false,
    theme: 'default',
    securityLevel: 'loose',
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
