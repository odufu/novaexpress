# NovaXpress Logistics Platform - Namecheap Stellar Hosting (WASM) Deployment Guide

This guide explains how to deploy the **NovaXpress Flutter WebAssembly (WASM)** application onto **Namecheap Stellar Hosting** (or any cPanel / Apache / LiteSpeed shared hosting).

---

## 📦 What Has Been Built

The ready-to-deploy zip archive is located in your project root:
- **Archive File:** `novaxpress_app_wasm_cpanel.zip` (approx. 56.4 MB)
- **Built From:** `build/web/`
- **Engine:** Flutter Web compiled to **WebAssembly (`main.dart.wasm`)** with an automatic JavaScript fallback (`main.dart.js`) for legacy browsers.
- **Server Configuration:** Embedded `.htaccess` with WebAssembly MIME types, Cross-Origin Isolation headers (`COOP`/`COEP`), SPA route rewriting (GoRouter), and Gzip/Deflate compression.

### Critical Included Files in the Archive:
| File / Directory | Purpose |
| :--- | :--- |
| `main.dart.wasm` | High-performance compiled WebAssembly binary (7.24 MB). |
| `main.dart.mjs` | WebAssembly JavaScript runtime glue. |
| `main.dart.js` | Full JavaScript fallback bundle for older/non-Wasm browsers. |
| `flutter_bootstrap.js` | Intelligent loader that detects browser Wasm GC support and streams the Wasm binary. |
| `.htaccess` | Apache configuration enabling `application/wasm` MIME type, COOP/COEP isolation, and SPA URL rewriting. |
| `canvaskit/` | Skia WebAssembly graphics rendering engine. |
| `assets/` | Brand assets, fonts, icons, audio, and state geo-data. |
| `index.html` | Application HTML shell with branded splash and Paystack integration. |

---

## 🚀 Step-by-Step Deployment to Namecheap Stellar (cPanel)

### Step 1: Log in to cPanel
1. Log in to your **Namecheap Dashboard**.
2. Go to **Hosting List** on the left menu.
3. Click the **Go to cPanel** button next to your Stellar Hosting subscription (or visit `https://yourdomain.com:2083`).

---

### Step 2: Open File Manager with Hidden Files Enabled
1. In cPanel, find the **Files** section and click **File Manager**.
2. In the top-right corner of File Manager, click **Settings** (gear icon).
3. Ensure the checkbox **Show Hidden Files (dotfiles)** is **CHECKED**, then click **Save**.  
   *(⚠️ Critical: This ensures the `.htaccess` configuration file is visible and active).*

---

### Step 3: Choose Your Web Root Directory
* **Deploying to Primary Domain** (e.g. `novaxpress.ng`):  
  Double-click into the `public_html` directory.
* **Deploying to a Subdomain / App Domain** (e.g. `app.novaxpress.ng` or `console.novaxpress.ng`):  
  Double-click into the folder designated for that subdomain (e.g., `public_html/app` or `app.novaxpress.ng`).

*(Tip: If there are existing placeholder files like default `index.html`, select and delete them).*

---

### Step 4: Upload `novaxpress_app_wasm_cpanel.zip`
1. Click the **Upload** button in the top toolbar of File Manager.
2. Select or drag-and-drop the file from your computer:
   ```
   C:\PROJECT\NoveXPS\novaxpress_app_wasm_cpanel.zip
   ```
3. Wait until the progress bar reaches **100% (Green)**.
4. Click **Go Back to /home/...** at the bottom of the upload page.

---

### Step 5: Extract the Archive
1. In File Manager, right-click on `novaxpress_app_wasm_cpanel.zip` and select **Extract**.
2. Confirm the extraction path (e.g., `/public_html` or `/public_html/app`) and click **Extract Files**.
3. Once extraction finishes, click **Close**.
4. **Clean up:** Right-click `novaxpress_app_wasm_cpanel.zip` and select **Delete** to free up disk space on your hosting plan.

---

### Step 6: Verify Key Files in File Manager
Ensure the following files are sitting directly in the root of your web directory:
- [x] `.htaccess`
- [x] `index.html`
- [x] `flutter_bootstrap.js`
- [x] `main.dart.wasm`
- [x] `main.dart.mjs`
- [x] `main.dart.js`
- [x] `assets/`
- [x] `canvaskit/`

---

## ⚡ How the Pre-Configured `.htaccess` Works on Namecheap

The included `.htaccess` solves the common pitfalls of hosting WebAssembly on shared cPanel hosting:

1. **MIME Type Fix:**  
   Apache will serve `.wasm` with `Content-Type: application/wasm`. Without this, Apache defaults to `application/octet-stream` which causes browsers to reject WebAssembly streaming.
2. **Cross-Origin Opener / Embedder Policy (COOP & COEP):**  
   Sets `Cross-Origin-Opener-Policy: same-origin` and `Cross-Origin-Embedder-Policy: credentialless`. This enables WebAssembly high-resolution timers and threading while still allowing third-party CDNs (Paystack, Google Fonts, Supabase).
3. **GoRouter SPA Deep-Linking:**  
   If an administrator accesses `https://yourdomain.com/admin` or a closer refreshes `https://yourdomain.com/closer`, Apache silently rewrites the request to `index.html` instead of throwing a 404 Not Found error.
4. **Zero-Cache for `index.html`:**  
   Ensures whenever you update the app, users immediately receive the new version without stale cache issues.

---

## 🧪 Testing Your Live WebAssembly Deployment
1. Open your browser and navigate to your domain (e.g. `https://yourdomain.com`).
2. Open **Chrome DevTools** (`F12`) -> **Network** tab.
3. Filter by **Wasm** or look for `main.dart.wasm`.
4. You should see `main.dart.wasm` loaded with `status 200` and `type: wasm`.
5. You can test deep-link routing by navigating directly to `/admin`, `/client`, or `/dc` and pressing browser refresh (`Ctrl + R`).

