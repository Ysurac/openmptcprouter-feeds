'use strict';
'require baseclass';
'require ui';

return baseclass.extend({
	__init__() {
		ui.menu.load().then((tree) => this.render(tree));
	},

	render(tree) {
		let node = tree;
		let url = '';

		this.renderModeMenu(tree);

		if (L.env.dispatchpath.length >= 3) {
			for (let i = 0; i < 3 && node; i++) {
				node = node.children[L.env.dispatchpath[i]];
				url = url + (url ? '/' : '') + L.env.dispatchpath[i];
			}

			if (node)
				this.renderTabMenu(node, url);
		}

		this.renderBreadcrumb(tree);
		this.bindLayout();
	},

	renderTabMenu(tree, url, level) {
		const container = document.querySelector('#tabmenu');
		const ul = E('ul', { 'class': 'tabs' });
		const children = ui.menu.getChildren(tree);
		let activeNode = null;

		children.forEach(child => {
			const isActive = (L.env.dispatchpath[3 + (level || 0)] == child.name);
			const activeClass = isActive ? ' active' : '';
			const className = 'tabmenu-item-%s %s'.format(child.name, activeClass);

			ul.appendChild(E('li', { 'class': className }, [
				E('a', { 'href': L.url(url, child.name) }, [ _(child.title) ] )]));

			if (isActive)
				activeNode = child;
		});

		if (ul.children.length == 0)
			return E([]);

		container.appendChild(ul);
		container.style.display = '';

		if (activeNode)
			this.renderTabMenu(activeNode, url + '/' + activeNode.name, (level || 0) + 1);

		return ul;
	},

	/* Categories become collapsible groups in the sidebar, their pages are
	 * the group's links and deeper levels are left to the tab menu. */
	renderMainMenu(tree, url) {
		const container = document.querySelector('#mainmenu');
		const ul = E('ul', { 'class': 'nav' });
		const children = ui.menu.getChildren(tree);

		children.forEach(child => {
			const isActive = (L.env.dispatchpath[1] == child.name);
			const pages = ui.menu.getChildren(child);
			const li = E('li', {
				'class': isActive ? 'active' : '',
				'data-name': child.name
			});
			const label = [
				E('span', { 'class': 'nav-icon' }),
				E('span', { 'class': 'nav-label' }, [ _(child.title) ])
			];

			if (pages.length == 0) {
				li.appendChild(E('a', { 'href': L.url(url, child.name) }, label));
				ul.appendChild(li);
				return;
			}

			const subnav = E('ul', { 'class': 'subnav' });

			pages.forEach(page => {
				const isCurrent = isActive && (L.env.dispatchpath[2] == page.name);
				const link = E('a', { 'href': L.url(url, child.name, page.name) }, [ _(page.title) ]);

				if (isCurrent)
					link.setAttribute('aria-current', 'page');

				subnav.appendChild(E('li', { 'class': isCurrent ? 'active' : '' }, [ link ]));
			});

			li.classList.add('group');

			if (isActive)
				li.classList.add('open');

			li.appendChild(E('a', {
				'href': '#',
				'class': 'group-toggle',
				'role': 'button',
				'aria-expanded': isActive ? 'true' : 'false',
				'click': (ev) => this.handleGroupToggle(ev)
			}, label.concat([ E('span', { 'class': 'chevron' }) ])));
			li.appendChild(subnav);

			ul.appendChild(li);
		});

		container.appendChild(ul);
		container.style.display = '';

		return ul;
	},

	renderModeMenu(tree) {
		const ul = document.querySelector('#modemenu');
		const children = ui.menu.getChildren(tree);

		children.forEach((child, index) => {
			const isActive = L.env.requestpath.length
				? child.name === L.env.requestpath[0]
				: index === 0;

			ul.appendChild(E('li', { 'class': isActive ? 'active' : '' }, [
				E('a', { 'href': L.url(child.name) }, [ _(child.title) ])
			]));

			if (isActive)
				this.renderMainMenu(child, child.name);
		});

		if (ul.children.length > 1)
			ul.style.display = '';
	},

	renderBreadcrumb(tree) {
		const container = document.querySelector('#breadcrumb');
		const titles = [];
		let node = tree;

		for (let i = 0; node && i < L.env.dispatchpath.length; i++) {
			node = node.children ? node.children[L.env.dispatchpath[i]] : null;

			if (i > 0 && node && node.title)
				titles.push(_(node.title));
		}

		titles.forEach((title, i) => {
			container.appendChild(E((i == titles.length - 1) ? 'strong' : 'span', {}, [ title ]));
		});
	},

	handleGroupToggle(ev) {
		const toggle = ev.currentTarget;
		const open = toggle.parentNode.classList.toggle('open');

		toggle.setAttribute('aria-expanded', open ? 'true' : 'false');
		ev.preventDefault();
	},

	setSidebar(open) {
		document.body.classList.toggle('sidebar-open', open);
		document.querySelector('.menu-toggle').setAttribute('aria-expanded', open ? 'true' : 'false');
	},

	/* Only rendered by the auto variant: a manual choice that matches the
	 * system preference is dropped so the page follows the system again. */
	handleDarkModeToggle() {
		const root = document.querySelector(':root');
		const dark = (root.getAttribute('data-darkmode') != 'true');
		const system = window.matchMedia('(prefers-color-scheme: dark)').matches;

		try {
			if (dark == system)
				window.localStorage.removeItem('omr-darkmode');
			else
				window.localStorage.setItem('omr-darkmode', dark ? 'true' : 'false');
		}
		catch (e) {}

		root.setAttribute('data-darkmode', dark ? 'true' : 'false');
	},

	bindLayout() {
		const darkToggle = document.querySelector('.darkmode-toggle');

		document.querySelector('.menu-toggle').addEventListener('click', () =>
			this.setSidebar(!document.body.classList.contains('sidebar-open')));

		document.querySelector('#sidebar-mask').addEventListener('click', () =>
			this.setSidebar(false));

		document.addEventListener('keydown', (ev) => {
			if (ev.key === 'Escape' && document.body.classList.contains('sidebar-open'))
				this.setSidebar(false);
		});

		if (darkToggle) {
			darkToggle.addEventListener('click', () => this.handleDarkModeToggle());
			darkToggle.style.display = '';
		}
	}
});
