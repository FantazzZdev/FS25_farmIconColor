// Farm Icon Color - logo converter core (browser + Node, no dependencies).
// Image (RGBA 256x256) -> DDS DXT5 with mipmaps (same layout as the logos
// shipped with the mod) -> XML "logo package" with the DDS in Base64.
(function (root) {
  "use strict";

  var LOGO_SIZE = 256;
  var MAX_BYTES = 512 * 1024;

  function adler32(bytes) {
    var a = 1, b = 0;
    for (var i = 0; i < bytes.length; i++) {
      a = (a + bytes[i]) % 65521;
      b = (b + a) % 65521;
    }
    return b * 65536 + a;
  }

  function toBase64(bytes) {
    if (typeof Buffer !== "undefined") return Buffer.from(bytes).toString("base64");
    var out = "";
    for (var i = 0; i < bytes.length; i += 0x8000) {
      out += String.fromCharCode.apply(null, bytes.subarray(i, i + 0x8000));
    }
    return btoa(out);
  }

  function u32(bytes, offset) {
    return (bytes[offset] | (bytes[offset + 1] << 8) | (bytes[offset + 2] << 16)) + bytes[offset + 3] * 16777216;
  }

  function parseDdsHeader(bytes) {
    if (bytes.length < 128 || bytes[0] !== 68 || bytes[1] !== 68 || bytes[2] !== 83 || bytes[3] !== 32) return null;
    if (u32(bytes, 4) !== 124) return null;
    return {
      height: u32(bytes, 12),
      width: u32(bytes, 16),
      mipCount: u32(bytes, 28) || 1,
      fourCC: String.fromCharCode(bytes[84], bytes[85], bytes[86], bytes[87])
    };
  }

  // ---------------------------------------------------------------- decode --
  function color565(c) {
    var r = (c >> 11) & 31, g = (c >> 5) & 63, b = c & 31;
    return [(r << 3) | (r >> 2), (g << 2) | (g >> 4), (b << 3) | (b >> 2)];
  }

  // Decodes the top mip of a DXT1/DXT5 DDS to RGBA (preview + tint detection).
  function decodeDds(bytes) {
    var h = parseDdsHeader(bytes);
    if (!h || (h.fourCC !== "DXT5" && h.fourCC !== "DXT1")) return null;
    var w = h.width, ht = h.height, out = new Uint8ClampedArray(w * ht * 4);
    var blockSize = h.fourCC === "DXT5" ? 16 : 8, p = 128;
    for (var by = 0; by < ht; by += 4) {
      for (var bx = 0; bx < w; bx += 4, p += blockSize) {
        var alphas = null, aBits = 0, aHi = 0, cp = p;
        if (blockSize === 16) {
          var a0 = bytes[p], a1 = bytes[p + 1];
          alphas = [a0, a1];
          for (var i = 2; i < 8; i++) {
            alphas.push(a0 > a1 ? Math.round(((8 - i) * a0 + (i - 1) * a1) / 7)
                                : (i < 6 ? Math.round(((6 - i) * a0 + (i - 1) * a1) / 5) : (i === 6 ? 0 : 255)));
          }
          aBits = bytes[p + 2] | (bytes[p + 3] << 8) | (bytes[p + 4] << 16);
          aHi = bytes[p + 5] | (bytes[p + 6] << 8) | (bytes[p + 7] << 16);
          cp = p + 8;
        }
        var c0 = bytes[cp] | (bytes[cp + 1] << 8), c1 = bytes[cp + 2] | (bytes[cp + 3] << 8);
        var e0 = color565(c0), e1 = color565(c1), pal = [e0, e1];
        if (blockSize === 16 || c0 > c1) {
          pal.push([0, 1, 2].map(function (k) { return Math.round((2 * e0[k] + e1[k]) / 3); }));
          pal.push([0, 1, 2].map(function (k) { return Math.round((e0[k] + 2 * e1[k]) / 3); }));
        } else {
          pal.push([0, 1, 2].map(function (k) { return Math.round((e0[k] + e1[k]) / 2); }));
          pal.push([0, 0, 0]);
        }
        var idx = u32(bytes, cp + 4);
        for (var k = 0; k < 16; k++) {
          var x = bx + (k & 3), y = by + (k >> 2);
          if (x >= w || y >= ht) continue;
          var ci = Math.floor(idx / Math.pow(4, k)) & 3, o = (y * w + x) * 4, col = pal[ci];
          out[o] = col[0]; out[o + 1] = col[1]; out[o + 2] = col[2];
          if (alphas) {
            var ai = k < 8 ? (aBits >> (3 * k)) & 7 : (aHi >> (3 * (k - 8))) & 7;
            out[o + 3] = alphas[ai];
          } else {
            out[o + 3] = (blockSize === 8 && c0 <= c1 && ci === 3) ? 0 : 255;
          }
        }
      }
    }
    return { width: w, height: ht, rgba: out };
  }

  // ---------------------------------------------------------------- encode --
  function to565(r, g, b) {
    return ((Math.round(r * 31 / 255) & 31) << 11) | ((Math.round(g * 63 / 255) & 63) << 5) | (Math.round(b * 31 / 255) & 31);
  }

  function encodeBlock(px, out, o) {
    // ---- alpha (8 bytes): 8-value mode, a0 > a1
    var amin = 255, amax = 0, i, k;
    for (k = 0; k < 16; k++) { amin = Math.min(amin, px[k][3]); amax = Math.max(amax, px[k][3]); }
    out[o] = amax; out[o + 1] = amin;
    if (amax !== amin) {
      var apal = [amax, amin];
      for (i = 2; i < 8; i++) apal.push(((8 - i) * amax + (i - 1) * amin) / 7);
      for (k = 0; k < 16; k++) {
        var best = 0, bestD = 1e9;
        for (i = 0; i < 8; i++) { var d = Math.abs(apal[i] - px[k][3]); if (d < bestD) { bestD = d; best = i; } }
        for (var bit = 0; bit < 3; bit++) {
          if ((best >> bit) & 1) { var pos = 3 * k + bit; out[o + 2 + (pos >> 3)] |= 1 << (pos & 7); }
        }
      }
    }
    // ---- colour (8 bytes): range fit on visible pixels
    var use = px.filter(function (p) { return p[3] > 0; });
    if (use.length === 0) use = px;
    var mn = [255, 255, 255], mx = [0, 0, 0];
    use.forEach(function (p) { for (var c = 0; c < 3; c++) { mn[c] = Math.min(mn[c], p[c]); mx[c] = Math.max(mx[c], p[c]); } });
    for (var c = 0; c < 3; c++) { var inset = (mx[c] - mn[c]) / 16; mn[c] += inset; mx[c] -= inset; }
    var c0 = to565(mx[0], mx[1], mx[2]), c1 = to565(mn[0], mn[1], mn[2]);
    if (c0 < c1) { var t = c0; c0 = c1; c1 = t; }
    out[o + 8] = c0 & 255; out[o + 9] = c0 >> 8; out[o + 10] = c1 & 255; out[o + 11] = c1 >> 8;
    if (c0 === c1) return;
    var e0 = color565(c0), e1 = color565(c1);
    var cpal = [e0, e1,
      [0, 1, 2].map(function (q) { return (2 * e0[q] + e1[q]) / 3; }),
      [0, 1, 2].map(function (q) { return (e0[q] + 2 * e1[q]) / 3; })];
    var bits = 0;
    for (k = 0; k < 16; k++) {
      var bi = 0, bd = 1e9;
      for (i = 0; i < 4; i++) {
        var dr = cpal[i][0] - px[k][0], dg = cpal[i][1] - px[k][1], db = cpal[i][2] - px[k][2];
        var dist = dr * dr + dg * dg + db * db;
        if (dist < bd) { bd = dist; bi = i; }
      }
      bits += bi * Math.pow(4, k);
    }
    out[o + 12] = bits % 256; out[o + 13] = Math.floor(bits / 256) % 256;
    out[o + 14] = Math.floor(bits / 65536) % 256; out[o + 15] = Math.floor(bits / 16777216) % 256;
  }

  function encodeLevel(rgba, size, out, offset) {
    for (var by = 0; by < size || (by === 0); by += 4) {
      for (var bx = 0; bx < size || (bx === 0); bx += 4) {
        var px = [];
        for (var k = 0; k < 16; k++) {
          var x = Math.min(bx + (k & 3), size - 1), y = Math.min(by + (k >> 2), size - 1), p = (y * size + x) * 4;
          px.push([rgba[p], rgba[p + 1], rgba[p + 2], rgba[p + 3]]);
        }
        encodeBlock(px, out, offset);
        offset += 16;
      }
    }
    return offset;
  }

  // Alpha-weighted 2x2 box filter (keeps transparent borders from going dark).
  function downscale(rgba, size) {
    var half = size >> 1, out = new Uint8ClampedArray(half * half * 4);
    for (var y = 0; y < half; y++) {
      for (var x = 0; x < half; x++) {
        var r = 0, g = 0, b = 0, a = 0;
        for (var k = 0; k < 4; k++) {
          var p = ((2 * y + (k >> 1)) * size + 2 * x + (k & 1)) * 4, w = rgba[p + 3];
          r += rgba[p] * w; g += rgba[p + 1] * w; b += rgba[p + 2] * w; a += w;
        }
        var o = (y * half + x) * 4;
        if (a > 0) { out[o] = r / a; out[o + 1] = g / a; out[o + 2] = b / a; }
        out[o + 3] = a / 4;
      }
    }
    return out;
  }

  function blockBytes(size) { var b = Math.max(1, Math.ceil(size / 4)); return b * b * 16; }

  function encodeDds(rgba, size) {
    var levels = Math.round(Math.log(size) / Math.LN2) + 1, total = 128;
    for (var l = 0, s = size; l < levels; l++, s = Math.max(1, s >> 1)) total += blockBytes(s);
    var out = new Uint8Array(total), view = new DataView(out.buffer);
    out.set([68, 68, 83, 32], 0);
    view.setUint32(4, 124, true);
    view.setUint32(8, 0xA1007, true);            // CAPS|HEIGHT|WIDTH|PIXELFORMAT|MIPMAPCOUNT|LINEARSIZE
    view.setUint32(12, size, true);
    view.setUint32(16, size, true);
    view.setUint32(20, blockBytes(size), true);
    view.setUint32(24, 1, true);
    view.setUint32(28, levels, true);
    view.setUint32(76, 32, true);
    view.setUint32(80, 4, true);                 // DDPF_FOURCC
    out.set([68, 88, 84, 53], 84);               // "DXT5"
    view.setUint32(108, 0x401008, true);         // TEXTURE|COMPLEX|MIPMAP
    var offset = 128, level = rgba;
    for (var s2 = size; ; s2 >>= 1) {
      offset = encodeLevel(level, s2, out, offset);
      if (s2 === 1) break;
      level = downscale(level, s2);
    }
    return out;
  }

  // ------------------------------------------------------------- analysis --
  // "Tintable" = the visible pixels are (almost) white: the mod multiplies
  // them by the farm colour. Coloured logos keep their own colours.
  function isTintable(rgba) {
    var visible = 0, white = 0;
    for (var p = 0; p < rgba.length; p += 4) {
      if (rgba[p + 3] < 128) continue;
      visible++;
      var mx = Math.max(rgba[p], rgba[p + 1], rgba[p + 2]), mn = Math.min(rgba[p], rgba[p + 1], rgba[p + 2]);
      if (mn >= 200 && mx - mn <= 24) white++;
    }
    return visible > 0 && white / visible >= 0.95;
  }

  function makeWhite(rgba) {
    var out = new Uint8ClampedArray(rgba);
    for (var p = 0; p < out.length; p += 4) { out[p] = 255; out[p + 1] = 255; out[p + 2] = 255; }
    return out;
  }

  function xmlEscape(text) {
    return String(text).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
  }

  function buildPackageXml(name, ddsBytes, tintable) {
    var b64 = toBase64(ddsBytes), lines = [];
    for (var i = 0; i < b64.length; i += 120) lines.push(b64.slice(i, i + 120));
    return '<?xml version="1.0" encoding="utf-8" standalone="no"?>\n' +
      "<!-- Farm Icon Color logo package: put this file in\n" +
      "     Documents/My Games/FarmingSimulator2025/modSettings/FS25_farmIconColor/customLogos/\n" +
      "     then open Logos in the farm edit dialog and press Import (INSERT). -->\n" +
      '<farmIconColorLogo version="1">\n' +
      '    <logo name="' + xmlEscape(name) + '" format="dds" bytes="' + ddsBytes.length +
      '" adler32="' + adler32(ddsBytes) + '" tintable="' + (tintable ? "true" : "false") + '">\n' +
      "        <data>\n" + lines.join("\n") + "\n        </data>\n" +
      "    </logo>\n</farmIconColorLogo>\n";
  }

  function sanitizeName(name) {
    return String(name || "").replace(/\.[^.]+$/, "").replace(/[\u0000-\u001f<>"&]/g, "").slice(0, 48).trim();
  }

  root.FarmIconColorDds = {
    LOGO_SIZE: LOGO_SIZE, MAX_BYTES: MAX_BYTES,
    adler32: adler32, toBase64: toBase64, parseDdsHeader: parseDdsHeader, decodeDds: decodeDds,
    encodeDds: encodeDds, isTintable: isTintable, makeWhite: makeWhite,
    buildPackageXml: buildPackageXml, sanitizeName: sanitizeName
  };
  if (typeof module !== "undefined") module.exports = root.FarmIconColorDds;
})(typeof window !== "undefined" ? window : globalThis);
