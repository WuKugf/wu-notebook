/* WU本子 · 应用逻辑
   纯前端 / 无框架 / 无构建。数据读写全部经由 WStore（js/store.js）。 */
(function () {
  "use strict";

  var WStore = window.WStore;
  var root = document.documentElement;
  var viewRoot = document.getElementById("viewRoot");
  var modalRoot = document.getElementById("modalRoot");
  var toastEl = document.getElementById("toast");
  var searchWrap = document.getElementById("searchWrap");
  var searchInput = document.getElementById("searchInput");
  var newBtn = document.getElementById("newBtn");
  var viewTitle = document.getElementById("viewTitle");
  var viewKicker = document.getElementById("viewKicker");
  var fileInput = document.getElementById("fileInput");

  var VIEW_META = {
    vault: { title: "密码本", kicker: "WU 本子 / VAULT", search: "搜索名称或账号", newLabel: "＋ 新建密码" },
    memos: { title: "备忘录", kicker: "WU 本子 / MEMO", search: "搜索标题、正文或标签", newLabel: "＋ 新建备忘" },
    todos: { title: "待办", kicker: "WU 本子 / TODO", search: "搜索待办或子任务", newLabel: "＋ 新建待办" },
    days: { title: "倒数日", kicker: "WU 本子 / DAYS", search: "搜索日子", newLabel: "＋ 记一个日子" },
    files: { title: "文件库", kicker: "WU 本子 / FILES", search: "搜索文件名", newLabel: "＋ 导入文件" },
    settings: { title: "设置", kicker: "WU 本子 / SETTINGS", search: "", newLabel: "" }
  };

  var state = {
    view: "vault",
    search: { vault: "", memos: "", todos: "", days: "", files: "" },
    vaultUnlocked: false,
    revealed: {},
    todoFilter: "all",
    dayFilter: "all",
    expanded: {},
    files: [],
    fileFallback: false,
    fileToken: 0,
    previewUrl: null,
    filesLoaded: false
  };

  var toastTimer = null;

  /* ---------------- 小工具 ---------------- */
  function $(sel, ctx) { return (ctx || document).querySelector(sel); }
  function $$(sel, ctx) { return Array.from((ctx || document).querySelectorAll(sel)); }

  function esc(v) {
    return String(v == null ? "" : v)
      .replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;").replace(/'/g, "&#39;");
  }

  function uid(prefix) {
    return (prefix || "i") + "_" + Date.now().toString(36) + Math.random().toString(36).slice(2, 7);
  }

  function toast(msg) {
    toastEl.textContent = msg;
    toastEl.classList.add("show");
    clearTimeout(toastTimer);
    toastTimer = setTimeout(function () { toastEl.classList.remove("show"); }, 2200);
  }

  function pad2(n) { return String(n).padStart(2, "0"); }

  function fmtDate(ts) {
    if (!ts) return "";
    var d = new Date(ts);
    return d.getFullYear() + "." + pad2(d.getMonth() + 1) + "." + pad2(d.getDate());
  }

  function fmtMD(iso) {
    if (!iso) return "";
    var p = iso.split("-");
    return p[1] + "." + p[2];
  }

  function parseISO(iso) {
    var p = String(iso).split("-").map(Number);
    return new Date(p[0], (p[1] || 1) - 1, p[2] || 1);
  }

  function dayDiff(iso) {
    if (!iso) return 0;
    var t = parseISO(iso);
    var n = new Date();
    var a = Date.UTC(t.getFullYear(), t.getMonth(), t.getDate());
    var b = Date.UTC(n.getFullYear(), n.getMonth(), n.getDate());
    return Math.round((a - b) / 86400000);
  }

  var WEEK = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"];

  function weekday(iso) {
    return WEEK[parseISO(iso).getDay()];
  }

  function fmtSize(bytes) {
    if (!bytes) return "0 B";
    if (bytes < 1024) return bytes + " B";
    if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + " KB";
    if (bytes < 1024 * 1024 * 1024) return (bytes / 1024 / 1024).toFixed(1) + " MB";
    return (bytes / 1024 / 1024 / 1024).toFixed(2) + " GB";
  }

  function copyText(text) {
    var done = function () { toast("已复制到剪贴板"); };
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(text).then(done).catch(function () { legacyCopy(text, done); });
    } else {
      legacyCopy(text, done);
    }
  }

  function legacyCopy(text, cb) {
    var ta = document.createElement("textarea");
    ta.value = text;
    ta.style.position = "fixed";
    ta.style.opacity = "0";
    document.body.appendChild(ta);
    ta.select();
    try { document.execCommand("copy"); cb(); } catch (e) { toast("复制失败，请手动选择"); }
    document.body.removeChild(ta);
  }

  function findItem(name, id) {
    return WStore.list(name).filter(function (x) { return x.id === id; })[0] || null;
  }

  /* ---------------- 图标 ---------------- */
  var ICON = {
    close: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M6 6l12 12M18 6L6 18"/></svg>',
    eye: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M3 12s3.5-6 9-6 9 6 9 6-3.5 6-9 6-9-6-9-6z"/><circle cx="12" cy="12" r="2.6"/></svg>',
    eyeOff: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M3 12s3.5-6 9-6 9 6 9 6-3.5 6-9 6-9-6-9-6z"/><path d="M4 4l16 16"/></svg>',
    copy: '<svg viewBox="0 0 24 24" aria-hidden="true"><rect x="8" y="8" width="11" height="12" rx="2"/><path d="M16 8V6a2 2 0 0 0-2-2H6a2 2 0 0 0-2 2v9a2 2 0 0 0 2 2h2"/></svg>',
    pin: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M9 3h6l-1 6 4 4v2H6v-2l4-4z"/><path d="M12 15v5"/></svg>',
    edit: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M4 20h4l10-10a2.8 2.8 0 0 0-4-4L4 16z"/><path d="M13.5 6.5l4 4"/></svg>',
    trash: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M4 7h16"/><path d="M7 7V5h10v2"/><path d="M6 7l1 13h10l1-13"/><path d="M10 11v6M14 11v6"/></svg>',
    archive: '<svg viewBox="0 0 24 24" aria-hidden="true"><rect x="3.5" y="4" width="17" height="4.5" rx="1"/><path d="M5 8.5V19h14V8.5"/><path d="M9 12.5h6"/></svg>',
    restore: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M4 12a8 8 0 1 0 2.4-5.7"/><path d="M4 4v4h4"/></svg>',
    plus: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 5v14M5 12h14"/></svg>',
    check: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M5 12.5l4.5 4.5L19 7.5"/></svg>',
    chevron: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M6 9l6 6 6-6"/></svg>',
    lock: '<svg viewBox="0 0 24 24" aria-hidden="true"><rect x="4.5" y="10.5" width="15" height="10.5" rx="3"/><path d="M8 10.5V7.5a4 4 0 0 1 8 0v3"/><circle cx="12" cy="15.5" r="1.4"/></svg>',
    vault: '<svg viewBox="0 0 24 24" aria-hidden="true"><rect x="3.5" y="4.5" width="17" height="15" rx="2.5"/><circle cx="12" cy="12" r="3.4"/><path d="M12 8.6v-1M12 15.4v1M15.4 12h1M7.6 12h1"/></svg>',
    memo: '<svg viewBox="0 0 24 24" aria-hidden="true"><rect x="5" y="3.5" width="14" height="17" rx="2.5"/><path d="M8.5 8h7M8.5 12h7M8.5 16h4"/></svg>',
    todo: '<svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="8"/><path d="M8.5 12.2l2.5 2.5 4.5-5"/></svg>',
    day: '<svg viewBox="0 0 24 24" aria-hidden="true"><rect x="3.5" y="5" width="17" height="15.5" rx="2.5"/><path d="M3.5 9.5h17M8 3v4M16 3v4"/></svg>',
    file: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M6 3.5h7l5 5v12H5v-17z"/><path d="M13 3.5v5h5"/></svg>',
    image: '<svg viewBox="0 0 24 24" aria-hidden="true"><rect x="3.5" y="5" width="17" height="14" rx="2.5"/><circle cx="9" cy="10" r="1.6"/><path d="M5 17l5-5 3 3 3-2.5 4 4"/></svg>',
    audio: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M5 9h4l5-4v14l-5-4H5z"/><path d="M17 9.5c1.5 1.5 1.5 3.5 0 5"/></svg>',
    video: '<svg viewBox="0 0 24 24" aria-hidden="true"><rect x="3.5" y="6" width="12" height="12" rx="2"/><path d="M15.5 10l5-3v10l-5-3z"/></svg>',
    pdf: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M6 3.5h7l5 5v12H5v-17z"/><path d="M13 3.5v5h5"/><path d="M8 16v-4h1.6a1.2 1.2 0 0 1 0 2.4H8M13 16v-4h2M13 14h1.5"/></svg>',
    download: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 4v11M8 11l4 4 4-4"/><path d="M5 19h14"/></svg>'
  };

  /* ---------------- 主题 / 字号 ---------------- */
  var THEMES = [
    { id: "ink", name: "墨绿", desc: "深墨底 · 米白字", swatch: ["#060807", "#93c9b7", "#f2efe7"] },
    { id: "night", name: "深夜", desc: "纯黑 · 冷薄荷", swatch: ["#000000", "#86c3cc", "#e9eeec"] },
    { id: "cream", name: "米白", desc: "纸感底 · 深绿字", swatch: ["#f2efe7", "#2f5148", "#0b1411"] }
  ];

  var SIZES = [
    { id: "sm", name: "小" },
    { id: "md", name: "标准" },
    { id: "lg", name: "大" }
  ];

  function applyTheme(theme, size) {
    root.setAttribute("data-theme", theme);
    root.setAttribute("data-size", size);
    var meta = document.querySelector('meta[name="theme-color"]');
    if (meta) meta.setAttribute("content", theme === "cream" ? "#f2efe7" : "#060807");
  }

  /* ---------------- 顶部与导航 ---------------- */
  function updateChrome() {
    var meta = VIEW_META[state.view];
    viewTitle.textContent = meta.title;
    viewKicker.textContent = meta.kicker;

    var hasSearch = !!meta.search;
    searchWrap.style.display = hasSearch ? "" : "none";
    searchInput.placeholder = meta.search || "搜索";
    searchInput.value = state.search[state.view] || "";

    var auth = WStore.vault.getAuth();
    var canCreate = state.view !== "settings" &&
      (state.view !== "vault" || (auth && state.vaultUnlocked));
    newBtn.hidden = !canCreate;
    newBtn.innerHTML = esc(meta.newLabel || "＋ 新建");

    $$("[data-view]").forEach(function (el) {
      el.classList.toggle("active", el.getAttribute("data-view") === state.view);
    });
  }

  function updateCounts() {
    var auth = WStore.vault.getAuth();
    var counts = {
      vault: (auth && state.vaultUnlocked) ? WStore.list("vault").length : 0,
      memos: WStore.list("memos").length,
      todos: WStore.list("todos").filter(function (t) { return !t.done && !t.archived; }).length,
      days: WStore.list("days").length,
      files: state.files.length
    };
    $$("[data-count-for]").forEach(function (el) {
      var k = el.getAttribute("data-count-for");
      var n = counts[k] || 0;
      if (k === "vault" && !(auth && state.vaultUnlocked)) {
        el.textContent = "锁";
        el.classList.add("is-lock");
      } else {
        el.textContent = n > 0 ? String(n) : "";
        el.classList.remove("is-lock");
      }
    });
  }

  /* ---------------- 打开视图 ---------------- */
  function navigate(view) {
    if (!VIEW_META[view]) view = "vault";
    if (location.hash.slice(1) === view) {
      applyView(view);
    } else {
      location.hash = view;
    }
  }

  function applyView(view) {
    if (!VIEW_META[view]) view = "vault";
    state.view = view;
    updateChrome();
    render();
  }

  window.addEventListener("hashchange", function () {
    applyView(location.hash.slice(1) || "vault");
  });
  window.addEventListener("popstate", function () {
    applyView(location.hash.slice(1) || "vault");
  });

  /* ---------------- 渲染分发 ---------------- */
  function refresh() {
    updateChrome();
    updateCounts();
    render();
  }

  function render() {
    var v = state.view;
    if (v === "vault") renderVault();
    else if (v === "memos") renderMemos();
    else if (v === "todos") renderTodos();
    else if (v === "days") renderDays();
    else if (v === "files") renderFiles();
    else if (v === "settings") renderSettings();
    updateCounts();
  }

  function emptyBlock(icon, title, text, actionLabel, act) {
    return '<div class="empty">' +
      '<div class="empty-icon">' + icon + '</div>' +
      '<h3>' + esc(title) + '</h3>' +
      '<p>' + esc(text) + '</p>' +
      (actionLabel ? '<button class="btn-ghost" data-act="' + act + '">' + esc(actionLabel) + '</button>' : "") +
      '</div>';
  }

  /* ---------------- 密码本 ---------------- */
  function renderVault() {
    var auth = WStore.vault.getAuth();

    if (!auth) {
      viewRoot.innerHTML =
        '<div class="gate">' +
          '<div class="gate-card">' +
            '<div class="gate-icon">' + ICON.vault + '</div>' +
            '<p class="mono">VAULT · FIRST RUN</p>' +
            '<h2>先给密码本上一把锁</h2>' +
            '<p class="gate-text">这把密码只属于密码本，和备忘录、待办分开。它保存在本机，不上传任何地方。</p>' +
            '<form id="vault-setup" class="gate-form" novalidate>' +
              '<div class="field"><label for="vp1">密码本密码</label>' +
                '<input id="vp1" name="password" type="password" autocomplete="new-password" placeholder="至少 4 个字符" maxlength="64"></div>' +
              '<div class="field"><label for="vp2">再输一次</label>' +
                '<input id="vp2" name="confirm" type="password" autocomplete="new-password" placeholder="确认同一把密码" maxlength="64"></div>' +
              '<p class="form-error" data-error></p>' +
              '<button class="act-primary gate-btn" type="submit">设置并进入</button>' +
            '</form>' +
            '<p class="gate-note">忘记密码将无法找回条目，只能清空密码本重来。</p>' +
          '</div>' +
        '</div>';
      var first = $("#vp1", viewRoot);
      if (first) setTimeout(function () { first.focus(); }, 60);
      return;
    }

    if (!state.vaultUnlocked) {
      viewRoot.innerHTML =
        '<div class="gate">' +
          '<div class="gate-card">' +
            '<div class="gate-icon locked">' + ICON.lock + '</div>' +
            '<p class="mono">VAULT · LOCKED</p>' +
            '<h2>密码本已上锁</h2>' +
            '<p class="gate-text">输入密码本自己的密码。打开页面后会自动重新上锁。</p>' +
            '<form id="vault-unlock" class="gate-form" novalidate>' +
              '<div class="field"><label for="vpu">密码</label>' +
                '<input id="vpu" name="password" type="password" autocomplete="current-password" placeholder="输入密码本密码" maxlength="64"></div>' +
              '<p class="form-error" data-error></p>' +
              '<button class="act-primary gate-btn" type="submit">解锁</button>' +
            '</form>' +
            '<button class="link-btn" data-act="vault-forgot">忘记密码？</button>' +
          '</div>' +
        '</div>';
      var input = $("#vpu", viewRoot);
      if (input) setTimeout(function () { input.focus(); }, 60);
      return;
    }

    var q = (state.search.vault || "").trim().toLowerCase();
    var entries = WStore.list("vault").filter(function (e) {
      if (!q) return true;
      return [e.name, e.account, e.note, e.password].join(" ").toLowerCase().indexOf(q) > -1;
    }).sort(function (a, b) { return (b.createdAt || 0) - (a.createdAt || 0); });

    var all = WStore.list("vault").length;

    var html =
      '<div class="view-bar">' +
        '<span class="bar-note"><i class="dot"></i>已解锁 · ' + all + ' 条密码</span>' +
        '<button class="btn-ghost sm" data-act="vault-lock">' + ICON.lock + '<span>重新上锁</span></button>' +
      '</div>';

    if (!entries.length) {
      html += emptyBlock(ICON.vault, q ? "没有匹配的条目" : "密码本还是空的",
        q ? "换个关键词再找找。" : "把常用的账号与密码收进来，默认以掩码显示。",
        q ? "" : "新建第一条密码", "vault-new");
      viewRoot.innerHTML = html;
      return;
    }

    html += '<div class="entry-grid">' + entries.map(function (e) {
      var shown = !!state.revealed[e.id];
      var mask = "•".repeat(Math.min(18, Math.max(8, (e.password || "").length)));
      return '<article class="entry-card">' +
        '<div class="entry-top"><h3>' + esc(e.name) + '</h3>' +
          '<span class="entry-time">' + fmtDate(e.createdAt) + '</span></div>' +
        (e.account ? '<div class="entry-account">' + esc(e.account) + '</div>' : "") +
        '<div class="entry-secret">' +
          '<span class="secret-text' + (shown ? " shown" : "") + '">' + esc(shown ? (e.password || "") : mask) + '</span>' +
          '<button class="secret-btn" data-act="vault-eye" data-id="' + e.id + '" aria-label="' + (shown ? "隐藏密码" : "查看密码") + '">' +
            (shown ? ICON.eyeOff : ICON.eye) + '</button>' +
        '</div>' +
        (e.note ? '<p class="entry-note">' + esc(e.note) + '</p>' : "") +
        '<div class="entry-actions">' +
          '<button data-act="vault-copy" data-id="' + e.id + '">' + ICON.copy + '<span>复制</span></button>' +
          '<button data-act="vault-edit" data-id="' + e.id + '">' + ICON.edit + '<span>编辑</span></button>' +
          '<button class="danger" data-act="vault-del" data-id="' + e.id + '">' + ICON.trash + '<span>删除</span></button>' +
        '</div>' +
      '</article>';
    }).join("") + '</div>';

    viewRoot.innerHTML = html;
  }

  function openVaultEditor(id) {
    if (!state.vaultUnlocked) { toast("请先解锁密码本"); return; }
    var entry = id ? findItem("vault", id) : null;
    if (id && !entry) return;

    formModal({
      kicker: "密码本 / ENTRY",
      title: entry ? "编辑密码" : "新建密码",
      saveLabel: entry ? "保存修改" : "保存条目",
      body:
        '<div class="field"><label>名称</label><input name="name" value="' + esc(entry ? entry.name : "") + '" placeholder="例如：邮箱、微信、路由器" maxlength="80" required></div>' +
        '<div class="field"><label>账号 / 用户</label><input name="account" value="' + esc(entry ? entry.account : "") + '" placeholder="账号、网址或后台地址" maxlength="120"></div>' +
        '<div class="field"><label>密码</label><input name="password" value="' + esc(entry ? entry.password : "") + '" placeholder="要记住的那串字符" maxlength="200" required></div>' +
        '<div class="field"><label>备注</label><textarea name="note" rows="3" placeholder="可留空">' + esc(entry ? entry.note : "") + '</textarea></div>' +
        '<p class="form-error" data-error></p>',
      onSubmit: function (form) {
        var fd = new FormData(form);
        var name = String(fd.get("name") || "").trim();
        var password = String(fd.get("password") || "");
        if (!name) { setError(form, "请填写名称"); return; }
        if (!password) { setError(form, "请填写密码"); return; }

        var list = WStore.list("vault");
        if (entry) {
          entry.name = name;
          entry.account = String(fd.get("account") || "").trim();
          entry.password = password;
          entry.note = String(fd.get("note") || "").trim();
          entry.updatedAt = Date.now();
        } else {
          list.unshift({
            id: uid("v"),
            name: name,
            account: String(fd.get("account") || "").trim(),
            password: password,
            note: String(fd.get("note") || "").trim(),
            createdAt: Date.now(),
            updatedAt: Date.now()
          });
        }
        WStore.saveList("vault", list);
        closeModal();
        refresh();
        toast(entry ? "已保存修改" : "已保存密码");
      }
    });
  }

  /* ---------------- 备忘录 ---------------- */
  function renderMemos() {
    var q = (state.search.memos || "").trim().toLowerCase();
    var all = WStore.list("memos");
    var list = all.filter(function (m) {
      if (!q) return true;
      return [m.title, m.body, (m.tags || []).join(" ")].join(" ").toLowerCase().indexOf(q) > -1;
    }).sort(function (a, b) {
      if (!!b.pinned !== !!a.pinned) return b.pinned ? 1 : -1;
      return (b.updatedAt || 0) - (a.updatedAt || 0);
    });

    var html = '<div class="view-bar"><span class="bar-note"><i class="dot"></i>' +
      all.length + ' 条备忘 · ' + all.filter(function (m) { return m.pinned; }).length + ' 条置顶</span>' +
      '<span class="bar-hint">点击卡片编辑</span></div>';

    if (!list.length) {
      html += emptyBlock(ICON.memo, q ? "没有匹配的备忘" : "还没有写下什么",
        q ? "试试别的关键词，或清空搜索。" : "标题、正文、标签，想到什么就先记下来。",
        q ? "" : "写第一条备忘", "memo-new");
      viewRoot.innerHTML = html;
      return;
    }

    html += '<div class="memo-grid">' + list.map(function (m) {
      return '<article class="memo-card' + (m.pinned ? " is-pinned" : "") + '" data-act="memo-edit" data-id="' + m.id + '">' +
        '<button class="pin-btn' + (m.pinned ? " on" : "") + '" data-act="memo-pin" data-id="' + m.id + '" aria-label="' + (m.pinned ? "取消置顶" : "置顶") + '">' + ICON.pin + '</button>' +
        '<h3>' + esc(m.title || "无标题") + '</h3>' +
        '<p class="memo-body">' + esc(m.body || "") + '</p>' +
        ((m.tags && m.tags.length) ? '<div class="tag-row">' + m.tags.map(function (t) {
          return '<span class="tag">#' + esc(t) + '</span>';
        }).join("") + '</div>' : "") +
        '<div class="memo-foot"><span>' + fmtDate(m.updatedAt || m.createdAt) + '</span><span>' + (m.body || "").length + ' 字</span></div>' +
      '</article>';
    }).join("") + '</div>';

    viewRoot.innerHTML = html;
  }

  function openMemoEditor(id) {
    var memo = id ? findItem("memos", id) : null;
    if (id && !memo) return;
    formModal({
      kicker: "备忘录 / NOTE",
      title: memo ? "编辑备忘" : "新建备忘",
      wide: true,
      saveLabel: memo ? "保存修改" : "保存备忘",
      body:
        '<div class="field"><label>标题</label><input name="title" value="' + esc(memo ? memo.title : "") + '" placeholder="一句话的标题" maxlength="120"></div>' +
        '<div class="field"><label>正文</label><textarea name="body" rows="9" placeholder="写点什么…">' + esc(memo ? memo.body : "") + '</textarea></div>' +
        '<div class="field-row">' +
          '<div class="field"><label>标签</label><input name="tags" value="' + esc(memo ? (memo.tags || []).join(", ") : "") + '" placeholder="生活, 工作, 灵感"></div>' +
          '<label class="switch"><input type="checkbox" name="pinned"' + (memo && memo.pinned ? " checked" : "") + '><span class="switch-track"><i></i></span><span class="switch-label">置顶</span></label>' +
        '</div>' +
        '<p class="form-error" data-error></p>',
      onSubmit: function (form) {
        var fd = new FormData(form);
        var title = String(fd.get("title") || "").trim();
        var body = String(fd.get("body") || "");
        if (!title && !body.trim()) { setError(form, "标题和正文至少写一样"); return; }
        var tags = String(fd.get("tags") || "").split(/[,，\s]+/).map(function (t) { return t.trim(); }).filter(Boolean);
        tags = Array.from(new Set(tags)).slice(0, 8);
        var pinned = !!form.querySelector('[name="pinned"]').checked;

        var list = WStore.list("memos");
        if (memo) {
          memo.title = title;
          memo.body = body;
          memo.tags = tags;
          memo.pinned = pinned;
          memo.updatedAt = Date.now();
        } else {
          list.unshift({
            id: uid("m"), title: title, body: body, tags: tags, pinned: pinned,
            createdAt: Date.now(), updatedAt: Date.now()
          });
        }
        WStore.saveList("memos", list);
        closeModal();
        refresh();
        toast(memo ? "已保存修改" : "已保存备忘");
      }
    });
  }

  /* ---------------- 待办 ---------------- */
  var PRIORITY = {
    high: { label: "高", rank: 0 },
    mid: { label: "中", rank: 1 },
    low: { label: "低", rank: 2 }
  };

  function dueInfo(due, done) {
    if (!due) return null;
    if (done) return { label: fmtMD(due), tone: "muted" };
    var d = dayDiff(due);
    if (d < 0) return { label: "逾期 " + (-d) + " 天", tone: "danger" };
    if (d === 0) return { label: "今天到期", tone: "warn" };
    if (d === 1) return { label: "明天到期", tone: "warn" };
    if (d <= 7) return { label: "还有 " + d + " 天", tone: "" };
    return { label: fmtMD(due), tone: "" };
  }

  function todoMatches(t, q) {
    if (!q) return true;
    var hay = [t.title, t.note].concat((t.subtasks || []).map(function (s) { return s.text; })).join(" ");
    return hay.toLowerCase().indexOf(q) > -1;
  }

  function sortTodos(list) {
    return list.slice().sort(function (a, b) {
      if (!!a.done !== !!b.done) return a.done ? 1 : -1;
      if (a.due && b.due && a.due !== b.due) return a.due < b.due ? -1 : 1;
      if (!!a.due !== !!b.due) return a.due ? -1 : 1;
      var pa = (PRIORITY[a.priority] || PRIORITY.mid).rank;
      var pb = (PRIORITY[b.priority] || PRIORITY.mid).rank;
      if (pa !== pb) return pa - pb;
      return (b.createdAt || 0) - (a.createdAt || 0);
    });
  }

  function renderTodos() {
    var all = WStore.list("todos");
    var q = (state.search.todos || "").trim().toLowerCase();
    var f = state.todoFilter;

    var counts = {
      all: all.filter(function (t) { return !t.archived; }).length,
      open: all.filter(function (t) { return !t.archived && !t.done; }).length,
      done: all.filter(function (t) { return !t.archived && t.done; }).length,
      archived: all.filter(function (t) { return t.archived; }).length
    };

    var filtered = all.filter(function (t) {
      if (f === "all") return !t.archived;
      if (f === "open") return !t.archived && !t.done;
      if (f === "done") return !t.archived && t.done;
      return !!t.archived;
    }).filter(function (t) { return todoMatches(t, q); });

    filtered = sortTodos(filtered);

    var chips = [
      ["all", "全部", counts.all],
      ["open", "进行中", counts.open],
      ["done", "已完成", counts.done],
      ["archived", "归档", counts.archived]
    ].map(function (x) {
      return '<button class="chip' + (f === x[0] ? " on" : "") + '" data-act="todo-filter" data-filter="' + x[0] + '">' +
        x[1] + '<em>' + x[2] + '</em></button>';
    }).join("");

    var html = '<div class="filter-row">' + chips + '</div>';

    if (!filtered.length) {
      html += emptyBlock(ICON.todo,
        q ? "没有匹配的待办" : (f === "archived" ? "归档是空的" : "眼前没有待办"),
        q ? "换个词再找找。" : (f === "archived" ? "归档的待办会收在这里。" : "把要做的事拆成小步，勾掉一件是一件。"),
        q ? "" : (f === "archived" ? "" : "新建第一件待办"), "todo-new");
      viewRoot.innerHTML = html;
      return;
    }

    html += '<div class="todo-list">' + filtered.map(function (t) {
      var done = !!t.done;
      var subs = t.subtasks || [];
      var subDone = subs.filter(function (s) { return s.done; }).length;
      var due = dueInfo(t.due, done);
      var pr = PRIORITY[t.priority] || PRIORITY.mid;
      var expanded = !!state.expanded[t.id];

      return '<article class="todo-item' + (done ? " is-done" : "") + (t.archived ? " is-archived" : "") + '">' +
        '<button class="todo-check' + (done ? " on" : "") + '" data-act="todo-toggle" data-id="' + t.id + '" aria-label="' + (done ? "标记未完成" : "标记完成") + '">' +
          (done ? ICON.check : "") + '</button>' +

        '<div class="todo-main">' +
          '<div class="todo-title-row">' +
            '<h3>' + esc(t.title) + '</h3>' +
            '<span class="prio ' + esc(t.priority || "mid") + '">' + pr.label + '</span>' +
            (due ? '<span class="due ' + due.tone + '">' + esc(due.label) + '</span>' : "") +
            (t.archived ? '<span class="arch-tag">已归档</span>' : "") +
          '</div>' +

          (t.note ? '<p class="todo-note">' + esc(t.note) + '</p>' : "") +

          (subs.length ?
            '<div class="sub-wrap">' +
              '<button class="sub-summary" data-act="todo-expand" data-id="' + t.id + '">' +
                ICON.chevron + '<span>' + subDone + ' / ' + subs.length + ' 子任务</span>' +
              '</button>' +
              '<div class="progress"><i style="width:' + Math.round((subDone / subs.length) * 100) + '%"></i></div>' +
              (expanded ? '<div class="sub-list">' + subs.map(function (s) {
                return '<button class="sub-row" data-act="todo-sub" data-id="' + t.id + '" data-sub="' + s.id + '">' +
                  '<span class="sub-check' + (s.done ? " on" : "") + '">' + (s.done ? ICON.check : "") + '</span>' +
                  '<span class="sub-text' + (s.done ? " done" : "") + '">' + esc(s.text) + '</span>' +
                '</button>';
              }).join("") + '</div>' : "") +
            '</div>' : "") +
        '</div>' +

        '<div class="todo-side">' +
          '<button class="icon-btn" data-act="todo-edit" data-id="' + t.id + '" title="编辑" aria-label="编辑">' + ICON.edit + '</button>' +
          '<button class="icon-btn" data-act="todo-archive" data-id="' + t.id + '" title="' + (t.archived ? "移出归档" : "归档") + '" aria-label="' + (t.archived ? "移出归档" : "归档") + '">' +
            (t.archived ? ICON.restore : ICON.archive) + '</button>' +
          '<button class="icon-btn danger" data-act="todo-del" data-id="' + t.id + '" title="删除" aria-label="删除">' + ICON.trash + '</button>' +
        '</div>' +
      '</article>';
    }).join("") + '</div>';

    viewRoot.innerHTML = html;
  }

  function openTodoEditor(id) {
    var todo = id ? findItem("todos", id) : null;
    if (id && !todo) return;

    var draft = (todo && todo.subtasks ? todo.subtasks : []).map(function (s) {
      return { id: s.id || uid("s"), text: s.text || "", done: !!s.done };
    });
    if (!draft.length) draft.push({ id: uid("s"), text: "", done: false });

    formModal({
      kicker: "待办 / TASK",
      title: todo ? "编辑待办" : "新建待办",
      saveLabel: todo ? "保存修改" : "保存待办",
      body:
        '<div class="field"><label>要做的事</label><input name="title" value="' + esc(todo ? todo.title : "") + '" placeholder="例如：交下周的设计稿" maxlength="160" required></div>' +
        '<div class="field-row">' +
          '<div class="field"><label>优先级</label><select name="priority">' +
            '<option value="high"' + (todo && todo.priority === "high" ? " selected" : "") + '>高</option>' +
            '<option value="mid"' + (!todo || todo.priority === "mid" ? " selected" : "") + '>中</option>' +
            '<option value="low"' + (todo && todo.priority === "low" ? " selected" : "") + '>低</option>' +
          '</select></div>' +
          '<div class="field"><label>截止时间</label><input name="due" type="date" value="' + esc(todo ? (todo.due || "") : "") + '"></div>' +
        '</div>' +
        '<div class="field"><label>备注</label><input name="note" value="' + esc(todo ? (todo.note || "") : "") + '" placeholder="可留空" maxlength="200"></div>' +
        '<div class="field"><label>子任务</label><div class="sub-editor" id="subEditor"></div>' +
          '<button type="button" class="add-sub" id="addSub">' + ICON.plus + ' 添加子任务</button></div>' +
        '<p class="form-error" data-error></p>',
      onOpen: function (form) {
        var box = $("#subEditor", form);
        function paint() {
          box.innerHTML = draft.map(function (s, i) {
            return '<div class="sub-edit-row" data-index="' + i + '">' +
              '<label class="mini-check"><input type="checkbox"' + (s.done ? " checked" : "") + ' data-role="done"><span></span></label>' +
              '<input type="text" data-role="text" value="' + esc(s.text) + '" placeholder="一小步" maxlength="120">' +
              '<button type="button" class="sub-del" data-index="' + i + '" aria-label="删除子任务">' + ICON.close + '</button>' +
            '</div>';
          }).join("");
        }
        function sync() {
          $$(".sub-edit-row", box).forEach(function (row, i) {
            var item = draft[i];
            if (!item) return;
            var input = row.querySelector('[data-role="text"]');
            var cb = row.querySelector('[data-role="done"]');
            item.text = input.value;
            item.done = cb.checked;
          });
        }
        paint();
        $("#addSub", form).addEventListener("click", function () {
          sync();
          draft.push({ id: uid("s"), text: "", done: false });
          paint();
          var inputs = $$('[data-role="text"]', box);
          if (inputs.length) inputs[inputs.length - 1].focus();
        });
        box.addEventListener("click", function (ev) {
          var del = ev.target.closest(".sub-del");
          if (!del) return;
          sync();
          draft.splice(Number(del.getAttribute("data-index")), 1);
          if (!draft.length) draft.push({ id: uid("s"), text: "", done: false });
          paint();
        });
        form.__syncSubs = function () {
          sync();
          return draft.filter(function (s) { return s.text.trim(); }).map(function (s) {
            return { id: s.id, text: s.text.trim(), done: !!s.done };
          });
        };
      },
      onSubmit: function (form) {
        var fd = new FormData(form);
        var title = String(fd.get("title") || "").trim();
        if (!title) { setError(form, "请填写要做的事"); return; }
        var subs = form.__syncSubs ? form.__syncSubs() : [];
        var data = {
          title: title,
          priority: String(fd.get("priority") || "mid"),
          due: String(fd.get("due") || ""),
          note: String(fd.get("note") || "").trim(),
          subtasks: subs
        };
        var list = WStore.list("todos");
        if (todo) {
          Object.assign(todo, data);
          todo.updatedAt = Date.now();
        } else {
          list.unshift(Object.assign({
            id: uid("t"), done: false, archived: false,
            createdAt: Date.now(), updatedAt: Date.now()
          }, data));
        }
        WStore.saveList("todos", list);
        closeModal();
        refresh();
        toast(todo ? "已保存修改" : "已添加待办");
      }
    });
  }

  /* ---------------- 倒数日 ---------------- */
  var DAY_COLORS = {
    mint: { name: "薄荷", hex: "#93c9b7" },
    warm: { name: "暖棕", hex: "#c69a6d" },
    rose: { name: "玫瑰", hex: "#d98b8b" },
    sky: { name: "雾蓝", hex: "#8aa8c9" }
  };

  function renderDays() {
    var all = WStore.list("days");
    var q = (state.search.days || "").trim().toLowerCase();
    var f = state.dayFilter;

    var counts = {
      all: all.length,
      future: all.filter(function (d) { return dayDiff(d.date) >= 0; }).length,
      past: all.filter(function (d) { return dayDiff(d.date) < 0; }).length
    };

    var list = all.filter(function (d) {
      if (f === "future") return dayDiff(d.date) >= 0;
      if (f === "past") return dayDiff(d.date) < 0;
      return true;
    }).filter(function (d) {
      return !q || d.title.toLowerCase().indexOf(q) > -1;
    }).sort(function (a, b) {
      if (!!b.pinned !== !!a.pinned) return b.pinned ? 1 : -1;
      var da = dayDiff(a.date);
      var db = dayDiff(b.date);
      var ra = da >= 0 ? da : 100000 + Math.abs(da);
      var rb = db >= 0 ? db : 100000 + Math.abs(db);
      return ra - rb;
    });

    var chips = [
      ["all", "全部", counts.all],
      ["future", "未来", counts.future],
      ["past", "过去", counts.past]
    ].map(function (x) {
      return '<button class="chip' + (f === x[0] ? " on" : "") + '" data-act="day-filter" data-filter="' + x[0] + '">' +
        x[1] + '<em>' + x[2] + '</em></button>';
    }).join("");

    var html = '<div class="filter-row">' + chips + '</div>';

    if (!list.length) {
      html += emptyBlock(ICON.day, q ? "没有匹配的日子" : "还没有记下日子",
        q ? "换个关键词，或切到「全部」。" : "生日、纪念日、旅行、倒计时，都可以放在这里。",
        q ? "" : "记下第一个日子", "day-new");
      viewRoot.innerHTML = html;
      return;
    }

    html += '<div class="day-grid">' + list.map(function (d) {
      var diff = dayDiff(d.date);
      var color = DAY_COLORS[d.color] ? d.color : "mint";
      var label = diff > 0 ? "还有" : diff < 0 ? "已过去" : "就是今天";
      var big = diff === 0
        ? '<b class="day-big is-today">今天</b>'
        : '<b class="day-big">' + Math.abs(diff) + '<span>天</span></b>';

      return '<article class="day-card color-' + color + (diff < 0 ? " is-past" : "") + '">' +
        '<div class="day-top">' +
          '<span class="day-label">' + (d.pinned ? "置顶 · " : "") + esc(label) + '</span>' +
          '<button class="pin-btn' + (d.pinned ? " on" : "") + '" data-act="day-pin" data-id="' + d.id + '" aria-label="' + (d.pinned ? "取消置顶" : "置顶") + '">' + ICON.pin + '</button>' +
        '</div>' +
        big +
        '<h3>' + esc(d.title) + '</h3>' +
        '<div class="day-meta"><span>' + esc(d.date) + '</span><span>' + weekday(d.date) + '</span>' +
          '<span class="color-tag" style="--c:' + DAY_COLORS[color].hex + '">' + DAY_COLORS[color].name + '</span></div>' +
        '<div class="day-actions">' +
          '<button class="mini-link" data-act="day-edit" data-id="' + d.id + '">' + ICON.edit + '编辑</button>' +
          '<button class="mini-link danger" data-act="day-del" data-id="' + d.id + '">' + ICON.trash + '删除</button>' +
        '</div>' +
      '</article>';
    }).join("") + '</div>';

    viewRoot.innerHTML = html;
  }

  function openDayEditor(id) {
    var day = id ? findItem("days", id) : null;
    if (id && !day) return;

    formModal({
      kicker: "倒数日 / DAY",
      title: day ? "编辑日子" : "记一个日子",
      saveLabel: day ? "保存修改" : "保存日子",
      body:
        '<div class="field"><label>名称</label><input name="title" value="' + esc(day ? day.title : "") + '" placeholder="例如：春节回家、毕业纪念" maxlength="80" required></div>' +
        '<div class="field"><label>日期</label><input name="date" type="date" value="' + esc(day ? day.date : "") + '" required></div>' +
        '<div class="field"><label>颜色标签</label><div class="color-row">' +
          Object.keys(DAY_COLORS).map(function (k) {
            return '<label class="color-dot" style="--c:' + DAY_COLORS[k].hex + '">' +
              '<input type="radio" name="color" value="' + k + '"' + ((day ? day.color : "mint") === k ? " checked" : "") + '>' +
              '<span></span><em>' + DAY_COLORS[k].name + '</em></label>';
          }).join("") +
        '</div></div>' +
        '<div class="field"><label class="switch"><input type="checkbox" name="pinned"' + (day && day.pinned ? " checked" : "") + '><span class="switch-track"><i></i></span><span class="switch-label">置顶这个日子</span></label></div>' +
        '<p class="form-error" data-error></p>',
      onSubmit: function (form) {
        var fd = new FormData(form);
        var title = String(fd.get("title") || "").trim();
        var date = String(fd.get("date") || "");
        if (!title) { setError(form, "请填写名称"); return; }
        if (!date) { setError(form, "请选择日期"); return; }
        var data = {
          title: title, date: date,
          color: String(fd.get("color") || "mint"),
          pinned: !!form.querySelector('[name="pinned"]').checked
        };
        var list = WStore.list("days");
        if (day) {
          Object.assign(day, data);
          day.updatedAt = Date.now();
        } else {
          list.unshift(Object.assign({ id: uid("d"), createdAt: Date.now(), updatedAt: Date.now() }, data));
        }
        WStore.saveList("days", list);
        closeModal();
        refresh();
        toast(day ? "已保存修改" : "已记下这个日子");
      }
    });
  }

  /* ---------------- 文件库 ---------------- */
  function fileKind(type, name) {
    var ext = (name || "").split(".").pop().toLowerCase();
    if ((type || "").indexOf("image/") === 0) return "image";
    if (type === "application/pdf" || ext === "pdf") return "pdf";
    if ((type || "").indexOf("video/") === 0) return "video";
    if ((type || "").indexOf("audio/") === 0) return "audio";
    if (/^(txt|md|markdown|json|csv|log|html|css|js|xml|yml|yaml)$/.test(ext)) return "text";
    return "file";
  }

  function kindIcon(kind) {
    if (kind === "image") return ICON.image;
    if (kind === "pdf") return ICON.pdf;
    if (kind === "video") return ICON.video;
    if (kind === "audio") return ICON.audio;
    return ICON.file;
  }

  function renderFiles() {
    var token = ++state.fileToken;
    var cached = state.files;

    if (state.filesLoaded && cached.length) {
      paintFiles(cached, state.fileFallback);
    } else {
      viewRoot.innerHTML = '<div class="empty"><div class="empty-icon">' + ICON.file + '</div><h3>正在读取文件…</h3><p>从浏览器本地存储中读取。</p></div>';
    }

    WStore.files.all().then(function (res) {
      if (token !== state.fileToken || state.view !== "files") return;
      state.files = res.records;
      state.fileFallback = res.fallback;
      state.filesLoaded = true;
      paintFiles(res.records, res.fallback);
      updateCounts();
    }).catch(function () {
      if (token !== state.fileToken) return;
      paintFiles([], true);
    });
  }

  function paintFiles(records, fallback) {
    var q = (state.search.files || "").trim().toLowerCase();
    var list = records.filter(function (f) {
      return !q || f.name.toLowerCase().indexOf(q) > -1;
    });
    var totalSize = records.reduce(function (n, f) { return n + (f.size || 0); }, 0);

    var html = '<div class="view-bar">' +
      '<span class="bar-note"><i class="dot"></i>' + records.length + ' 个文件 · ' + fmtSize(totalSize) +
        ' · ' + (fallback ? "本地存储（回退）" : "IndexedDB") + '</span>' +
      '<button class="btn-ghost sm" data-act="file-import">' + ICON.plus + '<span>导入文件</span></button>' +
    '</div>';

    var isFile = location.protocol === "file:";
    if (fallback && isFile) {
      html += '<div class="banner">当前以 file:// 直接打开，浏览器限制了文件库，已回退到本地存储（单个文件 ≤ 3 MB）。改用本地服务器（http://）打开可启用 IndexedDB，容量更大。</div>';
    } else if (fallback) {
      html += '<div class="banner">当前浏览器不支持 IndexedDB，文件已回退到本地存储；容量有限，单个文件不超过 3 MB。</div>';
    } else if (isFile) {
      html += '<div class="banner">正在以 file:// 直接打开。导入的文件只在本机读取、不会上传；若导入或预览异常，请改用本地服务器（http://）打开。</div>';
    }

    if (!list.length) {
      html += emptyBlock(ICON.file, q ? "没有匹配的文件" : "文件库还是空的",
        q ? "试试别的文件名。" : "照片、PDF、音频、文本都可以从本地导入，不会上传。",
        q ? "" : "从本地导入", "file-import");
      viewRoot.innerHTML = html;
      return;
    }

    html += '<div class="file-grid">' + list.map(function (f) {
      var kind = fileKind(f.type, f.name);
      return '<article class="file-card" data-act="file-preview" data-id="' + f.id + '">' +
        '<div class="file-icon kind-' + kind + '">' + kindIcon(kind) + '</div>' +
        '<div class="file-info"><b title="' + esc(f.name) + '">' + esc(f.name) + '</b>' +
          '<span>' + fmtSize(f.size) + ' · ' + fmtDate(f.createdAt) + '</span></div>' +
        '<div class="file-actions">' +
          '<button class="icon-btn" data-act="file-rename" data-id="' + f.id + '" title="重命名" aria-label="重命名">' + ICON.edit + '</button>' +
          '<button class="icon-btn danger" data-act="file-del" data-id="' + f.id + '" title="删除" aria-label="删除">' + ICON.trash + '</button>' +
        '</div>' +
      '</article>';
    }).join("") + '</div>';

    viewRoot.innerHTML = html;
  }

  async function handleImport(files) {
    if (!files || !files.length) return;
    toast("正在导入 " + files.length + " 个文件…");
    var ok = 0;
    var firstErr = "";
    for (var i = 0; i < files.length; i++) {
      try {
        await WStore.files.add(files[i], files[i].name);
        ok++;
      } catch (e) {
        if (!firstErr) firstErr = e.message || "导入失败";
      }
    }
    fileInput.value = "";
    toast(firstErr || ("已导入 " + ok + " 个文件"));
    state.filesLoaded = false;
    renderFiles();
  }

  function previewFile(rec) {
    var url = WStore.files.url(rec);
    var kind = fileKind(rec.type, rec.name);
    var body = "";
    var download = '<a class="mini-link" href="' + url + '" download="' + esc(rec.name) + '">' + ICON.download + '下载到本地</a>';

    if (kind === "image") {
      body = '<div class="preview-media"><img src="' + url + '" alt="' + esc(rec.name) + '"></div>';
    } else if (kind === "pdf") {
      body = '<iframe class="preview-frame" src="' + url + '" title="' + esc(rec.name) + '"></iframe>';
    } else if (kind === "video") {
      body = '<video class="preview-media" src="' + url + '" controls preload="metadata"></video>';
    } else if (kind === "audio") {
      body = '<audio class="preview-audio" src="' + url + '" controls></audio>';
    } else if (kind === "text") {
      body = '<pre class="file-text" data-text-slot>正在读取…</pre>';
    } else {
      body = '<div class="preview-unknown"><div class="file-icon kind-file">' + ICON.file + '</div>' +
        '<p>这个格式无法在站内预览，可以下载后用本机应用打开。</p></div>';
    }

    if (!rec.dataUrl && rec.blob) state.previewUrl = url;

    openRawModal("文件库 / PREVIEW", rec.name, body +
      '<div class="preview-meta"><span>' + esc(rec.type || "未知类型") + '</span><span>' + fmtSize(rec.size) + '</span><span>' + fmtDate(rec.createdAt) + '</span>' +
      download + '</div>', true);

    if (kind === "text") {
      fetch(url).then(function (r) { return r.text(); }).then(function (text) {
        var slot = $("[data-text-slot]", modalRoot);
        if (slot) slot.textContent = text;
      }).catch(function () {
        var slot = $("[data-text-slot]", modalRoot);
        if (slot) slot.textContent = "读取失败。";
      });
    }
  }

  function renameFileDialog(rec) {
    formModal({
      kicker: "文件库 / RENAME",
      title: "重命名文件",
      saveLabel: "保存名称",
      body:
        '<div class="field"><label>文件名</label><input name="name" value="' + esc(rec.name) + '" maxlength="160" required></div>' +
        '<p class="form-error" data-error></p>',
      onSubmit: async function (form) {
        var name = String(new FormData(form).get("name") || "").trim();
        if (!name) { setError(form, "请填写文件名"); return; }
        await WStore.files.rename(rec.id, name);
        closeModal();
        state.filesLoaded = false;
        renderFiles();
        toast("已重命名");
      }
    });
  }

  /* ---------------- 设置 ---------------- */
  function renderSettings() {
    var s = WStore.getSettings();
    var counts = {
      vault: WStore.list("vault").length,
      memos: WStore.list("memos").length,
      todos: WStore.list("todos").length,
      days: WStore.list("days").length,
      files: state.files.length
    };

    var themes = THEMES.map(function (t) {
      return '<button class="theme-card' + (s.theme === t.id ? " on" : "") + '" data-act="set-theme" data-value="' + t.id + '">' +
        '<span class="theme-swatch">' + t.swatch.map(function (c) {
          return '<i style="background:' + c + '"></i>';
        }).join("") + '</span>' +
        '<b>' + t.name + '</b><small>' + t.desc + '</small>' +
      '</button>';
    }).join("");

    var sizes = SIZES.map(function (x) {
      return '<button class="seg-btn' + (s.size === x.id ? " on" : "") + '" data-act="set-size" data-value="' + x.id + '">' + x.name + '</button>';
    }).join("");

    viewRoot.innerHTML =
      '<div class="settings-view">' +
        '<section class="set-block">' +
          '<div class="set-head"><p class="mono">APPEARANCE</p><h2>主题</h2><p>三套配色，随光线切换。</p></div>' +
          '<div class="theme-grid">' + themes + '</div>' +
        '</section>' +

        '<section class="set-block">' +
          '<div class="set-head"><p class="mono">TYPE</p><h2>字号</h2><p>只影响本子的正文与列表，不改结构。</p></div>' +
          '<div class="size-row"><div class="seg">' + sizes + '</div>' +
            '<p class="type-preview">字大一点，读起来松一点。<span class="mono">WUKU · LOCAL</span></p>' +
          '</div>' +
        '</section>' +

        '<section class="set-block">' +
          '<div class="set-head"><p class="mono">DATA</p><h2>本地数据</h2><p>全部保存在当前浏览器，不上传。</p></div>' +
          '<ul class="data-list">' +
            '<li><span>密码本</span><b>' + counts.vault + ' 条</b></li>' +
            '<li><span>备忘录</span><b>' + counts.memos + ' 条</b></li>' +
            '<li><span>待办</span><b>' + counts.todos + ' 条</b></li>' +
            '<li><span>倒数日</span><b>' + counts.days + ' 个</b></li>' +
            '<li><span>文件库</span><b>' + counts.files + ' 个</b></li>' +
            '<li><span>存储位置</span><b>浏览器本地</b></li>' +
          '</ul>' +
          '<p class="set-note">清除浏览器站点数据会一并清空这些内容；换设备或换浏览器不会自动同步。</p>' +
        '</section>' +
      '</div>';
  }

  function changeSetting(patch) {
    var s = WStore.getSettings();
    if (patch.theme) s.theme = patch.theme;
    if (patch.size) s.size = patch.size;
    WStore.saveSettings(s);
    applyTheme(s.theme, s.size);
    renderSettings();
    toast("设置已保存");
  }

  /* ---------------- 弹窗 ---------------- */
  function openModal(html, wide) {
    modalRoot.innerHTML = '<div class="modal-backdrop"><div class="modal' + (wide ? " modal-wide" : "") + '">' + html + '</div></div>';
    modalRoot.classList.add("open");
    modalRoot.setAttribute("aria-hidden", "false");
    document.body.classList.add("modal-open");
    var focusable = $(".modal-body input, .modal-body textarea, .modal-body select", modalRoot) ||
      $(".modal-body button, .modal-close", modalRoot);
    if (focusable) setTimeout(function () { focusable.focus(); }, 60);
  }

  function openRawModal(kicker, title, body, wide) {
    openModal(
      '<div class="modal-head"><div><p class="mono">' + esc(kicker) + '</p><h2>' + esc(title) + '</h2></div>' +
        '<button class="modal-close" data-close aria-label="关闭">' + ICON.close + '</button></div>' +
      '<div class="modal-body">' + body + '</div>',
      wide
    );
  }

  function formModal(opts) {
    openModal(
      '<div class="modal-head"><div><p class="mono">' + esc(opts.kicker) + '</p><h2>' + esc(opts.title) + '</h2></div>' +
        '<button class="modal-close" data-close aria-label="关闭">' + ICON.close + '</button></div>' +
      '<form class="modal-form" id="modalForm" novalidate>' +
        '<div class="modal-body">' + opts.body + '</div>' +
        '<div class="modal-foot">' +
          '<button type="button" class="btn-ghost" data-close>取消</button>' +
          '<button type="submit" class="act-primary">' + esc(opts.saveLabel || "保存") + '</button>' +
        '</div>' +
      '</form>',
      opts.wide
    );

    var form = $("#modalForm", modalRoot);
    if (opts.onOpen) opts.onOpen(form);
    form.addEventListener("submit", async function (ev) {
      ev.preventDefault();
      if (form.dataset.busy) return;
      form.dataset.busy = "1";
      try {
        await opts.onSubmit(form);
      } catch (e) {
        setError(form, e.message || "保存失败");
      } finally {
        delete form.dataset.busy;
      }
    });
  }

  function setError(form, msg) {
    var box = $("[data-error]", form);
    if (box) {
      box.textContent = msg;
      box.classList.add("show");
    } else {
      toast(msg);
    }
  }

  function confirmModal(title, message, okLabel, onOk, danger) {
    openModal(
      '<div class="modal-head"><div><p class="mono">CONFIRM</p><h2>' + esc(title) + '</h2></div>' +
        '<button class="modal-close" data-close aria-label="关闭">' + ICON.close + '</button></div>' +
      '<div class="modal-body"><p class="confirm-text">' + esc(message) + '</p></div>' +
      '<div class="modal-foot"><button class="btn-ghost" data-close>取消</button>' +
        '<button class="act-primary' + (danger ? " danger" : "") + '" id="confirmOk">' + esc(okLabel) + '</button></div>'
    );
    $("#confirmOk", modalRoot).addEventListener("click", async function () {
      try {
        await onOk();
        closeModal();
      } catch (e) {
        toast(e.message || "操作失败");
      }
    });
  }

  function closeModal() {
    modalRoot.classList.remove("open");
    modalRoot.setAttribute("aria-hidden", "true");
    modalRoot.innerHTML = "";
    document.body.classList.remove("modal-open");
    if (state.previewUrl) {
      try { URL.revokeObjectURL(state.previewUrl); } catch (e) {}
      state.previewUrl = null;
    }
  }

  modalRoot.addEventListener("click", function (ev) {
    if (ev.target.classList.contains("modal-backdrop") || ev.target.closest("[data-close]")) {
      closeModal();
    }
  });

  document.addEventListener("keydown", function (ev) {
    if (ev.key === "Escape" && modalRoot.classList.contains("open")) closeModal();
  });

  /* ---------------- 事件 ---------------- */
  document.addEventListener("click", function (ev) {
    var nav = ev.target.closest("[data-view]");
    if (nav) {
      navigate(nav.getAttribute("data-view"));
    }
  });

  newBtn.addEventListener("click", function () {
    if (state.view === "files") {
      fileInput.click();
    } else if (state.view === "vault") {
      openVaultEditor();
    } else if (state.view === "memos") {
      openMemoEditor();
    } else if (state.view === "todos") {
      openTodoEditor();
    } else if (state.view === "days") {
      openDayEditor();
    }
  });

  searchInput.addEventListener("input", function () {
    state.search[state.view] = this.value;
    if (state.view === "files") renderFiles();
    else render();
  });

  fileInput.addEventListener("change", function () {
    handleImport(Array.from(this.files || []));
  });

  /* 视图内点击 */
  viewRoot.addEventListener("click", function (ev) {
    var el = ev.target.closest("[data-act]");
    if (!el) return;
    var act = el.getAttribute("data-act");
    var id = el.getAttribute("data-id");
    var filter = el.getAttribute("data-filter");

    if (act === "vault-eye") {
      state.revealed[id] = !state.revealed[id];
      renderVault();
      return;
    }

    if (act === "vault-copy") {
      var entry = findItem("vault", id);
      if (entry) copyText(entry.password || "");
      return;
    }

    if (act === "vault-edit") { openVaultEditor(id); return; }

    if (act === "vault-del") {
      var e2 = findItem("vault", id);
      if (!e2) return;
      confirmModal("删除这条密码？", "「" + e2.name + "」将从密码本中移除，无法恢复。", "删除", function () {
        WStore.saveList("vault", WStore.list("vault").filter(function (x) { return x.id !== id; }));
        refresh();
        toast("已删除");
      }, true);
      return;
    }

    if (act === "vault-lock") {
      state.vaultUnlocked = false;
      state.revealed = {};
      updateChrome();
      renderVault();
      toast("密码本已重新上锁");
      return;
    }

    if (act === "vault-forgot") {
      confirmModal("忘记密码了？", "只能清空密码本里的全部条目与这把锁，重新设置。其他抽屉不受影响。", "清空密码本", function () {
        WStore.vault.clear();
        state.vaultUnlocked = false;
        state.revealed = {};
        refresh();
        toast("密码本已清空，可以重新设置");
      }, true);
      return;
    }

    if (act === "vault-new") { openVaultEditor(); return; }

    /* 备忘 */
    if (act === "memo-new") { openMemoEditor(); return; }
    if (act === "memo-edit") { openMemoEditor(id); return; }
    if (act === "memo-pin") {
      var memo = findItem("memos", id);
      if (!memo) return;
      memo.pinned = !memo.pinned;
      memo.updatedAt = Date.now();
      WStore.saveList("memos", WStore.list("memos"));
      renderMemos();
      toast(memo.pinned ? "已置顶" : "已取消置顶");
      return;
    }

    /* 待办 */
    if (act === "todo-new") { openTodoEditor(); return; }
    if (act === "todo-edit") { openTodoEditor(id); return; }
    if (act === "todo-toggle") {
      var todo = findItem("todos", id);
      if (!todo) return;
      todo.done = !todo.done;
      todo.updatedAt = Date.now();
      WStore.saveList("todos", WStore.list("todos"));
      renderTodos();
      toast(todo.done ? "已完成" : "已取消完成");
      return;
    }
    if (act === "todo-expand") {
      state.expanded[id] = !state.expanded[id];
      renderTodos();
      return;
    }
    if (act === "todo-sub") {
      var t2 = findItem("todos", id);
      if (!t2) return;
      var subId = el.getAttribute("data-sub");
      (t2.subtasks || []).forEach(function (s) { if (s.id === subId) s.done = !s.done; });
      t2.updatedAt = Date.now();
      WStore.saveList("todos", WStore.list("todos"));
      renderTodos();
      return;
    }
    if (act === "todo-archive") {
      var t3 = findItem("todos", id);
      if (!t3) return;
      t3.archived = !t3.archived;
      t3.updatedAt = Date.now();
      WStore.saveList("todos", WStore.list("todos"));
      renderTodos();
      toast(t3.archived ? "已归档" : "已移出归档");
      return;
    }
    if (act === "todo-del") {
      var t4 = findItem("todos", id);
      if (!t4) return;
      confirmModal("删除这件待办？", "「" + t4.title + "」及其子任务会被移除，无法恢复。", "删除", function () {
        WStore.saveList("todos", WStore.list("todos").filter(function (x) { return x.id !== id; }));
        renderTodos();
        toast("已删除");
      }, true);
      return;
    }
    if (act === "todo-filter") {
      state.todoFilter = filter;
      renderTodos();
      return;
    }

    /* 倒数日 */
    if (act === "day-new") { openDayEditor(); return; }
    if (act === "day-edit") { openDayEditor(id); return; }
    if (act === "day-pin") {
      var d = findItem("days", id);
      if (!d) return;
      d.pinned = !d.pinned;
      d.updatedAt = Date.now();
      WStore.saveList("days", WStore.list("days"));
      renderDays();
      toast(d.pinned ? "已置顶" : "已取消置顶");
      return;
    }
    if (act === "day-del") {
      var d2 = findItem("days", id);
      if (!d2) return;
      confirmModal("删除这个日子？", "「" + d2.title + "」会从倒数日里移除。", "删除", function () {
        WStore.saveList("days", WStore.list("days").filter(function (x) { return x.id !== id; }));
        renderDays();
        toast("已删除");
      }, true);
      return;
    }
    if (act === "day-filter") {
      state.dayFilter = filter;
      renderDays();
      return;
    }

    /* 文件 */
    if (act === "file-import") { fileInput.click(); return; }
    if (act === "file-preview") {
      var rec = state.files.filter(function (f) { return f.id === id; })[0];
      if (rec) previewFile(rec);
      return;
    }
    if (act === "file-rename") {
      var rec2 = state.files.filter(function (f) { return f.id === id; })[0];
      if (rec2) renameFileDialog(rec2);
      return;
    }
    if (act === "file-del") {
      var rec3 = state.files.filter(function (f) { return f.id === id; })[0];
      if (!rec3) return;
      confirmModal("删除这个文件？", "「" + rec3.name + "」会从本地文件库中移除。", "删除", async function () {
        await WStore.files.remove(id);
        state.files = state.files.filter(function (f) { return f.id !== id; });
        state.filesLoaded = false;
        renderFiles();
        toast("已删除文件");
      }, true);
      return;
    }

    /* 设置 */
    if (act === "set-theme") {
      changeSetting({ theme: el.getAttribute("data-value") });
      return;
    }
    if (act === "set-size") {
      changeSetting({ size: el.getAttribute("data-value") });
      return;
    }
  });

  /* 密码本表单 */
  viewRoot.addEventListener("submit", async function (ev) {
    var form = ev.target;
    if (form.id === "vault-setup") {
      ev.preventDefault();
      var pw = form.querySelector('[name="password"]').value;
      var cf = form.querySelector('[name="confirm"]').value;
      if (pw.length < 4) { setError(form, "密码至少 4 个字符"); return; }
      if (pw !== cf) { setError(form, "两次输入的密码不一致"); return; }
      var btn = form.querySelector("button[type=submit]");
      btn.disabled = true;
      btn.textContent = "正在设置…";
      try {
        await WStore.vault.setup(pw);
        state.vaultUnlocked = true;
        refresh();
        toast("密码本已设好，只保存在本机");
      } catch (e) {
        setError(form, "设置失败，请重试");
        btn.disabled = false;
        btn.textContent = "设置并进入";
      }
      return;
    }

    if (form.id === "vault-unlock") {
      ev.preventDefault();
      var password = form.querySelector('[name="password"]').value;
      if (!password) { setError(form, "请输入密码"); return; }
      var okBtn = form.querySelector("button[type=submit]");
      okBtn.disabled = true;
      okBtn.textContent = "正在解锁…";
      try {
        var ok = await WStore.vault.verify(password);
        if (ok) {
          state.vaultUnlocked = true;
          refresh();
          toast("密码本已解锁");
        } else {
          setError(form, "密码不对，再试一次");
          form.classList.add("shake");
          setTimeout(function () { form.classList.remove("shake"); }, 420);
          okBtn.disabled = false;
          okBtn.textContent = "解锁";
        }
      } catch (e) {
        setError(form, "解锁失败，请重试");
        okBtn.disabled = false;
        okBtn.textContent = "解锁";
      }
    }
  });

  /* ---------------- 启动 ---------------- */
  var initial = location.hash.slice(1);
  if (!VIEW_META[initial]) initial = "vault";
  var s = WStore.getSettings();
  applyTheme(s.theme, s.size);

  // 预热文件计数
  WStore.files.all().then(function (res) {
    state.files = res.records;
    state.fileFallback = res.fallback;
    state.filesLoaded = true;
    updateCounts();
  }).catch(function () {});

  applyView(initial);
})();
