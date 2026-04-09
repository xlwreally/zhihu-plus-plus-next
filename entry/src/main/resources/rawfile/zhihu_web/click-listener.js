(function () {
  if (window.__zhihuClickListenerInstalled) {
    return;
  }
  window.__zhihuClickListenerInstalled = true;

  function post(payload) {
    if (!window.zhihuBridge || typeof window.zhihuBridge.postMessage !== 'function') {
      return;
    }
    try {
      window.zhihuBridge.postMessage(JSON.stringify(payload));
    } catch (_) {
    }
  }

  function absoluteImageUrl(element) {
    if (!element) {
      return '';
    }
    return element.currentSrc || element.src || element.getAttribute('data-original') || element.getAttribute('src') || '';
  }

  document.addEventListener('click', function (event) {
    var target = event.target;
    if (!(target instanceof Element)) {
      return;
    }

    var image = target.closest('img');
    if (image instanceof HTMLImageElement) {
      if (image.getAttribute('data-zhihu-ignore-image-click') === 'true') {
        return;
      }
      var imageUrl = absoluteImageUrl(image);
      if (imageUrl) {
        event.preventDefault();
        post({ type: 'image', url: imageUrl });
      }
      return;
    }

    var anchor = target.closest('a');
    if (!(anchor instanceof HTMLAnchorElement)) {
      return;
    }
    var href = anchor.getAttribute('href') || '';
    if (!href || href.charAt(0) === '#') {
      return;
    }
    event.preventDefault();
    post({
      type: 'link',
      url: anchor.href,
      text: (anchor.textContent || '').trim()
    });
  }, true);
})();
