# Laundry Shop Management System

Flutter desktop application for managing customers, laundry services, orders,
and payment records using a single Apache CouchDB database.

## Features

- Responsive Windows desktop shell and Material 3 interface.
- Customer create, search, edit, and delete (deletion is blocked when order
  history exists).
- Laundry service create, search, edit, availability toggle, and delete
  (referenced services are deactivated instead of removed).
- Order creation from existing customers and available services, integer-safe
  price calculation, pickup dates, search, status filtering, and status edits.
- Payment recording with outstanding-balance checks, order payment history,
  and soft voiding that retains financial audit records.
- Live dashboard counts, payments, outstanding balances, and recent orders.
- CouchDB indexes for document type and common entity references.

## Run on Windows

Requires Flutter with Windows desktop support and the Windows build toolchain.

```powershell
flutter pub get
flutter run -d windows
```

In the app, open **Settings**:

1. Enter the CouchDB base URL, such as `http://localhost:5984`.
2. Keep the database name `laundry_db`, or enter another existing database.
3. Enter credentials for a CouchDB user restricted to this database.
4. Choose **Connect and load data**.

The database must already exist. On first connection, the app creates Mango
indexes used by its entity queries. The connected user therefore needs
read/write access to the database and permission to create indexes.

For the implementation flow, HTTP endpoints, credentials, indexes, and data
loading details, see [CouchDB Connection and Data Flow](DATABASE_CONNECTION.md).

## Data model

All records are JSON documents in the selected database and include a `type`
field: `customer`, `service`, `order`, or `payment`. IDs are prefixed, for
example `customer_…` and `order_…`. Orders preserve customer/service names and
the service price at the time the order is created.

Money is stored as integer centavos (for example, `price_per_kg_centavos`) and
weight as integer grams (`weight_grams`). This avoids floating-point money
calculations. Existing documents using the earlier `price_per_kg`,
`total_amount`, `amount_paid`, or `laundry_weight` fields can be read; newly
created documents use the integer fields.

The app manages CouchDB `_rev` values through document reads and updates.
Payment corrections are recorded by marking the original payment void rather
than deleting it. Orders are cancelled through their status and cannot be
cancelled while payments remain recorded. Customers with order history cannot
be deleted; services referenced by orders are marked unavailable instead.

## Security and consistency

- The database URL/name are saved locally; the CouchDB username/password are
  entered at runtime and held in memory only.
- Do not use CouchDB administrator credentials. Desktop application
  credentials can be extracted, so use an authenticated backend for production.
- HTTP is allowed only for a loopback address. Remote CouchDB connections must
  use HTTPS.
- Payment balance checks refresh the database before recording a receipt, but
  CouchDB does not provide a multi-document transaction. Concurrent payment
  writers may race; use a trusted backend that serializes/validates payments
  before using this for production financial operations.

## Verify

```powershell
flutter analyze
flutter test
flutter build windows
```
