# Entity Relationship Diagram

The application stores these entities as JSON documents in one CouchDB database. Each document is identified by CouchDB's `_id` and distinguished by its `type` value. The relationships below are logical references; CouchDB does not enforce foreign keys.

```mermaid
erDiagram
    CUSTOMER ||--o{ LAUNDRY_ORDER : places
    LAUNDRY_SERVICE ||--o{ LAUNDRY_ORDER : selected_for
    LAUNDRY_ORDER ||--o{ LAUNDRY_PAYMENT : has

    CUSTOMER {
        string _id PK
        string type "customer"
        string full_name
        string contact_number
        string email
        string address
        datetime created_at
        datetime updated_at
    }

    LAUNDRY_SERVICE {
        string _id PK
        string type "service"
        string service_name
        string description
        int price_per_kg_centavos
        int estimated_completion_hours
        boolean is_available
        datetime created_at
        datetime updated_at
    }

    LAUNDRY_ORDER {
        string _id PK
        string type "order"
        string customer_id FK
        string customer_name "snapshot"
        string service_id FK
        string service_name "snapshot"
        int weight_grams
        int price_per_kg_centavos "price snapshot"
        int total_amount_centavos
        datetime order_date
        datetime expected_pickup_date
        string order_status
        string special_instructions
        datetime created_at
        datetime updated_at
    }

    LAUNDRY_PAYMENT {
        string _id PK
        string type "payment"
        string order_id FK
        string customer_name "snapshot"
        int amount_centavos
        string payment_method
        datetime payment_date
        string payment_reference
        boolean is_voided
        datetime created_at
        datetime voided_at "optional"
    }
```

## Relationship and Storage Notes

- A customer can have zero or more orders. Each order records one `customer_id` and the customer's name at order creation.
- A laundry service can be used by zero or more orders. Each order records one `service_id`, the service name, and the per-kilogram price at order creation. Referenced services are made unavailable instead of deleted.
- An order can have zero or more payments. Each payment records one `order_id`; its `customer_name` is a snapshot copied from that order, not a separate customer reference.
- Customers and services referenced by order history are retained. The app blocks deletion of those customers and deactivates those services.
- `_rev` is CouchDB-managed document revision metadata and is omitted from the domain attributes above. `payment_status` and remaining balance are calculated from an order and its non-voided payments; they are not stored as fields.
- Money is stored as integer centavos and laundry weight as integer grams. Readers also accept legacy fields (`price_per_kg`, `total_amount`, `amount_paid`, and `laundry_weight`) and convert them to the current units.

## Enumerated Values

- `order_status`: `Pending`, `Washing`, `Drying`, `Folding`, `Ready for Pickup`, `Claimed`, `Cancelled`
- `payment_method`: `Cash`, `GCash`, `Maya`, `Bank Transfer`
