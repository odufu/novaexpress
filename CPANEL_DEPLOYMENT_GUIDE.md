# NovaXpress Website - cPanel Deployment Guide

This guide walks you through deploying the **NovaXpress Logistics** website onto any **cPanel** hosting platform (e.g. Namecheap, Hostinger, Bluehost, Whogohost, etc.).

---

## 📦 What Has Been Built

The ready-to-deploy zip archive is located in your project root:
- **File**: `novaxpress_website_cpanel.zip` (approx. 7.7 MB)
- **Built from**: `website/dist/`
- **Architecture**: React + Vite production build configured with client-side Supabase integration (no Node.js or Python backend server required on your hosting).

### Contents of the Package:
- `index.html` - Main application entry point with SEO & OpenGraph meta tags.
- `.htaccess` - Apache / LiteSpeed configuration with SPA rewriting, security headers, Gzip compression, and caching rules.
- `assets/` - Minified and hashed CSS and JavaScript bundles.
- `branding/` - High-resolution NovaXpress logos and dark mode variants.
- `images/` - Hero carousel photography and slide imagery.
- `favicon.svg` & `icons.svg` - Favicons and vector icons.
- `_redirects` - Fallback redirect rules for Netlify/Cloudflare if migrated later.

---

## 🚀 Step-by-Step Deployment to cPanel

### Step 1: Open cPanel File Manager
1. Log in to your **cPanel** dashboard.
2. In the **Files** section, click on **File Manager**.
3. In the top-right corner, click **Settings** (gear icon) and make sure **Show Hidden Files (dotfiles)** is checked, then click **Save**. *(This ensures you can see `.htaccess`)*.

---

### Step 2: Navigate to Your Web Root
- **For Primary Domain** (e.g. `novaxpress.ng`): Navigate into the `public_html` directory.
- **For Subdomain or Addon Domain** (e.g. `web.novaxpress.ng`): Navigate into the document root folder assigned to that domain (e.g., `public_html/web` or `novaxpress.ng`).

*(Tip: If there is an existing default `index.html` or default page from the host, delete or rename it).*

---

### Step 3: Upload the Zip Archive
1. Click the **Upload** button on the top toolbar of File Manager.
2. Drag and drop or select `novaxpress_website_cpanel.zip` from your computer:
   ```
   c:\PROJECT\NoveXPS\novaxpress_website_cpanel.zip
   ```
3. Wait until the upload progress reaches 100% (green bar).
4. Return to File Manager.

---

### Step 4: Extract the Zip Archive
1. In File Manager, right-click on `novaxpress_website_cpanel.zip`.
2. Select **Extract** (or click the *Extract* icon in the top toolbar).
3. Confirm the extraction path is your current directory (e.g. `/public_html`).
4. Click **Extract File(s)**.
5. All files will extract directly into `public_html` without creating unwanted nested folders.
6. *(Optional)*: Delete the `novaxpress_website_cpanel.zip` file to free up disk space.

---

### Step 5: Verify Your Live Website
Visit your domain in any browser:
- **Homepage**: `https://yourdomain.com`
- **Shipment Tracking**: `https://yourdomain.com/#tracking`
- **Services**: `https://yourdomain.com/#services`
- **Rate Estimator / Quote**: `https://yourdomain.com/#contact`
- **Admin CMS**: `https://yourdomain.com/#xpress-admin` (Passkey: `NovaAdmin2026!`)

---

## ⚙️ Configuration & Features Included

1. **SPA Routing**: The included `.htaccess` automatically routes any direct subpage URL (like `/services` or `/xpress-admin`) to `index.html` without showing Apache 404 errors.
2. **Direct Supabase Connectivity**:
   - The site communicates directly with the live Supabase project (`oygtaeriljuelhshfvkv.supabase.co`).
   - Quote requests submitted through the quote form are saved directly to `public.website_inquiries`.
   - The CMS admin panel allows updating services, case studies, company stats, and managing inquiries without needing to rebuild.
3. **High Performance**:
   - Static assets (`assets/*`) are served with 1-year cache headers.
   - `index.html` is configured with `no-cache` so users instantly receive future updates.
