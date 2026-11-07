# CouchDB Connection and Data Flow

This document describes how the Flutter app connects to Apache CouchDB, based
on the implementation in `lib/config/couchdb_settings.dart`,
`lib/features/settings/couchdb_settings_screen.dart`,
`lib/data/couchdb_client.dart`, and `lib/data/laundry_store.dart`.

## Connection overview

The app connects directly from the Flutter desktop client to CouchDB over
HTTP(S); it does not use a separate API server. The connection and data-loading
sequence is:

1. The user opens **Settings** and enters a CouchDB base URL, database name,
   username, and password.
2. The settings screen builds a `CouchDbConfig` and `CouchDbClient`.
   Configuration validation checks the URL, database name, and credentials.
3. **Connect and load data** requests database information from CouchDB.
   The database must already exist and the user must be allowed to access it.
4. The screen creates a `LaundryStore` around the client and calls
   `refresh()`. The store creates the app's Mango indexes and loads each
   document type.
5. After a successful load, the app installs that store in `AppShell`, replacing
   and disposing the previous store if there was one. Management screens then
   use the in-memory store until the app closes or another connection replaces
   it.

```text
Settings screen
    └── CouchDbConfig (URL, database, runtime credentials)
          └── CouchDbClient (HTTP requests)
                └── LaundryStore.refresh()
                      ├── create Mango indexes
                      ├── load customer/service/order/payment documents
                      └── AppShell supplies store to feature screens
```

Relevant source files:

- `lib/features/settings/couchdb_settings_screen.dart`: connection UI,
  validation, tests, and store handoff.
- `lib/config/couchdb_settings.dart`: persistence of the base URL and database
  name using `shared_preferences`.
- `lib/data/couchdb_client.dart`: URL construction, authentication, HTTP
  operations, response parsing, timeout, and CouchDB errors.
- `lib/data/laundry_store.dart`: indexes, entity queries, model conversion, and
  application-level create/update/delete workflows.
- `lib/features/app_shell.dart`: ownership and disposal of the active store.

## Settings and credentials

`CouchDbSettings` saves only the trimmed base URL and database name on the
device. The database defaults to `laundry_db`. The username and password are
entered at runtime; they are not saved by `CouchDbSettings`. The
`CouchDbConfig` passed to the active client holds them in memory while that
connection is in use.

The base URL must use `http://` or `https://`, must not include credentials,
query parameters, or a fragment, and the database name must follow CouchDB's
lowercase database-name restrictions enforced by `CouchDbConfig`. Non-local
servers must use HTTPS. HTTP is accepted only for localhost or a loopback IP
address.

The client sends JSON requests with an HTTP Basic Authorization header. That
header is constructed from the runtime username and password for each request.
Use a CouchDB user restricted to the selected database, not an administrator
account. Because this is a desktop app, credentials used by the app should not
be considered secret from a user with access to the machine. For production
systems that require stronger credential isolation or authorization, put a
trusted backend between the app and CouchDB.

## CouchDB requests

`CouchDbConfig.uriFor()` appends the selected database and an endpoint to the
base URL. For a base URL of `http://localhost:5984` and database
`laundry_db`, the client uses CouchDB endpoints such as:

| Purpose | Request |
| --- | --- |
| Verify database access and read its metadata | `GET /laundry_db` |
| Read a document and its current revision | `GET /laundry_db/{document-id}` |
| Create a document | `PUT /laundry_db/{document-id}` |
| Update a document | `PUT /laundry_db/{document-id}` |
| Delete a document using its revision | `DELETE /laundry_db/{document-id}?rev={revision}` |
| Query documents with Mango | `POST /laundry_db/_find` |
| Create a Mango index | `POST /laundry_db/_index` |

The client has a 12-second timeout for an HTTP request. Non-2xx responses,
timeouts, network failures, invalid JSON, and unexpected response shapes are
reported as `CouchDbException`s with user-facing error messages.

## Initial load and indexes

On connection, `LaundryStore.refresh()` first ensures these Mango JSON indexes
exist:

- `laundry-type` on `type`
- `laundry-type-order` on `type` and `order_id`
- `laundry-type-customer` on `type` and `customer_id`
- `laundry-type-service` on `type` and `service_id`
- `laundry-type-status` on `type` and `order_status`

The store then runs one `_find` query for each document `type`: `customer`,
`service`, `order`, and `payment`. Each query selects documents by `type` and
loads results in pages of 500. The JSON documents are converted to the app's
typed models and sorted for the screens.

The database has to be created separately in CouchDB before connecting. The
configured user needs database read/write access, and CouchDB must allow that
user to create the indexes on the first load.

## Reading and writing records

The screens call methods on `LaundryStore` rather than issuing HTTP requests
themselves. The store applies application rules and delegates persistence to
`CouchDbClient`. New documents are sent as JSON with a prefixed ID such as
`customer_<random-value>` or `order_<random-value>`, and a `type` field
identifying the entity.

For updates, the client first reads the existing document, merges the requested
changes, and sends the full document including its current CouchDB `_rev`.
Deletes also read the current document and submit its `_rev`. CouchDB uses
these revisions for optimistic concurrency; a stale revision can result in a
409 conflict. The app does not set or guess `_rev` values itself.

After a successful store operation, `refresh()` reloads the document
collections so the UI reflects CouchDB's current state. The store is held in
memory by `AppShell`; disposing or replacing it closes the owned HTTP client.

## Testing a connection

The Settings screen provides two checks:

- **Test database connection** requests the selected database's metadata and
  reports its document count. This verifies reachability, authentication, and
  database access.
- **Test CRUD operations** creates a uniquely named temporary
  `connection_test` document, reads and verifies it, updates it, then deletes
  it. If an operation fails after creation, the client attempts to remove the
  matching temporary document.

These are live checks against the configured database. The CRUD test writes a
temporary document before deleting it, so run it only against a database where
the configured account is permitted to create, update, and delete documents.

## Data and consistency notes

All business entities are JSON documents in the same database. The `type`
field distinguishes customers, services, orders, and payments. Relationships
are stored as IDs in document fields; CouchDB does not enforce foreign keys.
See `ERD.md` for the entity fields and logical relationships.

Updates to a single document use CouchDB revisions, but CouchDB does not make
the app's multi-document business operations transactional. In particular,
payment recording refreshes the store before checking an order's outstanding
balance, but simultaneous clients can still race and both attempt to record
payments. Use a trusted backend to serialize or validate financial operations
if this app is used for production payments.
