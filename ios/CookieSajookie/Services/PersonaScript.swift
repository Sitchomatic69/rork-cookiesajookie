import Foundation

/// Generates the protective JavaScript injected into every WKWebView at
/// `.atDocumentStart`. The script overrides high-entropy signals while
/// preserving the native function chain (`.toString()`, descriptors, prototype)
/// so naive anti-detection heuristics can't see the wrapper.
///
/// Design rules:
///   1. Use `Object.defineProperty` with `{configurable:true, enumerable:false}`
///      — matches real native descriptors on iOS Safari.
///   2. Wrap functions via `Reflect.apply` of the original, then reassign
///      `wrapper.toString` to a value that returns the original's `toString()`
///      output — survives `Function.prototype.toString.call(getParameter)`.
///   3. Never throw: every override is wrapped in try/catch so a single
///      failure can't trip a page's defensive `try{...}catch{detected}` block.
///   4. Deterministic seed (persona.renderSeed) drives canvas/audio offsets,
///      so the same persona produces a stable, hashable signature.
nonisolated enum PersonaScript {

    static func make(for p: BrowsingPersona) -> String {
        let langsJSON = "[" + p.languages.map { "\"\($0)\"" }.joined(separator: ",") + "]"
        let fontsJSON = "[" + p.fonts.map { "\"\($0)\"" }.joined(separator: ",") + "]"
        let secChUaPlatformValue = p.secChUaPlatform.replacingOccurrences(of: "\"", with: "")
        let isMobileJS = p.isMobile ? "true" : "false"

        return """
        (function(){
        'use strict';
        var SEED = \(p.renderSeed)n;
        var MOBILE = \(isMobileJS);
        var TZ = '\(p.timezone)';
        var LANG = '\(p.language)';
        var LANGS = \(langsJSON);
        var PLATFORM = '\(p.platform)';
        var VENDOR = '\(p.vendor)';
        var HW = \(p.hardwareConcurrency);
        var DM = \(p.deviceMemory);
        var MAXT = \(p.maxTouchPoints);
        var SW = \(p.screenWidth), SH = \(p.screenHeight);
        var AW = \(p.availWidth), AH = \(p.availHeight);
        var DPR = \(p.devicePixelRatio);
        var CD = \(p.colorDepth);
        var GL_VENDOR = '\(p.webglVendor)';
        var GL_RENDERER = '\(p.webglRenderer)';
        var GL_UVENDOR = '\(p.webglUnmaskedVendor)';
        var GL_URENDERER = '\(p.webglUnmaskedRenderer)';
        var AUDIO_RATE = \(p.audioSampleRate);
        var FONTS = \(fontsJSON);
        var SECCHUA_PLATFORM = '\(secChUaPlatformValue)';

        // --- Native-chain preserving helpers ---
        function defineGetter(obj, prop, getter) {
            try {
                Object.defineProperty(obj, prop, {
                    get: getter, configurable: true, enumerable: false
                });
            } catch(e) {}
        }
        function wrapMethod(proto, name, factory) {
            try {
                var original = proto[name];
                if (typeof original !== 'function') return;
                var wrapped = factory(original);
                // Preserve .toString() => native code form.
                var nativeStr = Function.prototype.toString.call(original);
                try {
                    wrapped.toString = function() { return nativeStr; };
                    Object.defineProperty(wrapped, 'toString', {
                        value: function() { return nativeStr; },
                        writable: false, enumerable: false, configurable: true
                    });
                } catch(e) {}
                try {
                    Object.defineProperty(wrapped, 'name', { value: name, configurable: true });
                } catch(e) {}
                proto[name] = wrapped;
            } catch(e) {}
        }

        // --- Deterministic PRNG (xorshift64*) seeded by persona ---
        var _s = SEED;
        function rng() {
            _s ^= _s >> 12n; _s ^= _s << 25n; _s ^= _s >> 27n;
            var v = (_s * 2685821657736338717n) & 0xFFFFFFFFFFFFFFFFn;
            return Number(v & 0xFFFFFFn) / 0xFFFFFF;
        }
        function reseed() { _s = SEED; }

        // --- Navigator overrides ---
        defineGetter(Navigator.prototype, 'platform', function(){ return PLATFORM; });
        defineGetter(Navigator.prototype, 'vendor', function(){ return VENDOR; });
        defineGetter(Navigator.prototype, 'language', function(){ return LANG; });
        defineGetter(Navigator.prototype, 'languages', function(){ return LANGS.slice(); });
        defineGetter(Navigator.prototype, 'hardwareConcurrency', function(){ return HW; });
        defineGetter(Navigator.prototype, 'deviceMemory', function(){ return DM; });
        defineGetter(Navigator.prototype, 'maxTouchPoints', function(){ return MAXT; });

        // userAgentData: Safari iOS doesn't expose it. Make it undefined to match.
        try {
            if ('userAgentData' in Navigator.prototype) {
                Object.defineProperty(Navigator.prototype, 'userAgentData', {
                    get: function(){
                        return {
                            brands: [],
                            mobile: MOBILE,
                            platform: SECCHUA_PLATFORM,
                            getHighEntropyValues: function(){ return Promise.resolve({
                                architecture: 'arm', bitness: '64', model: '',
                                platform: SECCHUA_PLATFORM, platformVersion: '',
                                uaFullVersion: '', mobile: MOBILE
                            }); },
                            toJSON: function(){ return { brands: [], mobile: MOBILE, platform: SECCHUA_PLATFORM }; }
                        };
                    },
                    configurable: true, enumerable: false
                });
            }
        } catch(e) {}

        // --- Screen overrides ---
        try {
            defineGetter(Screen.prototype, 'width', function(){ return SW; });
            defineGetter(Screen.prototype, 'height', function(){ return SH; });
            defineGetter(Screen.prototype, 'availWidth', function(){ return AW; });
            defineGetter(Screen.prototype, 'availHeight', function(){ return AH; });
            defineGetter(Screen.prototype, 'colorDepth', function(){ return CD; });
            defineGetter(Screen.prototype, 'pixelDepth', function(){ return CD; });
        } catch(e) {}
        try { defineGetter(window, 'devicePixelRatio', function(){ return DPR; }); } catch(e) {}

        // --- Intl / timezone ---
        try {
            var _resolved = Intl.DateTimeFormat.prototype.resolvedOptions;
            wrapMethod(Intl.DateTimeFormat.prototype, 'resolvedOptions', function(orig){
                return function() {
                    var r = orig.apply(this, arguments);
                    try { r.timeZone = TZ; } catch(e){}
                    try { r.locale = LANG; } catch(e){}
                    return r;
                };
            });
        } catch(e) {}
        try {
            wrapMethod(Date.prototype, 'getTimezoneOffset', function(){
                return function() {
                    try {
                        var utc = new Date(this.toLocaleString('en-US', { timeZone: 'UTC' }));
                        var tz  = new Date(this.toLocaleString('en-US', { timeZone: TZ }));
                        return Math.round((utc - tz) / 60000);
                    } catch(e){ return 0; }
                };
            });
        } catch(e) {}

        // --- Canvas: deterministic sub-pixel tweak (NOT noise) ---
        try {
            wrapMethod(HTMLCanvasElement.prototype, 'toDataURL', function(orig){
                return function() {
                    try {
                        var ctx = this.getContext && this.getContext('2d');
                        if (ctx && this.width > 0 && this.height > 0) {
                            reseed();
                            var x = Math.floor(rng() * this.width);
                            var y = Math.floor(rng() * this.height);
                            ctx.fillStyle = 'rgba(0,0,0,0.0039)'; // 1/255 alpha — visually invisible
                            ctx.fillRect(x, y, 1, 1);
                        }
                    } catch(e){}
                    return orig.apply(this, arguments);
                };
            });
            wrapMethod(HTMLCanvasElement.prototype, 'toBlob', function(orig){
                return function() {
                    try {
                        var ctx = this.getContext && this.getContext('2d');
                        if (ctx) {
                            reseed();
                            ctx.fillStyle = 'rgba(0,0,0,0.0039)';
                            ctx.fillRect(Math.floor(rng()*this.width), Math.floor(rng()*this.height), 1, 1);
                        }
                    } catch(e){}
                    return orig.apply(this, arguments);
                };
            });
            wrapMethod(CanvasRenderingContext2D.prototype, 'getImageData', function(orig){
                return function() {
                    var img = orig.apply(this, arguments);
                    try {
                        reseed();
                        // Tweak exactly one byte deterministically.
                        if (img && img.data && img.data.length > 0) {
                            var idx = Math.floor(rng() * img.data.length) & ~3;
                            img.data[idx] = (img.data[idx] ^ 1) & 0xFF;
                        }
                    } catch(e){}
                    return img;
                };
            });
            wrapMethod(CanvasRenderingContext2D.prototype, 'measureText', function(orig){
                return function() {
                    var m = orig.apply(this, arguments);
                    try {
                        if (m && typeof m.width === 'number') {
                            reseed();
                            var delta = (rng() - 0.5) * 0.0001;
                            Object.defineProperty(m, 'width', { value: m.width + delta, configurable: true });
                        }
                    } catch(e){}
                    return m;
                };
            });
        } catch(e) {}

        // --- WebGL ---
        function patchGL(proto) {
            wrapMethod(proto, 'getParameter', function(orig){
                return function(p) {
                    try {
                        // UNMASKED_VENDOR_WEBGL = 0x9245, UNMASKED_RENDERER_WEBGL = 0x9246
                        if (p === 0x9245) return GL_UVENDOR;
                        if (p === 0x9246) return GL_URENDERER;
                        // VENDOR = 0x1F00, RENDERER = 0x1F01
                        if (p === 0x1F00) return GL_VENDOR;
                        if (p === 0x1F01) return GL_RENDERER;
                    } catch(e){}
                    return orig.apply(this, arguments);
                };
            });
        }
        try { if (typeof WebGLRenderingContext !== 'undefined') patchGL(WebGLRenderingContext.prototype); } catch(e){}
        try { if (typeof WebGL2RenderingContext !== 'undefined') patchGL(WebGL2RenderingContext.prototype); } catch(e){}

        // --- AudioContext: stable sample rate + deterministic getChannelData offset ---
        try {
            if (typeof AudioBuffer !== 'undefined') {
                wrapMethod(AudioBuffer.prototype, 'getChannelData', function(orig){
                    return function() {
                        var data = orig.apply(this, arguments);
                        try {
                            reseed();
                            if (data && data.length > 0) {
                                var i = Math.floor(rng() * data.length);
                                data[i] = data[i] + (rng() - 0.5) * 1e-7;
                            }
                        } catch(e){}
                        return data;
                    };
                });
            }
            if (typeof OfflineAudioContext !== 'undefined') {
                defineGetter(OfflineAudioContext.prototype, 'sampleRate', function(){ return AUDIO_RATE; });
            }
            if (typeof AudioContext !== 'undefined') {
                defineGetter(AudioContext.prototype, 'sampleRate', function(){ return AUDIO_RATE; });
            }
        } catch(e){}

        // --- Font enumeration sandboxing via measureText / FontFace check ---
        try {
            if (typeof document !== 'undefined' && document.fonts && document.fonts.check) {
                wrapMethod(document.fonts.__proto__, 'check', function(orig){
                    return function(spec, text) {
                        try {
                            for (var i = 0; i < FONTS.length; i++) {
                                if (spec && spec.indexOf(FONTS[i]) !== -1) {
                                    return orig.apply(this, arguments);
                                }
                            }
                            return false;
                        } catch(e){}
                        return orig.apply(this, arguments);
                    };
                });
            }
        } catch(e){}

        // --- Permissions: stabilize notifications query ---
        try {
            if (navigator.permissions && navigator.permissions.query) {
                wrapMethod(navigator.permissions.__proto__, 'query', function(orig){
                    return function(p) {
                        try {
                            if (p && p.name === 'notifications') {
                                return Promise.resolve({
                                    state: (typeof Notification !== 'undefined' && Notification.permission) || 'prompt',
                                    onchange: null
                                });
                            }
                        } catch(e){}
                        return orig.apply(this, arguments);
                    };
                });
            }
        } catch(e){}

        // --- Plugins: empty array (matches Safari iOS) ---
        try {
            if (MOBILE) {
                defineGetter(Navigator.prototype, 'plugins', function(){ return []; });
                defineGetter(Navigator.prototype, 'mimeTypes', function(){ return []; });
            }
        } catch(e){}

        // --- Battery API (Safari iOS does not expose; mirror that) ---
        try {
            if (MOBILE && 'getBattery' in Navigator.prototype) {
                delete Navigator.prototype.getBattery;
            }
        } catch(e){}

        })();
        """
    }
}
