/* Open off-site HTTP(S) links in a new tab while preserving local book navigation. */
(function mddocExternalLinks() {
    'use strict';

    function setExternalTarget(link) {
        if (!link || !link.href) {
            return;
        }

        let url;
        try {
            url = new URL(link.href, window.location.href);
        } catch (error) {
            return;
        }

        if (!['http:', 'https:'].includes(url.protocol)) {
            return;
        }

        if (url.origin === window.location.origin) {
            link.target = '_self';
            return;
        }

        link.target = '_blank';
        const rel = new Set((link.rel || '').split(/\s+/).filter(Boolean));
        rel.add('noopener');
        rel.add('noreferrer');
        link.rel = Array.from(rel).join(' ');
    }

    function scan(node) {
        if (node.matches && node.matches('a[href]')) {
            setExternalTarget(node);
        }
        if (node.querySelectorAll) {
            node.querySelectorAll('a[href]').forEach(setExternalTarget);
        }
    }

    scan(document);
    new MutationObserver(records => {
        records.forEach(record => {
            if (record.type === 'attributes') {
                setExternalTarget(record.target);
            } else {
                record.addedNodes.forEach(scan);
            }
        });
    }).observe(document.documentElement, {
        attributes: true,
        attributeFilter: ['href'],
        childList: true,
        subtree: true,
    });
})();
