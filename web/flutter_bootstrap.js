{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  config: {
    canvasKitBaseUrl: new URL('canvaskit/', document.baseURI).href,
    canvasKitVariant: 'full',
    // __OFFLINE_FONT_FALLBACK__
  },
});
