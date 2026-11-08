(function () {
  "use strict";

  var reduce = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  var fine = window.matchMedia("(pointer: fine)").matches;

  /* ---------- 载入 ---------- */
  var loader = document.getElementById("loader");
  var lbar = document.getElementById("lbar");
  var lnum = document.getElementById("lnum");
  var val = 0;

  function tick() {
    val += Math.max(1, Math.round((100 - val) * 0.12));
    if (val > 100) val = 100;
    lbar.style.transform = "scaleX(" + val / 100 + ")";
    lnum.textContent = String(val).padStart(3, "0") + " / 100";
    if (val < 100) {
      setTimeout(tick, 42);
    } else {
      setTimeout(function () {
        loader.classList.add("done");
        document.body.style.overflow = "";
      }, 240);
    }
  }

  if (loader) {
    document.body.style.overflow = "hidden";
    if (reduce) {
      loader.classList.add("done");
      document.body.style.overflow = "";
    } else {
      setTimeout(tick, 220);
    }
  }

  /* ---------- 导航 / 进度 ---------- */
  var nav = document.getElementById("nav");
  var pbar = document.getElementById("pbar");

  function onScroll() {
    var y = window.scrollY || window.pageYOffset;
    if (nav) nav.classList.toggle("stuck", y > 40);
    if (pbar) {
      var h = document.documentElement.scrollHeight - window.innerHeight;
      pbar.style.width = (h > 0 ? Math.min(1, y / h) : 0) * 100 + "%";
    }
  }
  window.addEventListener("scroll", onScroll, { passive: true });
  onScroll();

  /* ---------- 跑马灯 ---------- */
  var words = ["local first", "6 drawers", "zero ads", "no account", "no tracking", "v1.0.0", "WUKU", "offline ready", "打开即用", "本地存储"];
  var track = document.getElementById("mtrack");
  if (track) {
    var html = "";
    for (var r = 0; r < 2; r++) {
      for (var i = 0; i < words.length; i++) {
        html += "<span><b>" + words[i] + "</b><em></em></span>";
      }
    }
    track.innerHTML = html;
  }

  /* ---------- 进场 ---------- */
  var revealEls = [].slice.call(document.querySelectorAll("[data-reveal]"));
  if ("IntersectionObserver" in window && !reduce) {
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (e) {
        if (e.isIntersecting) {
          e.target.classList.add("in");
          io.unobserve(e.target);
        }
      });
    }, { threshold: 0.12, rootMargin: "0px 0px -8% 0px" });
    revealEls.forEach(function (el) { io.observe(el); });
  } else {
    revealEls.forEach(function (el) { el.classList.add("in"); });
  }

  /* ---------- 宣言逐行点亮 ---------- */
  var lines = [].slice.call(document.querySelectorAll(".manifesto .line"));
  if ("IntersectionObserver" in window) {
    var io2 = new IntersectionObserver(function (entries) {
      entries.forEach(function (e) { e.target.classList.toggle("on", e.isIntersecting); });
    }, { threshold: 0.55 });
    lines.forEach(function (el) { io2.observe(el); });
  } else {
    lines.forEach(function (el) { el.classList.add("on"); });
  }

  /* ---------- 数字 ---------- */
  var counted = false;
  var statEls = [].slice.call(document.querySelectorAll("[data-count]"));

  function runCount() {
    if (counted) return;
    counted = true;
    statEls.forEach(function (el) {
      var to = parseInt(el.getAttribute("data-count"), 10) || 0;
      if (reduce || to === 0) { el.textContent = to; return; }
      var s = null;
      function step(ts) {
        if (!s) s = ts;
        var p = Math.min(1, (ts - s) / 1400);
        var e = 1 - Math.pow(1 - p, 3);
        el.textContent = Math.round(to * e);
        if (p < 1) requestAnimationFrame(step);
      }
      requestAnimationFrame(step);
    });
  }

  if ("IntersectionObserver" in window) {
    var io3 = new IntersectionObserver(function (entries) {
      entries.forEach(function (e) {
        if (e.isIntersecting) { runCount(); io3.disconnect(); }
      });
    }, { threshold: 0.4 });
    var statsBox = document.querySelector(".stats");
    if (statsBox) io3.observe(statsBox);
  } else {
    runCount();
  }

  /* ---------- 3D 跟随 ---------- */
  var tilt = document.getElementById("tilt");
  var stage = document.getElementById("stage");
  var tx = 0, ty = 0, cx = 0, cy = 0, raf = null;

  if (tilt && stage && fine && !reduce) {
    stage.addEventListener("pointermove", function (ev) {
      var r = stage.getBoundingClientRect();
      tx = ((ev.clientX - r.left) / r.width - 0.5) * 2;
      ty = ((ev.clientY - r.top) / r.height - 0.5) * 2;
      if (!raf) raf = requestAnimationFrame(loop);
    });
    stage.addEventListener("pointerleave", function () {
      tx = 0; ty = 0;
      if (!raf) raf = requestAnimationFrame(loop);
    });
    function loop() {
      cx += (tx - cx) * 0.08;
      cy += (ty - cy) * 0.08;
      tilt.style.setProperty("--ry", (-13 - cx * 7).toFixed(2));
      tilt.style.setProperty("--rx", (6 + cy * 5).toFixed(2));
      if (Math.abs(tx - cx) > 0.001 || Math.abs(ty - cy) > 0.001) {
        requestAnimationFrame(loop);
      } else {
        raf = null;
      }
    }
    raf = requestAnimationFrame(loop);
  } else if (tilt) {
    tilt.style.setProperty("--ry", "-13");
    tilt.style.setProperty("--rx", "6");
  }

  /* ---------- 截图卡倾斜 ---------- */
  if (fine && !reduce) {
    [].slice.call(document.querySelectorAll(".tilt-s")).forEach(function (el) {
      var box = el.closest(".shot");
      if (!box) return;
      box.addEventListener("pointermove", function (ev) {
        var r = box.getBoundingClientRect();
        var px = (ev.clientX - r.left) / r.width - 0.5;
        var py = (ev.clientY - r.top) / r.height - 0.5;
        el.style.setProperty("--ry", (-6 - px * 8).toFixed(2));
        el.style.setProperty("--rx", (3 + py * 6).toFixed(2));
      });
      box.addEventListener("pointerleave", function () {
        el.style.setProperty("--ry", "-6");
        el.style.setProperty("--rx", "3");
      });
    });
  }

  /* ---------- 卡片光斑 ---------- */
  [].slice.call(document.querySelectorAll(".card")).forEach(function (c) {
    c.addEventListener("pointermove", function (ev) {
      var r = c.getBoundingClientRect();
      c.style.setProperty("--mx", (ev.clientX - r.left) + "px");
      c.style.setProperty("--my", (ev.clientY - r.top) + "px");
    });
  });

  /* ---------- 磁吸按钮 ---------- */
  if (fine && !reduce) {
    [].slice.call(document.querySelectorAll(".magnetic")).forEach(function (b) {
      b.addEventListener("pointermove", function (ev) {
        var r = b.getBoundingClientRect();
        var dx = (ev.clientX - r.left - r.width / 2) * 0.12;
        var dy = (ev.clientY - r.top - r.height / 2) * 0.18;
        b.style.transform = "translate(" + dx + "px," + dy + "px)";
      });
      b.addEventListener("pointerleave", function () { b.style.transform = ""; });
    });
  }

  /* ---------- 自定义光标 ---------- */
  if (fine) {
    var ring = document.getElementById("ring");
    if (ring) {
      var mx = 0, my = 0, rxx = 0, ryy = 0;
      document.addEventListener("pointermove", function (ev) { mx = ev.clientX; my = ev.clientY; });
      (function follow() {
        rxx += (mx - rxx) * 0.18;
        ryy += (my - ryy) * 0.18;
        ring.style.transform = "translate3d(" + rxx + "px," + ryy + "px,0)";
        requestAnimationFrame(follow);
      })();
      document.addEventListener("pointerover", function (ev) {
        var t = ev.target.closest("a,button,.card,.shot");
        ring.classList.toggle("big", !!t);
      });
    }
  }

  /* ---------- 锚点偏移（避开固定导航） ---------- */
  [].slice.call(document.querySelectorAll('a[href^="#"]')).forEach(function (a) {
    a.addEventListener("click", function (ev) {
      var id = a.getAttribute("href");
      if (id.length < 2) return;
      var el = document.querySelector(id);
      if (!el) return;
      ev.preventDefault();
      var top = el.getBoundingClientRect().top + window.scrollY - 58;
      window.scrollTo({ top: top, behavior: reduce ? "auto" : "smooth" });
    });
  });
})();
