'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"canvaskit/canvaskit.js": "728b2d477d9b8c14593d4f9b82b484f3",
"canvaskit/canvaskit.js.symbols": "bdcd3835edf8586b6d6edfce8749fb77",
"canvaskit/canvaskit.wasm": "7a3f4ae7d65fc1de6a6e7ddd3224bc93",
"canvaskit/chromium/canvaskit.js": "8191e843020c832c9cf8852a4b909d4c",
"canvaskit/chromium/canvaskit.js.symbols": "b61b5f4673c9698029fa0a746a9ad581",
"canvaskit/chromium/canvaskit.wasm": "f504de372e31c8031018a9ec0a9ef5f0",
"canvaskit/skwasm.js": "ea559890a088fe28b4ddf70e17e60052",
"canvaskit/skwasm.js.symbols": "e72c79950c8a8483d826a7f0560573a1",
"canvaskit/skwasm.wasm": "39dd80367a4e71582d234948adc521c0",
"flutter.js": "83d881c1dbb6d6bcd6b42e274605b69c",
"flutter_bootstrap.js": "7cc9392e4e906d0381745f08a1f6d7c8",
"index.html": "89292b678def8e00767db955b5e485a1",
"/": "89292b678def8e00767db955b5e485a1",
"main.dart.js": "b00005c265538f6c10c046c76fd67e9a",
"version.json": "2d2b1edffdbdffafacc8ef08f17822ed",
"assets/assets/logouzita.png": "d93ab90e6f22545c4285bce122942e27",
"assets/assets/banner.jpg": "5cf46ce9cf8959cc76fda4ee93b1f388",
"assets/assets/fonts/Nasalization.otf": "663c62572f93cd595b9d1ac934720d99",
"assets/assets/biokaveh.png": "092088b62cd00808934beeea566ed6b0",
"assets/assets/icons/report.svg": "bd96b5e32ae0a95a7279a3a3f3f3aba4",
"assets/assets/icons/device.svg": "99480d814af7660268c1c33de24b0571",
"assets/assets/icons/users.svg": "91961992439dbe2abd74e8adf4e60f0d",
"assets/assets/icons/setting.svg": "02cf0377ea110412dcb07390f2b43151",
"assets/assets/icons/person.svg": "3e198bfbc6132731bb95e69268ac022d",
"assets/assets/icons/office.svg": "5d7b44309c2a5f5797bb8af157dc3e4a",
"assets/assets/icons/phone-plus.svg": "46f24b07dedbc43d4a3c11f3e5659d3f",
"assets/assets/icons/key.svg": "3211bc78aeb6efa68485a9fef822c32c",
"assets/assets/icons/user.svg": "f86f2b489ef70f5670667a460bb3f6e6",
"assets/assets/icons/admin.svg": "078214f2588f32d970616d4087d14621",
"assets/assets/icons/logouzita_maskable.png": "cbb783199dfa633f85587770ef324398",
"assets/assets/drawer_small_phone.jpg": "d23fa651c08811645a6f04f8cee914e8",
"assets/assets/drawer_big_phone.jpg": "ee6c4b848486eb19a37134c73a942036",
"assets/packages/cupertino_icons/assets/CupertinoIcons.ttf": "33b7d9392238c04c131b6ce224e13711",
"assets/fonts/MaterialIcons-Regular.otf": "b74465e81748d2cc3792a082d6a3b898",
"assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"assets/AssetManifest.json": "0290d69d4ebed64e3a17c27465d60b1c",
"assets/AssetManifest.bin.json": "69f806ade41e3bc9180a53587ccc0480",
"assets/AssetManifest.bin": "f98ae556a1eaa856d51b16aaeec0d9d0",
"assets/FontManifest.json": "2838e09e9e8724a23a1a1767309356ec",
"assets/NOTICES": "e3168da64b359fcdc32cbdee98f6d558",
"favicon.png": "5e75ac3e151feb1b4f93c206fa9707ed",
"manifest.json": "3976fc06484a48a2bb87c16e17ee047b",
"icons/Icon-512.png": "7586216a922a3e788c580b52643b544d",
"icons/Icon-maskable-192.png": "856e04284f1befc6b76e20617249cba3",
"icons/Icon-maskable-512.png": "a31f91e3f513cca1c3bba575811e7fc2",
"icons/Icon-192.png": "b8a8ce5be2766eaeed55493f7e0a83d6",
"icons/logouzita.png": "1f1d0aede70bea77fb414a5202f1e32e",
"icons/apple-touch-icon-180x180.png": "86817202c0d6d894844e1e32804589d9",
"icons/apple-touch-icon-167x167.png": "9b43d11acb299b46acb6243e15fa800a",
"icons/apple-touch-icon-152x152.png": "e292590640554944468b756b4184f9b8",
"icons/apple-touch-icon-120x120.png": "f8c9f5f1d5d1591f4cd89fa5cf466f27",
"icons/Icon-maskable-36.png": "15112a6c08e5f17b935848868d169526",
"icons/Icon-maskable-48.png": "715b2ad334213f74978ec3b2e6a3a32d",
"icons/Icon-maskable-72.png": "560eb9a08521841ff79411351aeb2384",
"icons/Icon-maskable-96.png": "3f9dc0f3202113d0dc84cff88cce162d",
"icons/Icon-maskable-128.png": "d9bedb8190b30ea4e1aae6daeda34c77",
"icons/Icon-maskable-144.png": "816326bc15a942977c947e5bb6e6fe15",
"icons/Icon-maskable-152.png": "e292590640554944468b756b4184f9b8",
"icons/Icon-maskable-180.png": "86817202c0d6d894844e1e32804589d9",
"icons/Icon-maskable-256.png": "cea06e1950a7aa4de3cbefa05316ccf2",
"icons/Icon-maskable-384.png": "cba4bc4b5b4e452a59e1fe95727e5aa6",
"404.html": "89292b678def8e00767db955b5e485a1"};
// The application shell files that are downloaded before a service worker can
// start.
const CORE = ["main.dart.js",
"index.html",
"flutter_bootstrap.js",
"assets/AssetManifest.bin.json",
"assets/FontManifest.json"];

// During install, the TEMP cache is populated with the application shell files.
self.addEventListener("install", (event) => {
  self.skipWaiting();
  return event.waitUntil(
    caches.open(TEMP).then((cache) => {
      return cache.addAll(
        CORE.map((value) => new Request(value, {'cache': 'reload'})));
    })
  );
});
// During activate, the cache is populated with the temp files downloaded in
// install. If this service worker is upgrading from one with a saved
// MANIFEST, then use this to retain unchanged resource files.
self.addEventListener("activate", function(event) {
  return event.waitUntil(async function() {
    try {
      var contentCache = await caches.open(CACHE_NAME);
      var tempCache = await caches.open(TEMP);
      var manifestCache = await caches.open(MANIFEST);
      var manifest = await manifestCache.match('manifest');
      // When there is no prior manifest, clear the entire cache.
      if (!manifest) {
        await caches.delete(CACHE_NAME);
        contentCache = await caches.open(CACHE_NAME);
        for (var request of await tempCache.keys()) {
          var response = await tempCache.match(request);
          await contentCache.put(request, response);
        }
        await caches.delete(TEMP);
        // Save the manifest to make future upgrades efficient.
        await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
        // Claim client to enable caching on first launch
        self.clients.claim();
        return;
      }
      var oldManifest = await manifest.json();
      var origin = self.location.origin;
      for (var request of await contentCache.keys()) {
        var key = request.url.substring(origin.length + 1);
        if (key == "") {
          key = "/";
        }
        // If a resource from the old manifest is not in the new cache, or if
        // the MD5 sum has changed, delete it. Otherwise the resource is left
        // in the cache and can be reused by the new service worker.
        if (!RESOURCES[key] || RESOURCES[key] != oldManifest[key]) {
          await contentCache.delete(request);
        }
      }
      // Populate the cache with the app shell TEMP files, potentially overwriting
      // cache files preserved above.
      for (var request of await tempCache.keys()) {
        var response = await tempCache.match(request);
        await contentCache.put(request, response);
      }
      await caches.delete(TEMP);
      // Save the manifest to make future upgrades efficient.
      await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
      // Claim client to enable caching on first launch
      self.clients.claim();
      return;
    } catch (err) {
      // On an unhandled exception the state of the cache cannot be guaranteed.
      console.error('Failed to upgrade service worker: ' + err);
      await caches.delete(CACHE_NAME);
      await caches.delete(TEMP);
      await caches.delete(MANIFEST);
    }
  }());
});
// The fetch handler redirects requests for RESOURCE files to the service
// worker cache.
self.addEventListener("fetch", (event) => {
  if (event.request.method !== 'GET') {
    return;
  }
  var origin = self.location.origin;
  var key = event.request.url.substring(origin.length + 1);
  // Redirect URLs to the index.html
  if (key.indexOf('?v=') != -1) {
    key = key.split('?v=')[0];
  }
  if (event.request.url == origin || event.request.url.startsWith(origin + '/#') || key == '') {
    key = '/';
  }
  // If the URL is not the RESOURCE list then return to signal that the
  // browser should take over.
  if (!RESOURCES[key]) {
    return;
  }
  // If the URL is the index.html, perform an online-first request.
  if (key == '/') {
    return onlineFirst(event);
  }
  event.respondWith(caches.open(CACHE_NAME)
    .then((cache) =>  {
      return cache.match(event.request).then((response) => {
        // Either respond with the cached resource, or perform a fetch and
        // lazily populate the cache only if the resource was successfully fetched.
        return response || fetch(event.request).then((response) => {
          if (response && Boolean(response.ok)) {
            cache.put(event.request, response.clone());
          }
          return response;
        });
      })
    })
  );
});
self.addEventListener('message', (event) => {
  // SkipWaiting can be used to immediately activate a waiting service worker.
  // This will also require a page refresh triggered by the main worker.
  if (event.data === 'skipWaiting') {
    self.skipWaiting();
    return;
  }
  if (event.data === 'downloadOffline') {
    downloadOffline();
    return;
  }
});
// Download offline will check the RESOURCES for all files not in the cache
// and populate them.
async function downloadOffline() {
  var resources = [];
  var contentCache = await caches.open(CACHE_NAME);
  var currentContent = {};
  for (var request of await contentCache.keys()) {
    var key = request.url.substring(origin.length + 1);
    if (key == "") {
      key = "/";
    }
    currentContent[key] = true;
  }
  for (var resourceKey of Object.keys(RESOURCES)) {
    if (!currentContent[resourceKey]) {
      resources.push(resourceKey);
    }
  }
  return contentCache.addAll(resources);
}
// Attempt to download the resource online before falling back to
// the offline cache.
function onlineFirst(event) {
  return event.respondWith(
    fetch(event.request).then((response) => {
      return caches.open(CACHE_NAME).then((cache) => {
        cache.put(event.request, response.clone());
        return response;
      });
    }).catch((error) => {
      return caches.open(CACHE_NAME).then((cache) => {
        return cache.match(event.request).then((response) => {
          if (response != null) {
            return response;
          }
          throw error;
        });
      });
    })
  );
}
