# Supabase-backed POS: sessions, roles, inventory, and staff KPI plan

## Goal

Connect the Flutter POS to Supabase and introduce authenticated sessions for **staff** and **admin** users. Admins manage inventory; staff can sell products but cannot add, edit, restock, or delete inventory. Completed transactions must be timestamped and attributable to the signed-in staff member so the Transactions tab can show each staff member’s daily sales KPI. Products will later be seeded or bulk-imported from CSV.

This document is a plan only. No feature implementation is included yet.

## Current-state findings

- The existing Scan screen is `HomePage`; it contains the live camera scanner and cart.
- Products are currently persisted locally in Hive and include `barcode`, `price`, and `stock`.
- The existing Add Product screen supports barcode scanning and manual product details.
- There is no transaction/history model or persistence; the cart is cleared after a completed print flow.
- Shop details are persisted locally. There is no user/session or role model.
- The current app has Scan, Inventory, and Transactions planned as its three primary destinations.

## Roles and user flows

### 1. Authentication and session

1. On launch, restore the Supabase Auth session when one exists; otherwise show a login screen.
2. Users sign in with credentials created and managed through Supabase Auth.
3. Load the matching application profile (`admin` or `staff`) before displaying the POS shell.
4. The profile/settings hub shows the signed-in user’s name and role and provides **Sign out**.
5. On sign-out, clear in-memory cart/session state and return to login. Local cached data must never grant access without a valid Supabase session.

### 2. Admin inventory management

- Admins can view, search, add, edit, restock, and delete products.
- Barcode scan and manual barcode entry can be used during add/restock.
- For an existing barcode, show the matching product and add stock rather than creating a duplicate.
- Admins can import products from a validated CSV file (see CSV import section).

### 3. Staff sales flow

- Staff can scan and add available products to the cart, adjust cart quantities, review, and complete a cash sale. Receipt printing and QR/barcode payment are deferred, while the existing printer code remains retained for a future release.
- Staff can view inventory for product lookup and stock visibility, but all inventory-mutating controls are hidden and server-side access is denied.
- Staff use Transactions to see their own sales activity and daily KPI. They cannot browse another staff member’s transactions.

### 4. Transactions and KPI

1. On confirmed checkout, create one immutable transaction attributed to the signed-in user and stamped with the server-side sale time.
2. Store a transaction-item snapshot for each line: product ID, barcode, product name, unit price, and quantity.
3. The transaction list displays the sale date/time, staff name (where permitted), item count, and total.
4. The staff KPI view defaults to **today** and shows at least transaction count, units sold, and gross sales total. It can filter by a date or date range.
5. Admins can view KPI and transactions for all staff, filter by staff member and date range, and open a transaction detail. Staff see only their own results.

## Supabase data and security design

### Authentication and profiles

- Use Supabase Auth for sign-in, sign-out, session refresh, and password reset if needed.
- Create a `profiles` table keyed by `auth.users.id`, with `display_name`, `role` (`admin` or `staff`), and timestamps.
- Assign roles only through trusted admin/server workflows; the client must not be able to promote itself.
- Use a database trigger or secure provisioning flow to create a default staff profile for a new Auth user.

### Core tables

| Table | Key fields | Purpose |
| --- | --- | --- |
| `profiles` | `id`, `display_name`, `role` | User identity and authorization role |
| `products` | `id`, `barcode` (unique), `name`, `price`, `stock`, timestamps | Authoritative inventory catalogue |
| `transactions` | `id`, `staff_id`, `completed_at`, `total`, optional `shop_name` | Immutable completed-sale header |
| `transaction_items` | `id`, `transaction_id`, product snapshot fields, `quantity`, `unit_price` | Immutable sale lines for receipts, history, and KPI |

- Use `timestamptz` and a database default such as `now()` for `completed_at`; render it in the shop’s local timezone in Flutter.
- Complete checkout through a Supabase RPC/database transaction that validates stock, writes the transaction and its items, decrements stock, and returns the completed sale atomically.
- Keep stock non-negative by default. Any later negative-stock mode must be an explicit admin setting.

### Row Level Security (RLS)

- Enable RLS on all application tables.
- Both roles may read active products needed for selling; only admins may insert, update, or delete products.
- Staff may insert a transaction only through the checkout RPC, which always derives `staff_id` from `auth.uid()` rather than a client-supplied value.
- Staff can select only transactions and transaction items where `staff_id = auth.uid()`.
- Admins can read all transactions and staff KPI data.
- Direct updates/deletes of completed transactions and transaction items are denied for every client role.
- Verify each policy with Supabase SQL tests or an equivalent admin/staff test matrix; UI restrictions are not the security boundary.

## Flutter architecture changes

- Add Supabase Flutter configuration, environment-based URL/anon-key setup, initialization, and an auth/session repository.
- Add `AuthBloc`/state management following the existing project conventions: loading, unauthenticated, authenticated profile, and authorization failure states.
- Replace Hive as the source of truth for products and transactions with Supabase repositories. A short-lived local cache/offline strategy can be designed separately; do not allow it to bypass role checks.
- Refactor the root layout into an authenticated shell that owns Scan, Inventory, and Transactions while preserving the cart within the active session.
- Centralize permission checks in a role/capability layer and also use them to conditionally render inventory-management actions.
- Use server-returned checkout results before clearing the cart. Receipt printing is out of scope for this release and must not block or duplicate a recorded sale when re-enabled later.

## CSV product seed/import plan

- Define and document a CSV template with required columns: `barcode`, `name`, `price`, and `stock`. Optional fields can be added only with an accompanying schema/version update.
- Provide an admin-only Import Products action that picks a CSV file, parses it locally, and shows a validation preview before any data is written.
- Validate required values, barcode uniqueness inside the file, numeric non-negative price/stock, and conflicts with existing product barcodes.
- Let the admin explicitly choose the duplicate-barcode behavior before import: reject the row, update the product, or increase stock. The default should be **reject and report** to prevent accidental overwrites.
- Submit valid rows through a protected bulk-import RPC so validation and admin authorization are enforced on the server. Return row-level success/error results and retain an import summary.
- For initial catalogue seeding, use the same validated import schema via a Supabase SQL/scripted migration or the admin import screen. Never place production service-role credentials in the Flutter app.

## Implementation sequence

1. Add Supabase project configuration and environment handling; define migrations for profiles, products, transactions, transaction items, indexes, checkout RPC, and RLS policies.
2. Implement auth/session/profile loading, login and sign-out UI, and role-aware application shell.
3. Move product reads and admin-only inventory mutations from Hive to Supabase; adapt add/restock/edit/delete screens and barcode lookup.
4. Implement atomic checkout and transaction persistence with server timestamps and stock deduction. Retain the existing printer integration in disabled/commented form for a later release.
5. Build Transactions list/detail and KPI filters: self-only daily KPI for staff, all-staff date-filtered KPI for admins.
6. Add the admin CSV import preview, validation, protected bulk import, and initial-seed workflow.
7. Add integration/RLS tests for both roles, widget tests for guarded UI, checkout/stock tests, CSV validation tests, and an Android-device smoke test.

## Acceptance checks

- A user without a valid Supabase session cannot enter the POS; the previous session restores securely when valid.
- Admins can add, edit, restock, delete, and CSV-import products; staff cannot perform those actions in the UI or through Supabase APIs.
- Staff can complete sales using available products and can view only their own transaction/KPI data.
- Every completed sale has an immutable transaction ID, authenticated staff ID, server-generated date/time, item snapshots, and total.
- A staff member’s default KPI shows today’s transaction count, units sold, and gross sales correctly; admins can filter those figures by staff and date range.
- Checkout changes stock and records the transaction atomically, with no duplicate sale from retry handling. Printing is not invoked in this release.
- CSV import rejects invalid rows, presents clear row-level errors, and never exposes elevated Supabase credentials in the app.
- RLS policy tests prove the admin/staff permissions above; release/debug Android builds analyze cleanly apart from known pre-existing info lints.

## Decisions needed before implementation

1. Should staff be allowed to see current stock quantities, or only product availability/name/price?
2. Sales are cash-only for this release. Should the later KPI design track payment method, discounts, costs, and net profit in addition to gross sales?
3. Should admins create staff accounts in a simple admin screen, or should account provisioning remain in the Supabase dashboard initially?
4. For CSV duplicates, is the proposed default (**reject and report**) correct, and which of update versus restock should be available as an override?
