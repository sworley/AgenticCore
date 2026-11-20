/*
 * Documentation mdBook sidebar controls.
 *
 * The default mdBook theme already hides nested lists when their parent lacks
 * the `expanded` class. This enhancement adds keyboard-accessible controls,
 * collapses inactive branches on first load, and persists operator choices.
 */
(function mddocCollapsibleSidebar() {
    'use strict';

    const stateKey = 'mddoc-mdbook-sidebar-sections-v1';

    function readState() {
        try {
            const value = window.localStorage.getItem(stateKey);
            return value ? JSON.parse(value) : {};
        } catch (error) {
            return {};
        }
    }

    function writeState(items) {
        const state = {};
        items.forEach(item => {
            state[item.key] = item.li.classList.contains('expanded');
        });
        try {
            window.localStorage.setItem(stateKey, JSON.stringify(state));
        } catch (error) {
            // Private browsing or a restricted file:// context may deny storage.
        }
    }

    function setup() {
        const sidebar = document.getElementById('mdbook-sidebar');
        const chapter = sidebar && sidebar.querySelector('ol.chapter');
        if (!chapter || chapter.dataset.mddocSidebarReady === 'true') {
            return;
        }
        chapter.dataset.mddocSidebarReady = 'true';

        const items = [];
        const candidates = chapter.querySelectorAll('li.chapter-item');
        candidates.forEach((li, index) => {
            const childList = Array.from(li.children)
                .find(child => child.matches && child.matches('ol.section'));
            const wrapper = Array.from(li.children)
                .find(child => child.matches && child.matches('.chapter-link-wrapper'));
            if (!childList || !wrapper) {
                return;
            }

            const link = wrapper.querySelector('a');
            if (!link) {
                return;
            }

            const key = link.getAttribute('href') || link.textContent.trim() || String(index);
            const sectionId = `mddoc-sidebar-section-${index}`;
            childList.id = childList.id || sectionId;

            const toggle = document.createElement('button');
            toggle.type = 'button';
            toggle.className = 'mddoc-sidebar-toggle';
            toggle.setAttribute('aria-controls', childList.id);
            toggle.innerHTML = '<span aria-hidden="true">❯</span>';
            wrapper.appendChild(toggle);

            const item = { key, li, childList, toggle };
            items.push(item);
            toggle.addEventListener('click', event => {
                event.preventDefault();
                event.stopPropagation();
                const expanded = li.classList.toggle('expanded');
                toggle.setAttribute('aria-expanded', String(expanded));
                toggle.setAttribute('aria-label', `${expanded ? 'Collapse' : 'Expand'} ${link.textContent.trim()}`);
                writeState(items);
            });
        });

        const active = chapter.querySelector('a.active');
        const saved = readState();
        items.forEach(item => {
            const savedValue = saved[item.key];
            const expanded = typeof savedValue === 'boolean'
                ? savedValue
                : Boolean(active && item.li.contains(active));
            item.li.classList.toggle('expanded', expanded);
            item.toggle.setAttribute('aria-expanded', String(expanded));
            item.toggle.setAttribute('aria-label', `${expanded ? 'Collapse' : 'Expand'} ${item.li.querySelector(':scope > .chapter-link-wrapper a').textContent.trim()}`);
        });

        // The active page must remain reachable even if a saved state was stale.
        if (active) {
            let parent = active.parentElement;
            while (parent && parent !== chapter) {
                if (parent.tagName === 'LI' && parent.classList.contains('chapter-item')) {
                    parent.classList.add('expanded');
                    const item = items.find(candidate => candidate.li === parent);
                    if (item) {
                        item.toggle.setAttribute('aria-expanded', 'true');
                    }
                }
                parent = parent.parentElement;
            }
        }

        const scrollbox = sidebar.querySelector('.sidebar-scrollbox');
        if (!scrollbox || scrollbox.querySelector('.mddoc-sidebar-controls')) {
            return;
        }

        const controls = document.createElement('div');
        controls.className = 'mddoc-sidebar-controls';
        controls.setAttribute('role', 'group');
        controls.setAttribute('aria-label', 'Sidebar section controls');

        const collapse = document.createElement('button');
        collapse.type = 'button';
        collapse.textContent = 'Collapse all';
        collapse.addEventListener('click', () => {
            items.forEach(item => {
                item.li.classList.remove('expanded');
                item.toggle.setAttribute('aria-expanded', 'false');
            });
            writeState(items);
        });

        const expand = document.createElement('button');
        expand.type = 'button';
        expand.textContent = 'Expand all';
        expand.addEventListener('click', () => {
            items.forEach(item => {
                item.li.classList.add('expanded');
                item.toggle.setAttribute('aria-expanded', 'true');
            });
            writeState(items);
        });

        controls.append(collapse, expand);
        scrollbox.insertBefore(controls, scrollbox.firstChild);
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', setup, { once: true });
    } else {
        setup();
    }
})();
