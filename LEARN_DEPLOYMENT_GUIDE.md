# NovaXpress Academy (`learn.novaxpressng.com`) - Deployment & Operation Guide

This guide details the architecture, feature set, and step-by-step cPanel deployment for **NovaXpress Academy** (`learn.novaxpressng.com`)—the role-based e-learning and verifiable accreditation platform.

---

## 🎓 What Was Built

### 1. 7 Official Role-Based Certification Pathways
Every role on NovaXpress has a designated, progressive training curriculum leading to an accredited professional certification:

| Role Key | Operational Title | Official Certification | Badge Color | Focus Areas |
| :--- | :--- | :--- | :--- | :--- |
| `closer` | Telesales Representative | **Certified Sales Person** | Indigo `#4F46E5` | Address geo-normalization, landmark extraction, UPG upsell packages, call objection handling |
| `rider` | Fleet Delivery Courier | **Certified Mobile Operations** | Orange `#F37021` | Rider PDA app, OTP validation, doorstep signatures on glass, cash collection compliance |
| `dc_operations` | DC Dispatch Operations | **Certified Dispatch Operations** | Emerald `#059669` | Barcode intake, regional route clustering, rider run-sheets, damaged parcel triage |
| `dc_stock_admin` | DC Stock & Inventory Officer | **Certified Inventory Manager** | Sky Blue `#0284C7` | Warehouse SKU bin allocation, 2-way inter-DC stock handshakes, quarantine returns |
| `dc_finance_admin` | DC Finance Officer | **Certified Finance Operations** | Amber `#D97706` | Rider cash reconciliation, bank deposit vouchers, cash caps, remittance disputes |
| `accountant` | National General Accountant | **Certified Accountant** | Purple `#7C3AED` | National COD settlements, merchant payout batches, tariff deductions, bank audits |
| `dc_manager` | Grand DC Manager | **Certified Logistics Manager** | Navy `#1E3A8A` | Station SLA enforcement (95%+), vault balance audits, shift management |

---

### 2. Standard 6-Step Module Architecture
Each module in every certification track is structured consistently:
1. **Module Title & Duration** (e.g. *Lead Intake & Address Geo-Normalization • 14 mins*)
2. **Objectives & Competencies** (High-yield checkable learning goals)
3. **Module Video Player** (Streamable responsive player supporting YouTube, Vimeo, or direct MP4 screen recordings with speed controls)
4. **Interactive Transcript** (Searchable, readable transcription of the training recording)
5. **Key Summary & SOP Cheatsheet** (Step-by-step checklists, formulas, and operational rules)
6. **Objective Examination** (Interactive multiple-choice quiz with immediate grading, 80% pass threshold, and answer explanations)

---

### 3. Verifiable Digital Certification System
* **Unique Cryptographic Code:** Every certificate receives an immutable ID (e.g. `NX-CERT-2026-X8921`).
* **Holographic Seal & Signature:** Official NovaXpress seal, candidate name, date, role title, and distinction score.
* **One-Click Printing / PDF Export:** Print-optimized stylesheet (`window.print()`).
* **Public Verification Endpoint:** Anyone can visit `https://learn.novaxpressng.com/verify/NX-CERT-XXXXX` to authenticate the validity of the certificate in real-time.

---

### 4. Super Admin Management Studio
When logged in as a **Super Admin** (`emeraldcodelines@gmail.com`):
* **Curriculum Studio:** Create new training modules, embed screen record URLs, edit transcripts, write summaries, and add objective examination questions.
* **Trainee Roster:** Live roster of all registered candidates, track their progress percentage, inspect quiz scores, and manually grant certificates.
* **Certificate Registry:** Search, inspect, and audit all issued certificates across the company.

---

## 🚀 3-Minute cPanel Deployment to `learn.novaxpressng.com`

### Step 1: Create Subdomain in cPanel
1. In cPanel, go to **Domains** -> **Create A New Domain**.
2. Domain: **`learn.novaxpressng.com`**.
3. Document Root: Ensure it points to:
   ```
   /home/novadrip/learn.novaxpressng.com
   ```
   *(Uncheck "Share document root with public_html")*.
4. Click **Submit**.

---

### Step 2: Add DNS A Record in Zone Editor
1. In cPanel, go to **Zone Editor** -> click **Manage** (or **+ A Record**) next to `novaxpressng.com`.
2. Add an **A Record**:
   * **Name:** `learn.novaxpressng.com.` (or just `learn`)
   * **Address:** `66.29.141.121`
   * **TTL:** `1200`
3. Click **Save Record**.

---

### Step 3: Upload and Extract Zip Archive
1. In cPanel, open **File Manager**.
2. Double-click the folder: **`learn.novaxpressng.com`**.
3. Click **Upload** and upload the ready-made archive from your project root:
   ```
   C:\PROJECT\NoveXPS\novaxpress_learn_cpanel.zip
   ```
4. Once uploaded (100% Green), return to File Manager.
5. Right-click **`novaxpress_learn_cpanel.zip`** -> **Extract** -> Click **Extract Files**.
6. Delete the zip archive.

---

### Step 4: Access NovaXpress Academy
Navigate to:
```
https://learn.novaxpressng.com
```
* The platform will load instantly (< 500ms).
* Log in using your Super Admin credentials (`emeraldcodelines@gmail.com`) to manage the curriculum, or test with any staff account from [`CREDENTIALS.md`](file:///c:/PROJECT/NoveXPS/CREDENTIALS.md)!

