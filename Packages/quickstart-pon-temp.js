(function () {
  'use strict';

  var PON_DEV = 'pon0';
  var R = 62;
  var CIRC = 2 * Math.PI * R;
  var COLOR = '#FF9800';

  function clamp(n, min, max) { return Math.max(min, Math.min(max, n)); }

  function findCpuTempChart() {
    var charts = document.querySelectorAll('.system .chart');
    for (var i = 0; i < charts.length; i++) {
      if ((charts[i].textContent || '').indexOf('CPU温度') !== -1)
        return charts[i];
    }
    return null;
  }

  function findMemoryChart() {
    var charts = document.querySelectorAll('.system .chart');
    for (var i = 0; i < charts.length; i++) {
      if ((charts[i].textContent || '').indexOf('内存使用率') !== -1)
        return charts[i];
    }
    return null;
  }

  function makeRing(color) {
    var NS = 'http://www.w3.org/2000/svg';
    var svg = document.createElementNS(NS, 'svg');
    svg.setAttribute('viewBox', '0 0 150 150');
    svg.setAttribute('width', '150');
    svg.setAttribute('height', '150');
    svg.style.position = 'absolute';
    svg.style.inset = '0';

    var track = document.createElementNS(NS, 'circle');
    track.setAttribute('cx', '75');
    track.setAttribute('cy', '75');
    track.setAttribute('r', String(R));
    track.setAttribute('fill', 'none');
    track.setAttribute('stroke', 'rgba(120,130,150,0.18)');
    track.setAttribute('stroke-width', '11');

    var arc = document.createElementNS(NS, 'circle');
    arc.setAttribute('id', 'pon-temp-ring');
    arc.setAttribute('cx', '75');
    arc.setAttribute('cy', '75');
    arc.setAttribute('r', String(R));
    arc.setAttribute('fill', 'none');
    arc.setAttribute('stroke', color);
    arc.setAttribute('stroke-width', '11');
    arc.setAttribute('stroke-linecap', 'round');
    arc.setAttribute('transform', 'rotate(-90 75 75)');
    arc.setAttribute('stroke-dasharray', String(CIRC));
    arc.setAttribute('stroke-dashoffset', String(CIRC));

    svg.appendChild(track);
    svg.appendChild(arc);
    return svg;
  }

  function addCard() {
    if (document.getElementById('pon-temp-chart')) return true;
    var cpu = findCpuTempChart();
    var anchor = findMemoryChart() || cpu;
    if (!cpu || !anchor) return false;

    var clone = cpu.cloneNode(true);
    clone.id = 'pon-temp-chart';
    var dom = clone.querySelector('.chart-dom');
    if (dom) dom.parentNode.removeChild(dom);

    var wrapper = clone.querySelector('.pie-chart-wrapper');
    if (!wrapper) return false;
    wrapper.insertBefore(makeRing(COLOR), wrapper.firstChild);

    var icon = clone.querySelector('.center-icon');
    if (icon) {
      var paths = icon.querySelectorAll('path');
      for (var i = 0; i < paths.length; i++) paths[i].setAttribute('fill', COLOR);
    }

    var label = clone.querySelector('.center-label');
    if (label) {
      label.textContent = '--℃';
      label.style.color = COLOR;
    }

    var caption = clone.lastElementChild;
    if (caption && caption.tagName === 'DIV') caption.textContent = 'PON温度';

    anchor.parentNode.insertBefore(clone, anchor.nextSibling);
    return true;
  }

  function updateRing(t) {
    var arc = document.getElementById('pon-temp-ring');
    var card = document.getElementById('pon-temp-chart');
    if (!arc || !card) return;
    arc.setAttribute('stroke', COLOR);
    var pct = (t == null || !isFinite(t)) ? 0 : clamp((t - 20) / 60 * 100, 0, 100);
    arc.setAttribute('stroke-dashoffset', String(CIRC * (1 - pct / 100)));
    var label = card.querySelector('.center-label');
    if (label) {
      label.textContent = (t == null || !isFinite(t)) ? '--℃' : t.toFixed(1) + '℃';
      label.style.color = COLOR;
    }
  }

  function refresh() {
    addCard();
    if (!window.L || typeof L.require !== 'function') return;
    L.require('fs').then(function (fs) {
      return fs.exec_direct('/usr/sbin/ponctl', ['--device', PON_DEV, 'status', '--json']);
    }).then(function (out) {
      var data = JSON.parse(out);
      var t = data && data.frontend ? data.frontend.temperature_celsius : null;
      updateRing(typeof t === 'number' && isFinite(t) ? t : null);
    }).catch(function () {
      updateRing(null);
    });
  }

  setInterval(refresh, 5000);
  refresh();
})();
