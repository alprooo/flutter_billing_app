# Inventory, navigation, and store-header plan

## Goal

Extend the POS so staff can add or restock products by barcode scan or manual entry, navigate between Scan, Inventory, and Transactions, and see a store-branded header with access to profile settings.

This document is a plan only. No feature implementation is included yet.

## Current-state findings

- The existing Scan screen is `HomePage`; it contains the live camera scanner and cart.
- Products are saved locally in Hive and already include `barcode`, `price`, and `stock`.
- The existing Add Product screen supports barcode scanning and manual product details, but it rejects an existing barcode instead of treating it as a restock.
- There is no transaction/history model or persistence yet; the cart is cleared after a completed print flow.
- Shop details are already persisted and include the shop name, but there is no logo or user-profile data model.
- The current top-right video icon only turns the scanner camera on/off.

## Proposed user flows

### 1. Add product or restock inventory

1. From **Inventory**, staff chooses **Add / Restock**.
2. They can either scan a barcode or use a clearly labelled manual-entry action (`Icons.edit_note` or `Icons.keyboard`).
3. After scanning or entering a barcode:
   - If the barcode is new, show a product form for name, selling price, and opening/restock quantity.
   - If the barcode already exists, show the matching product and a restock form with a quantity field. Saving increases its current stock and retains its name and price.
4. Show a confirmation message with the new stock quantity.

### 2. Three primary destinations

Use a persistent `NavigationBar` with:

| Menu | Purpose | Existing/new screen |
| --- | --- | --- |
| Scan | Scan products into the current cart and review the order | Adapt current `HomePage` |
| Inventory | Search, add, edit, and restock products | Adapt `ProductListPage` plus a new add/restock flow |
| Transactions | Browse completed sales and open their details | New feature |

The active cart must survive switching between Scan and Inventory/Transactions during the same app session.

### 3. Store header and profile

On the Scan screen header:

- Left: a circular store-logo placeholder; use the first letter of the shop name until photo/logo support is added.
- Center: the persisted shop name, with a fallback such as `Anugrah Ukui` when it has not been configured.
- Right: a profile icon that opens a new Profile & Settings page.

The Profile & Settings page will provide access to existing **Shop Details** and **Printer Settings**. It will not introduce authentication unless separately requested.

### 4. Replace the video icon

Replace the scanner camera-toggle video icon with a manual-entry icon. Tapping it opens a small dialog or bottom sheet where staff can type a barcode, then follows the same new-product/restock lookup flow. The flash control remains available.

Because this removes the only camera on/off control, the scanner stays on while the Scan tab is active and is stopped when that tab is left. Camera permission/error states remain handled.

## Data and architecture changes

### Inventory

- Keep `Product.stock` as the authoritative on-hand quantity.
- Add a `RestockProduct` Bloc event/use case/repository method that receives product ID and quantity, validates a positive quantity, and writes an updated product to Hive.
- Extend the add-product form to collect stock quantity and create the product with that value.
- Prevent duplicate barcodes. Existing barcode lookup routes to restock rather than create.

### Transactions

- Add immutable `Transaction` and `TransactionItem` entities/models, with transaction ID, timestamp, item snapshot (name, barcode, unit price, quantity), total, and optional shop-name snapshot.
- Register Hive adapters and open a dedicated `transactions` box in `HiveDatabase`.
- Add transaction repository, use cases, and a `TransactionBloc` following the existing feature structure.
- On confirmed checkout, save the completed transaction and update stock before clearing the cart. Receipt printing is a separate outcome: a printing failure must be shown clearly and must not silently discard the cart before checkout is confirmed.
- Provide newest-first transaction list and a detail screen. No refunds, voids, export, customer data, or payment-method tracking in this first release.

### Header/profile/logo

- Reuse `ShopBloc` for shop-name display.
- Add a nullable `logoPath` only if image selection is included in this release. Otherwise, ship the letter-based placeholder with no data migration.
- Build a small profile/settings hub screen rather than duplicating current Shop and Printer settings pages.

## Implementation sequence

1. Refactor the root layout into a shell that owns the three-tab navigation and scanner lifecycle; preserve the current cart Bloc above the tabs.
2. Build the reusable store header and profile/settings hub; wire shop name and the logo placeholder.
3. Implement barcode lookup plus the add/restock form, manual barcode entry action, stock validation, and Hive product update.
4. Adapt the Inventory tab: stock counts, Add / Restock entry point, search/scan lookup, and existing edit/delete actions.
5. Add transaction models, Hive persistence, repository/use cases/Bloc, checkout recording, transaction list, and detail page.
6. Replace the scanner video action with manual entry and verify camera lifecycle/permission behavior.
7. Add tests and run formatting, analyzer, and an Android device smoke test.

## Acceptance checks

- A newly scanned or manually entered barcode creates a product with a positive starting stock.
- Scanning or manually entering an existing barcode increases only its stock and does not create a duplicate.
- The scanner video icon is gone; the replacement opens manual barcode entry.
- Scan, Inventory, and Transactions are visible in the bottom navigation and preserve the cart when switching tabs.
- The header displays logo placeholder, store name, and profile icon; profile settings can reach shop and printer settings.
- A completed sale appears in Transactions with item, quantity, Rupiah amount, and date/time.
- Stock behavior is explicitly verified after a sale (see review question below).
- Existing product data opens without migration errors; release/debug Android builds analyze cleanly apart from known pre-existing info lints.

## Decisions needed before implementation

1. **Sale stock deduction:** Should completing a sale automatically reduce on-hand stock? This plan recommends **yes**, while preventing the stock from going below zero unless you want negative-stock sales.
2. **Store logo:** Is a letter placeholder acceptable for this release, or should profile settings allow selecting a logo image from the phone?
3. **Transactions:** Should a transaction be recorded when the user presses Review/Confirm, or only after Bluetooth receipt printing succeeds? This plan recommends recording it on confirmed checkout even if printing is unavailable, with print status shown separately.
4. **Manual-entry icon:** The plan proposes `Icons.edit_note`; confirm if you have a different icon in mind.
