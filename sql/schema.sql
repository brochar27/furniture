-- Furniture shop schema (PostgreSQL 14+)
-- Catalog, inventory, procurement, sales, delivery, and after-sales.

BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS citext;

-- ---------------------------------------------------------------------------
-- Enums
-- ---------------------------------------------------------------------------

CREATE TYPE employee_role AS ENUM (
  'owner', 'manager', 'salesperson', 'designer', 'warehouse', 'driver', 'support'
);

CREATE TYPE address_kind AS ENUM ('billing', 'shipping', 'store', 'warehouse', 'other');

CREATE TYPE product_status AS ENUM ('draft', 'active', 'discontinued');

CREATE TYPE stock_movement_type AS ENUM (
  'receipt', 'sale', 'return', 'transfer', 'adjustment', 'damage'
);

CREATE TYPE po_status AS ENUM ('draft', 'sent', 'partial', 'received', 'cancelled');

CREATE TYPE order_status AS ENUM (
  'draft', 'placed', 'paid', 'fulfilled', 'cancelled', 'refunded'
);

CREATE TYPE payment_method AS ENUM ('card', 'cash', 'financing', 'bank_transfer', 'store_credit');

CREATE TYPE payment_status AS ENUM ('pending', 'authorized', 'captured', 'failed', 'refunded');

CREATE TYPE shipment_status AS ENUM (
  'pending', 'scheduled', 'in_transit', 'delivered', 'failed', 'returned'
);

CREATE TYPE return_status AS ENUM ('requested', 'approved', 'received', 'rejected', 'refunded');

CREATE TYPE appointment_kind AS ENUM ('design_consult', 'measure', 'delivery', 'pickup', 'repair');

CREATE TYPE appointment_status AS ENUM ('scheduled', 'completed', 'cancelled', 'no_show');

CREATE TYPE warranty_claim_status AS ENUM ('open', 'in_review', 'approved', 'denied', 'closed');

-- ---------------------------------------------------------------------------
-- People and places
-- ---------------------------------------------------------------------------

CREATE TABLE stores (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code          text NOT NULL UNIQUE,
  name          text NOT NULL,
  phone         text,
  email         citext,
  timezone      text NOT NULL DEFAULT 'America/Los_Angeles',
  opened_on     date,
  is_active     boolean NOT NULL DEFAULT true,
  created_at    timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE warehouses (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id      uuid REFERENCES stores (id),
  code          text NOT NULL UNIQUE,
  name          text NOT NULL,
  is_active     boolean NOT NULL DEFAULT true,
  created_at    timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE employees (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id      uuid NOT NULL REFERENCES stores (id),
  role          employee_role NOT NULL,
  first_name    text NOT NULL,
  last_name     text NOT NULL,
  email         citext NOT NULL UNIQUE,
  phone         text,
  hired_on      date NOT NULL DEFAULT CURRENT_DATE,
  is_active     boolean NOT NULL DEFAULT true,
  created_at    timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE customers (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email         citext NOT NULL UNIQUE,
  first_name    text NOT NULL,
  last_name     text NOT NULL,
  phone         text,
  notes         text,
  created_at    timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE addresses (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id   uuid REFERENCES customers (id) ON DELETE CASCADE,
  store_id      uuid REFERENCES stores (id) ON DELETE CASCADE,
  warehouse_id  uuid REFERENCES warehouses (id) ON DELETE CASCADE,
  kind          address_kind NOT NULL,
  line1         text NOT NULL,
  line2         text,
  city          text NOT NULL,
  region        text NOT NULL,
  postal_code   text NOT NULL,
  country       char(2) NOT NULL DEFAULT 'US',
  is_default    boolean NOT NULL DEFAULT false,
  created_at    timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT addresses_one_owner CHECK (
    num_nonnulls(customer_id, store_id, warehouse_id) = 1
  )
);

CREATE INDEX addresses_customer_idx ON addresses (customer_id);

-- ---------------------------------------------------------------------------
-- Catalog
-- ---------------------------------------------------------------------------

CREATE TABLE categories (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  parent_id     uuid REFERENCES categories (id),
  slug          text NOT NULL UNIQUE,
  name          text NOT NULL,
  sort_order    int NOT NULL DEFAULT 0
);

CREATE TABLE brands (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name          text NOT NULL UNIQUE,
  country       char(2),
  website       text
);

CREATE TABLE materials (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name          text NOT NULL UNIQUE,
  care_notes    text
);

CREATE TABLE finishes (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name          text NOT NULL UNIQUE,
  hex_color     char(7)
);

CREATE TABLE products (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  category_id     uuid NOT NULL REFERENCES categories (id),
  brand_id        uuid REFERENCES brands (id),
  sku_prefix      text NOT NULL UNIQUE,
  name            text NOT NULL,
  description     text,
  status          product_status NOT NULL DEFAULT 'draft',
  width_cm        numeric(8, 1),
  depth_cm        numeric(8, 1),
  height_cm       numeric(8, 1),
  weight_kg       numeric(8, 2),
  assembly_req    boolean NOT NULL DEFAULT false,
  lead_time_days  int NOT NULL DEFAULT 0 CHECK (lead_time_days >= 0),
  created_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX products_category_idx ON products (category_id);
CREATE INDEX products_status_idx ON products (status);

CREATE TABLE product_materials (
  product_id    uuid NOT NULL REFERENCES products (id) ON DELETE CASCADE,
  material_id   uuid NOT NULL REFERENCES materials (id),
  is_primary    boolean NOT NULL DEFAULT false,
  PRIMARY KEY (product_id, material_id)
);

CREATE TABLE product_variants (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id      uuid NOT NULL REFERENCES products (id) ON DELETE CASCADE,
  finish_id       uuid REFERENCES finishes (id),
  sku             text NOT NULL UNIQUE,
  name            text NOT NULL,
  list_price      numeric(12, 2) NOT NULL CHECK (list_price >= 0),
  cost            numeric(12, 2) NOT NULL CHECK (cost >= 0),
  is_active       boolean NOT NULL DEFAULT true,
  created_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX product_variants_product_idx ON product_variants (product_id);

CREATE TABLE product_images (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id    uuid NOT NULL REFERENCES products (id) ON DELETE CASCADE,
  variant_id    uuid REFERENCES product_variants (id) ON DELETE CASCADE,
  url           text NOT NULL,
  alt_text      text,
  sort_order    int NOT NULL DEFAULT 0
);

-- ---------------------------------------------------------------------------
-- Inventory
-- ---------------------------------------------------------------------------

CREATE TABLE inventory_levels (
  warehouse_id  uuid NOT NULL REFERENCES warehouses (id),
  variant_id    uuid NOT NULL REFERENCES product_variants (id),
  on_hand       int NOT NULL DEFAULT 0 CHECK (on_hand >= 0),
  reserved      int NOT NULL DEFAULT 0 CHECK (reserved >= 0),
  reorder_point int NOT NULL DEFAULT 0 CHECK (reorder_point >= 0),
  updated_at    timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (warehouse_id, variant_id),
  CONSTRAINT inventory_reserved_lte_on_hand CHECK (reserved <= on_hand)
);

CREATE TABLE stock_movements (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  warehouse_id    uuid NOT NULL REFERENCES warehouses (id),
  variant_id      uuid NOT NULL REFERENCES product_variants (id),
  movement_type   stock_movement_type NOT NULL,
  quantity        int NOT NULL CHECK (quantity <> 0),
  reference       text,
  employee_id     uuid REFERENCES employees (id),
  occurred_at     timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX stock_movements_variant_idx ON stock_movements (variant_id, occurred_at DESC);

-- ---------------------------------------------------------------------------
-- Procurement
-- ---------------------------------------------------------------------------

CREATE TABLE suppliers (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name          text NOT NULL UNIQUE,
  email         citext,
  phone         text,
  payment_terms text NOT NULL DEFAULT 'net 30',
  is_active     boolean NOT NULL DEFAULT true,
  created_at    timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE supplier_contacts (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  supplier_id   uuid NOT NULL REFERENCES suppliers (id) ON DELETE CASCADE,
  name          text NOT NULL,
  email         citext,
  phone         text,
  role          text
);

CREATE TABLE supplier_variants (
  supplier_id     uuid NOT NULL REFERENCES suppliers (id),
  variant_id      uuid NOT NULL REFERENCES product_variants (id),
  supplier_sku    text,
  unit_cost       numeric(12, 2) NOT NULL CHECK (unit_cost >= 0),
  min_order_qty   int NOT NULL DEFAULT 1 CHECK (min_order_qty > 0),
  lead_time_days  int NOT NULL DEFAULT 14 CHECK (lead_time_days >= 0),
  PRIMARY KEY (supplier_id, variant_id)
);

CREATE TABLE purchase_orders (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  supplier_id   uuid NOT NULL REFERENCES suppliers (id),
  warehouse_id  uuid NOT NULL REFERENCES warehouses (id),
  employee_id   uuid REFERENCES employees (id),
  po_number     text NOT NULL UNIQUE,
  status        po_status NOT NULL DEFAULT 'draft',
  ordered_on    date NOT NULL DEFAULT CURRENT_DATE,
  expected_on   date,
  notes         text,
  created_at    timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE purchase_order_lines (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  po_id         uuid NOT NULL REFERENCES purchase_orders (id) ON DELETE CASCADE,
  variant_id    uuid NOT NULL REFERENCES product_variants (id),
  quantity      int NOT NULL CHECK (quantity > 0),
  unit_cost     numeric(12, 2) NOT NULL CHECK (unit_cost >= 0),
  received_qty  int NOT NULL DEFAULT 0 CHECK (received_qty >= 0),
  UNIQUE (po_id, variant_id),
  CONSTRAINT pol_received_lte_ordered CHECK (received_qty <= quantity)
);

CREATE TABLE goods_receipts (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  po_id         uuid NOT NULL REFERENCES purchase_orders (id),
  warehouse_id  uuid NOT NULL REFERENCES warehouses (id),
  employee_id   uuid REFERENCES employees (id),
  received_at   timestamptz NOT NULL DEFAULT now(),
  notes         text
);

CREATE TABLE goods_receipt_lines (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  receipt_id    uuid NOT NULL REFERENCES goods_receipts (id) ON DELETE CASCADE,
  po_line_id    uuid NOT NULL REFERENCES purchase_order_lines (id),
  quantity      int NOT NULL CHECK (quantity > 0)
);

-- ---------------------------------------------------------------------------
-- Pricing and promotions
-- ---------------------------------------------------------------------------

CREATE TABLE promotions (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code          text UNIQUE,
  name          text NOT NULL,
  percent_off   numeric(5, 2) CHECK (percent_off IS NULL OR (percent_off > 0 AND percent_off <= 100)),
  amount_off    numeric(12, 2) CHECK (amount_off IS NULL OR amount_off > 0),
  starts_on     date NOT NULL,
  ends_on       date NOT NULL,
  is_active     boolean NOT NULL DEFAULT true,
  CONSTRAINT promo_has_discount CHECK (num_nonnulls(percent_off, amount_off) = 1),
  CONSTRAINT promo_dates CHECK (ends_on >= starts_on)
);

CREATE TABLE promotion_variants (
  promotion_id  uuid NOT NULL REFERENCES promotions (id) ON DELETE CASCADE,
  variant_id    uuid NOT NULL REFERENCES product_variants (id),
  PRIMARY KEY (promotion_id, variant_id)
);

-- ---------------------------------------------------------------------------
-- Sales
-- ---------------------------------------------------------------------------

CREATE TABLE orders (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_number    text NOT NULL UNIQUE,
  customer_id     uuid NOT NULL REFERENCES customers (id),
  store_id        uuid NOT NULL REFERENCES stores (id),
  salesperson_id  uuid REFERENCES employees (id),
  ship_address_id uuid REFERENCES addresses (id),
  promotion_id    uuid REFERENCES promotions (id),
  status          order_status NOT NULL DEFAULT 'draft',
  placed_at       timestamptz,
  notes           text,
  created_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX orders_customer_idx ON orders (customer_id, created_at DESC);
CREATE INDEX orders_status_idx ON orders (status);

CREATE TABLE order_lines (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id      uuid NOT NULL REFERENCES orders (id) ON DELETE CASCADE,
  variant_id    uuid NOT NULL REFERENCES product_variants (id),
  warehouse_id  uuid REFERENCES warehouses (id),
  quantity      int NOT NULL CHECK (quantity > 0),
  unit_price    numeric(12, 2) NOT NULL CHECK (unit_price >= 0),
  discount      numeric(12, 2) NOT NULL DEFAULT 0 CHECK (discount >= 0)
);

CREATE TABLE payments (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id        uuid NOT NULL REFERENCES orders (id),
  method          payment_method NOT NULL,
  status          payment_status NOT NULL DEFAULT 'pending',
  amount          numeric(12, 2) NOT NULL CHECK (amount > 0),
  provider_ref    text,
  paid_at         timestamptz,
  created_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX payments_order_idx ON payments (order_id);

CREATE TABLE shipments (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id        uuid NOT NULL REFERENCES orders (id),
  warehouse_id    uuid NOT NULL REFERENCES warehouses (id),
  driver_id       uuid REFERENCES employees (id),
  status          shipment_status NOT NULL DEFAULT 'pending',
  carrier         text,
  tracking_number text,
  scheduled_for   timestamptz,
  delivered_at    timestamptz,
  created_at      timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE shipment_lines (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  shipment_id   uuid NOT NULL REFERENCES shipments (id) ON DELETE CASCADE,
  order_line_id uuid NOT NULL REFERENCES order_lines (id),
  quantity      int NOT NULL CHECK (quantity > 0)
);

CREATE TABLE returns (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id      uuid NOT NULL REFERENCES orders (id),
  status        return_status NOT NULL DEFAULT 'requested',
  reason        text NOT NULL,
  requested_at  timestamptz NOT NULL DEFAULT now(),
  resolved_at   timestamptz
);

CREATE TABLE return_lines (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  return_id     uuid NOT NULL REFERENCES returns (id) ON DELETE CASCADE,
  order_line_id uuid NOT NULL REFERENCES order_lines (id),
  quantity      int NOT NULL CHECK (quantity > 0),
  restock       boolean NOT NULL DEFAULT true
);

-- ---------------------------------------------------------------------------
-- Service
-- ---------------------------------------------------------------------------

CREATE TABLE appointments (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id   uuid NOT NULL REFERENCES customers (id),
  store_id      uuid NOT NULL REFERENCES stores (id),
  employee_id   uuid REFERENCES employees (id),
  order_id      uuid REFERENCES orders (id),
  kind          appointment_kind NOT NULL,
  status        appointment_status NOT NULL DEFAULT 'scheduled',
  starts_at     timestamptz NOT NULL,
  ends_at       timestamptz NOT NULL,
  notes         text,
  CONSTRAINT appointment_window CHECK (ends_at > starts_at)
);

CREATE INDEX appointments_store_time_idx ON appointments (store_id, starts_at);

CREATE TABLE reviews (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id    uuid NOT NULL REFERENCES products (id),
  customer_id   uuid NOT NULL REFERENCES customers (id),
  order_id      uuid REFERENCES orders (id),
  rating        smallint NOT NULL CHECK (rating BETWEEN 1 AND 5),
  title         text,
  body          text,
  created_at    timestamptz NOT NULL DEFAULT now(),
  UNIQUE (product_id, customer_id)
);

CREATE TABLE warranties (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_line_id   uuid NOT NULL UNIQUE REFERENCES order_lines (id),
  coverage_months int NOT NULL CHECK (coverage_months > 0),
  starts_on       date NOT NULL,
  ends_on         date NOT NULL,
  CONSTRAINT warranty_dates CHECK (ends_on > starts_on)
);

CREATE TABLE warranty_claims (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  warranty_id   uuid NOT NULL REFERENCES warranties (id),
  status        warranty_claim_status NOT NULL DEFAULT 'open',
  description   text NOT NULL,
  opened_at     timestamptz NOT NULL DEFAULT now(),
  closed_at     timestamptz
);

-- ---------------------------------------------------------------------------
-- Convenience view
-- ---------------------------------------------------------------------------

CREATE VIEW variant_availability AS
SELECT
  v.id AS variant_id,
  v.sku,
  p.name AS product_name,
  v.name AS variant_name,
  v.list_price,
  COALESCE(SUM(i.on_hand - i.reserved), 0) AS available_qty
FROM product_variants v
JOIN products p ON p.id = v.product_id
LEFT JOIN inventory_levels i ON i.variant_id = v.id
GROUP BY v.id, v.sku, p.name, v.name, v.list_price;

COMMIT;
