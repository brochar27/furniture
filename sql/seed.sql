-- Sample data for the furniture shop. Load after schema.sql.

BEGIN;

INSERT INTO stores (id, code, name, phone, email, opened_on) VALUES
  ('11111111-1111-1111-1111-111111111111', 'SF', 'Harbor & Grain — Hayes Valley', '415-555-0142', 'hayes@harborgrain.example', '2018-04-12'),
  ('22222222-2222-2222-2222-222222222222', 'OAK', 'Harbor & Grain — Temescal', '510-555-0190', 'oak@harborgrain.example', '2022-09-01');

INSERT INTO warehouses (id, store_id, code, name) VALUES
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-1111-1111-1111-111111111111', 'SF-WH', 'Bayview warehouse'),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '22222222-2222-2222-2222-222222222222', 'OAK-WH', 'Emeryville overflow');

INSERT INTO employees (id, store_id, role, first_name, last_name, email, hired_on) VALUES
  ('e1111111-1111-1111-1111-111111111111', '11111111-1111-1111-1111-111111111111', 'manager', 'Mina', 'Cho', 'mina@harborgrain.example', '2018-04-12'),
  ('e2222222-2222-2222-2222-222222222222', '11111111-1111-1111-1111-111111111111', 'salesperson', 'Leo', 'Vargas', 'leo@harborgrain.example', '2020-02-03'),
  ('e3333333-3333-3333-3333-333333333333', '11111111-1111-1111-1111-111111111111', 'designer', 'Asha', 'Patel', 'asha@harborgrain.example', '2021-06-15'),
  ('e4444444-4444-4444-4444-444444444444', '22222222-2222-2222-2222-222222222222', 'driver', 'Noah', 'Kim', 'noah@harborgrain.example', '2023-01-09');

INSERT INTO customers (id, email, first_name, last_name, phone) VALUES
  ('c1111111-1111-1111-1111-111111111111', 'jordan@example.com', 'Jordan', 'Ellis', '415-555-2201'),
  ('c2222222-2222-2222-2222-222222222222', 'sam@example.com', 'Sam', 'Okoye', '510-555-7788');

INSERT INTO addresses (id, customer_id, kind, line1, city, region, postal_code, is_default) VALUES
  ('d1111111-1111-1111-1111-111111111111', 'c1111111-1111-1111-1111-111111111111', 'shipping', '88 Castro St', 'San Francisco', 'CA', '94114', true),
  ('d2222222-2222-2222-2222-222222222222', 'c2222222-2222-2222-2222-222222222222', 'shipping', '1401 40th St', 'Oakland', 'CA', '94601', true);

INSERT INTO addresses (store_id, kind, line1, city, region, postal_code) VALUES
  ('11111111-1111-1111-1111-111111111111', 'store', '432 Hayes St', 'San Francisco', 'CA', '94102');

INSERT INTO categories (id, parent_id, slug, name, sort_order) VALUES
  ('ca111111-1111-1111-1111-111111111111', NULL, 'seating', 'Seating', 1),
  ('ca222222-2222-2222-2222-222222222222', 'ca111111-1111-1111-1111-111111111111', 'sofas', 'Sofas', 1),
  ('ca333333-3333-3333-3333-333333333333', NULL, 'tables', 'Tables', 2),
  ('ca444444-4444-4444-4444-444444444444', 'ca333333-3333-3333-3333-333333333333', 'dining-tables', 'Dining tables', 1),
  ('ca555555-5555-5555-5555-555555555555', NULL, 'storage', 'Storage', 3),
  ('ca666666-6666-6666-6666-666666666666', NULL, 'lighting', 'Lighting', 4);

INSERT INTO brands (id, name, country) VALUES
  ('b1111111-1111-1111-1111-111111111111', 'Northline', 'US'),
  ('b2222222-2222-2222-2222-222222222222', 'Fjord Form', 'DK');

INSERT INTO materials (id, name, care_notes) VALUES
  ('81111111-1111-4111-8111-111111111111', 'White oak', 'Wipe with a dry cloth. Oil twice a year.'),
  ('82222222-2222-4222-8222-222222222222', 'Walnut', 'Avoid direct sun. Dust weekly.'),
  ('83333333-3333-4333-8333-333333333333', 'Performance linen', 'Spot clean. Professional clean yearly.'),
  ('84444444-4444-4444-8444-444444444444', 'Powder-coated steel', 'Damp cloth. Do not use abrasives.');

INSERT INTO finishes (id, name, hex_color) VALUES
  ('f1111111-1111-1111-1111-111111111111', 'Natural oak', '#C4A574'),
  ('f2222222-2222-2222-2222-222222222222', 'Smoked walnut', '#3E2A1F'),
  ('f3333333-3333-3333-3333-333333333333', 'Sand linen', '#E6DCC8'),
  ('f4444444-4444-4444-4444-444444444444', 'Ink linen', '#2C3338'),
  ('f5555555-5555-5555-5555-555555555555', 'Matte black', '#1A1A1A');

INSERT INTO products (id, category_id, brand_id, sku_prefix, name, description, status, width_cm, depth_cm, height_cm, weight_kg, assembly_req, lead_time_days) VALUES
  ('a1111111-1111-4111-8111-111111111111', 'ca222222-2222-2222-2222-222222222222', 'b1111111-1111-1111-1111-111111111111', 'SOFA-HAYES', 'Hayes 3-seat sofa', 'Loose-back sofa with kiln-dried oak legs.', 'active', 228.0, 96.0, 84.0, 48.50, false, 21),
  ('a2222222-2222-4222-8222-222222222222', 'ca444444-4444-4444-4444-444444444444', 'b2222222-2222-2222-2222-222222222222', 'TBL-FJORD', 'Fjord dining table', 'Solid wood top, seats six.', 'active', 180.0, 90.0, 75.0, 32.00, true, 28),
  ('a3333333-3333-4333-8333-333333333333', 'ca555555-5555-5555-5555-555555555555', 'b1111111-1111-1111-1111-111111111111', 'SHLF-BAY', 'Bay credenza', 'Low storage with two sliding doors.', 'active', 160.0, 45.0, 70.0, 41.20, true, 14),
  ('a4444444-4444-4444-8444-444444444444', 'ca666666-6666-6666-6666-666666666666', 'b2222222-2222-2222-2222-222222222222', 'LAMP-ARC', 'Arc floor lamp', 'Counterweighted arc lamp.', 'active', 40.0, 140.0, 190.0, 12.40, true, 7);

INSERT INTO product_materials (product_id, material_id, is_primary) VALUES
  ('a1111111-1111-4111-8111-111111111111', '83333333-3333-4333-8333-333333333333', true),
  ('a1111111-1111-4111-8111-111111111111', '81111111-1111-4111-8111-111111111111', false),
  ('a2222222-2222-4222-8222-222222222222', '81111111-1111-4111-8111-111111111111', true),
  ('a3333333-3333-4333-8333-333333333333', '82222222-2222-4222-8222-222222222222', true),
  ('a4444444-4444-4444-8444-444444444444', '84444444-4444-4444-8444-444444444444', true);

INSERT INTO product_variants (id, product_id, finish_id, sku, name, list_price, cost) VALUES
  ('b5111111-1111-4111-8111-111111111111', 'a1111111-1111-4111-8111-111111111111', 'f3333333-3333-3333-3333-333333333333', 'SOFA-HAYES-SAND', 'Hayes sofa / sand linen', 2890.00, 1420.00),
  ('b5111112-1111-4111-8111-111111111112', 'a1111111-1111-4111-8111-111111111111', 'f4444444-4444-4444-4444-444444444444', 'SOFA-HAYES-INK', 'Hayes sofa / ink linen', 2890.00, 1420.00),
  ('b5222222-2222-4222-8222-222222222222', 'a2222222-2222-4222-8222-222222222222', 'f1111111-1111-1111-1111-111111111111', 'TBL-FJORD-OAK', 'Fjord table / natural oak', 1640.00, 710.00),
  ('b5222223-2222-4222-8222-222222222223', 'a2222222-2222-4222-8222-222222222222', 'f2222222-2222-2222-2222-222222222222', 'TBL-FJORD-WAL', 'Fjord table / smoked walnut', 1890.00, 860.00),
  ('b5333333-3333-4333-8333-333333333333', 'a3333333-3333-4333-8333-333333333333', 'f2222222-2222-2222-2222-222222222222', 'SHLF-BAY-WAL', 'Bay credenza / smoked walnut', 2120.00, 980.00),
  ('b5444444-4444-4444-8444-444444444444', 'a4444444-4444-4444-8444-444444444444', 'f5555555-5555-5555-5555-555555555555', 'LAMP-ARC-BLK', 'Arc floor lamp / matte black', 420.00, 155.00);

INSERT INTO inventory_levels (warehouse_id, variant_id, on_hand, reserved, reorder_point) VALUES
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'b5111111-1111-4111-8111-111111111111', 4, 1, 2),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'b5111112-1111-4111-8111-111111111112', 2, 0, 2),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'b5222222-2222-4222-8222-222222222222', 6, 0, 3),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'b5222223-2222-4222-8222-222222222223', 3, 1, 2),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'b5333333-3333-4333-8333-333333333333', 5, 0, 2),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'b5444444-4444-4444-8444-444444444444', 12, 0, 4);

INSERT INTO stock_movements (warehouse_id, variant_id, movement_type, quantity, reference, employee_id) VALUES
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'b5111111-1111-4111-8111-111111111111', 'receipt', 4, 'opening', 'e1111111-1111-1111-1111-111111111111'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'b5444444-4444-4444-8444-444444444444', 'receipt', 12, 'opening', 'e1111111-1111-1111-1111-111111111111');

INSERT INTO suppliers (id, name, email, payment_terms) VALUES
  ('c5111111-1111-4111-8111-111111111111', 'Mendocino Millworks', 'orders@mendocinomill.example', 'net 30'),
  ('c5222222-2222-4222-8222-222222222222', 'Baltic Upholstery Co', 'hello@balticuph.example', 'net 45');

INSERT INTO supplier_contacts (supplier_id, name, email, role) VALUES
  ('c5111111-1111-4111-8111-111111111111', 'Greta Holm', 'greta@mendocinomill.example', 'account manager'),
  ('c5222222-2222-4222-8222-222222222222', 'Ivan Petrov', 'ivan@balticuph.example', 'sales');

INSERT INTO supplier_variants (supplier_id, variant_id, supplier_sku, unit_cost, min_order_qty, lead_time_days) VALUES
  ('c5222222-2222-4222-8222-222222222222', 'b5111111-1111-4111-8111-111111111111', 'HU-HAYES-SAND', 1420.00, 2, 21),
  ('c5222222-2222-4222-8222-222222222222', 'b5111112-1111-4111-8111-111111111112', 'HU-HAYES-INK', 1420.00, 2, 21),
  ('c5111111-1111-4111-8111-111111111111', 'b5222222-2222-4222-8222-222222222222', 'MM-FJORD-OAK', 710.00, 1, 28),
  ('c5111111-1111-4111-8111-111111111111', 'b5333333-3333-4333-8333-333333333333', 'MM-BAY-WAL', 980.00, 1, 14);

INSERT INTO purchase_orders (id, supplier_id, warehouse_id, employee_id, po_number, status, ordered_on, expected_on) VALUES
  ('d0111111-1111-4111-8111-111111111111', 'c5111111-1111-4111-8111-111111111111', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'e1111111-1111-1111-1111-111111111111', 'PO-1042', 'sent', '2026-09-20', '2026-10-18');

INSERT INTO purchase_order_lines (id, po_id, variant_id, quantity, unit_cost, received_qty) VALUES
  ('d0211111-1111-4111-8111-111111111111', 'd0111111-1111-4111-8111-111111111111', 'b5222222-2222-4222-8222-222222222222', 4, 710.00, 0);

INSERT INTO promotions (id, code, name, percent_off, starts_on, ends_on) VALUES
  ('d0311111-1111-4111-8111-111111111111', 'FALL10', 'Fall floor sample', 10.00, '2026-09-01', '2026-11-30');

INSERT INTO promotion_variants (promotion_id, variant_id) VALUES
  ('d0311111-1111-4111-8111-111111111111', 'b5444444-4444-4444-8444-444444444444');

INSERT INTO orders (id, order_number, customer_id, store_id, salesperson_id, ship_address_id, status, placed_at) VALUES
  ('0a111111-1111-4111-8111-111111111111', 'HG-24018', 'c1111111-1111-1111-1111-111111111111', '11111111-1111-1111-1111-111111111111', 'e2222222-2222-2222-2222-222222222222', 'd1111111-1111-1111-1111-111111111111', 'paid', '2026-10-02 16:40:00-07');

INSERT INTO order_lines (id, order_id, variant_id, warehouse_id, quantity, unit_price, discount) VALUES
  ('0b111111-1111-4111-8111-111111111111', '0a111111-1111-4111-8111-111111111111', 'b5111111-1111-4111-8111-111111111111', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 1, 2890.00, 0),
  ('0b111112-1111-4111-8111-111111111112', '0a111111-1111-4111-8111-111111111111', 'b5444444-4444-4444-8444-444444444444', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 1, 420.00, 42.00);

INSERT INTO payments (order_id, method, status, amount, provider_ref, paid_at) VALUES
  ('0a111111-1111-4111-8111-111111111111', 'card', 'captured', 3268.00, 'ch_demo_24018', '2026-10-02 16:41:00-07');

INSERT INTO shipments (id, order_id, warehouse_id, driver_id, status, carrier, scheduled_for) VALUES
  ('0c111111-1111-4111-8111-111111111111', '0a111111-1111-4111-8111-111111111111', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'e4444444-4444-4444-4444-444444444444', 'scheduled', 'in-house', '2026-10-11 10:00:00-07');

INSERT INTO shipment_lines (shipment_id, order_line_id, quantity) VALUES
  ('0c111111-1111-4111-8111-111111111111', '0b111111-1111-4111-8111-111111111111', 1),
  ('0c111111-1111-4111-8111-111111111111', '0b111112-1111-4111-8111-111111111112', 1);

INSERT INTO warranties (order_line_id, coverage_months, starts_on, ends_on) VALUES
  ('0b111111-1111-4111-8111-111111111111', 60, '2026-10-11', '2031-10-11');

INSERT INTO appointments (customer_id, store_id, employee_id, order_id, kind, starts_at, ends_at, notes) VALUES
  ('c2222222-2222-2222-2222-222222222222', '22222222-2222-2222-2222-222222222222', 'e3333333-3333-3333-3333-333333333333', NULL, 'design_consult', '2026-10-14 15:00:00-07', '2026-10-14 16:00:00-07', 'Dining room redo, seats 8.');

INSERT INTO reviews (product_id, customer_id, order_id, rating, title, body) VALUES
  ('a4444444-4444-4444-8444-444444444444', 'c1111111-1111-1111-1111-111111111111', '0a111111-1111-4111-8111-111111111111', 5, 'Perfect arc', 'Clears the sofa and the shade is even.');

COMMIT;
