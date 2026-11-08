/* WU本子 · 本地数据层
   localStorage：密码本、备忘、待办、倒数日、设置
   IndexedDB：文件库（不支持时回退 localStorage / dataURL）
   所有数据只留在当前浏览器。 */
(function () {
  "use strict";

  var NS = "wuku.v1.";

  function read(key, fallback) {
    try {
      var raw = localStorage.getItem(NS + key);
      return raw ? JSON.parse(raw) : fallback;
    } catch (e) {
      return fallback;
    }
  }

  function write(key, value) {
    localStorage.setItem(NS + key, JSON.stringify(value));
  }

  function removeKey(key) {
    localStorage.removeItem(NS + key);
  }

  function list(name) {
    var v = read(name, []);
    return Array.isArray(v) ? v : [];
  }

  function saveList(name, items) {
    write(name, items);
    return items;
  }

  /* ---------------- 设置 ---------------- */
  var DEFAULT_SETTINGS = { theme: "ink", size: "md" };

  function getSettings() {
    var s = read("settings", {});
    return {
      theme: (s && s.theme) || DEFAULT_SETTINGS.theme,
      size: (s && s.size) || DEFAULT_SETTINGS.size
    };
  }

  function saveSettings(s) {
    write("settings", s);
  }

  /* ---------------- 密码本锁 ---------------- */
  function randomSalt() {
    var bytes = new Uint8Array(8);
    if (window.crypto && crypto.getRandomValues) {
      crypto.getRandomValues(bytes);
    } else {
      for (var i = 0; i < bytes.length; i++) bytes[i] = Math.floor(Math.random() * 256);
    }
    return Array.from(bytes).map(function (b) { return b.toString(16).padStart(2, "0"); }).join("");
  }

  function fallbackHash(input) {
    var h1 = 0x811c9dc5;
    var h2 = 0x1000193;
    for (var round = 0; round < 800; round++) {
      for (var i = 0; i < input.length; i++) {
        var c = input.charCodeAt(i) + round;
        h1 = (h1 ^ c) >>> 0;
        h1 = (h1 * 0x01000193) >>> 0;
        h2 = (h2 + c * (i + 1)) >>> 0;
        h2 = ((h2 << 5) | (h2 >>> 27)) >>> 0;
      }
    }
    return (h1.toString(16) + h2.toString(16)).padStart(16, "0");
  }

  async function hashPassword(password, salt) {
    var input = salt + "::" + password;
    if (window.crypto && crypto.subtle && window.TextEncoder) {
      try {
        var buf = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(input));
        return Array.from(new Uint8Array(buf)).map(function (b) {
          return b.toString(16).padStart(2, "0");
        }).join("");
      } catch (e) { /* file:// 或旧内核回退 */ }
    }
    return fallbackHash(input);
  }

  function getAuth() {
    var a = read("vault.auth", null);
    return (a && a.salt && a.hash) ? a : null;
  }

  async function setupVault(password) {
    var salt = randomSalt();
    var hash = await hashPassword(password, salt);
    var auth = { salt: salt, hash: hash, createdAt: Date.now() };
    write("vault.auth", auth);
    return auth;
  }

  async function verifyVault(password) {
    var auth = getAuth();
    if (!auth) return false;
    var hash = await hashPassword(password, auth.salt);
    return hash === auth.hash;
  }

  function clearVault() {
    removeKey("vault.auth");
    removeKey("vault");
  }

  /* ---------------- 文件库 ---------------- */
  var DB_NAME = "wuku-files";
  var DB_VERSION = 1;
  var STORE_NAME = "files";
  var dbPromise = null;
  var idbBroken = false;

  function openDB() {
    if (idbBroken) return Promise.reject(new Error("indexeddb-disabled"));
    if (dbPromise) return dbPromise;
    dbPromise = new Promise(function (resolve, reject) {
      if (!window.indexedDB) { reject(new Error("no-indexeddb")); return; }
      var req;
      try {
        req = indexedDB.open(DB_NAME, DB_VERSION);
      } catch (e) { reject(e); return; }
      req.onupgradeneeded = function () {
        var db = req.result;
        if (!db.objectStoreNames.contains(STORE_NAME)) {
          db.createObjectStore(STORE_NAME, { keyPath: "id" });
        }
      };
      req.onsuccess = function () { resolve(req.result); };
      req.onerror = function () { reject(req.error || new Error("idb-open-failed")); };
      req.onblocked = function () { reject(new Error("idb-blocked")); };
    });
    return dbPromise;
  }

  function reqP(req) {
    return new Promise(function (resolve, reject) {
      req.onsuccess = function () { resolve(req.result); };
      req.onerror = function () { reject(req.error); };
    });
  }

  function fileToDataURL(file) {
    return new Promise(function (resolve, reject) {
      var fr = new FileReader();
      fr.onload = function () { resolve(fr.result); };
      fr.onerror = function () { reject(fr.error); };
      fr.readAsDataURL(file);
    });
  }

  function fallbackFiles() {
    var arr = read("files", []);
    return Array.isArray(arr) ? arr : [];
  }

  function fallbackTotal(arr) {
    return arr.reduce(function (n, f) { return n + (f.size || 0); }, 0);
  }

  async function allFiles() {
    if (idbBroken) return { records: fallbackFiles(), fallback: true };
    try {
      var db = await openDB();
      var tx = db.transaction(STORE_NAME, "readonly");
      var store = tx.objectStore(STORE_NAME);
      var records = await reqP(store.getAll());
      records.sort(function (a, b) { return b.createdAt - a.createdAt; });
      return { records: records, fallback: false };
    } catch (e) {
      idbBroken = true;
      return { records: fallbackFiles(), fallback: true };
    }
  }

  async function addFile(file, name) {
    var record = {
      id: "f_" + Date.now().toString(36) + Math.random().toString(36).slice(2, 7),
      name: name || file.name || "未命名文件",
      type: file.type || "application/octet-stream",
      size: file.size || 0,
      createdAt: Date.now()
    };

    if (!idbBroken) {
      try {
        var db = await openDB();
        record.blob = file;
        var tx = db.transaction(STORE_NAME, "readwrite");
        await reqP(tx.objectStore(STORE_NAME).put(record));
        return record;
      } catch (e) {
        idbBroken = true;
      }
    }

    if (record.size > 3 * 1024 * 1024) {
      throw new Error("当前浏览器不支持 IndexedDB，本地存储回退模式下单个文件不能超过 3 MB");
    }
    var arr = fallbackFiles();
    if (fallbackTotal(arr) + record.size > 4 * 1024 * 1024) {
      throw new Error("本地存储空间不足（回退模式上限约 4 MB）");
    }
    record.dataUrl = await fileToDataURL(file);
    delete record.blob;
    arr.unshift(record);
    write("files", arr);
    return record;
  }

  async function renameFile(id, name) {
    if (!idbBroken) {
      try {
        var db = await openDB();
        var tx = db.transaction(STORE_NAME, "readwrite");
        var store = tx.objectStore(STORE_NAME);
        var rec = await reqP(store.get(id));
        if (!rec) throw new Error("file-not-found");
        rec.name = name;
        await reqP(store.put(rec));
        return rec;
      } catch (e) {
        if (!idbBroken) throw e;
      }
    }
    var arr = fallbackFiles();
    for (var i = 0; i < arr.length; i++) {
      if (arr[i].id === id) {
        arr[i].name = name;
        write("files", arr);
        return arr[i];
      }
    }
    throw new Error("file-not-found");
  }

  async function removeFile(id) {
    if (!idbBroken) {
      try {
        var db = await openDB();
        var tx = db.transaction(STORE_NAME, "readwrite");
        await reqP(tx.objectStore(STORE_NAME).delete(id));
        return true;
      } catch (e) {
        if (!idbBroken) throw e;
      }
    }
    var arr = fallbackFiles().filter(function (f) { return f.id !== id; });
    write("files", arr);
    return true;
  }

  function fileUrl(record) {
    if (record.dataUrl) return record.dataUrl;
    if (record.blob) return URL.createObjectURL(record.blob);
    return "";
  }

  window.WStore = {
    list: list,
    saveList: saveList,
    getSettings: getSettings,
    saveSettings: saveSettings,
    vault: {
      getAuth: getAuth,
      setup: setupVault,
      verify: verifyVault,
      clear: clearVault
    },
    files: {
      all: allFiles,
      add: addFile,
      rename: renameFile,
      remove: removeFile,
      url: fileUrl
    },
    clearAll: function () {
      ["vault", "vault.auth", "memos", "todos", "days", "files", "settings"].forEach(removeKey);
    }
  };
})();
