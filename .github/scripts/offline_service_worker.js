const scope = self.registration.scope;
const cachePrefix = `gmg-offline:${scope}:`;
const cacheName = cachePrefix + '__BUILD_HASH__';
const appShell = new URL('index.html', scope).href;
const offlineUrls = new Set(
  /*__OFFLINE_FILES__*/ [].map((path) => new URL(path, scope).href),
);

self.addEventListener('install', (event) => {
  event.waitUntil((async () => {
    const cache = await caches.open(cacheName);
    try {
      await cache.addAll(
        [...offlineUrls].map((url) => new Request(url, {cache: 'reload'})),
      );
    } catch (error) {
      await caches.delete(cacheName);
      throw error;
    }
  })());
});

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    const names = await caches.keys();
    await Promise.all(names.filter((name) =>
      name.startsWith(cachePrefix) && name !== cacheName,
    ).map((name) => caches.delete(name)));
    await self.clients.claim();
  })());
});

self.addEventListener('message', (event) => {
  if (event.data === 'skipWaiting') event.waitUntil(self.skipWaiting());
});

self.addEventListener('fetch', (event) => {
  const request = event.request;
  if (request.method !== 'GET') return;

  const url = new URL(request.url);
  url.search = '';
  url.hash = '';
  const isAppNavigation = request.mode === 'navigate' &&
    (url.href === scope || url.href === appShell);
  const key = isAppNavigation ? appShell : url.href;
  if (!offlineUrls.has(key)) return;

  event.respondWith((async () => {
    const cache = await caches.open(cacheName);
    return (await cache.match(key)) || fetch(request);
  })());
});
