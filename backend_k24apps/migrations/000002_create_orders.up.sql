-- Migration 000002: Orders Table
-- Depends on: users (000001)

-- Orders table (supports both single orders and bulk dispatch batches)
CREATE TABLE IF NOT EXISTS orders (
    id SERIAL PRIMARY KEY,
    order_number VARCHAR(50) UNIQUE NOT NULL,
    dispatch_id VARCHAR(50),                            -- Groups sub-orders from same bulk batch (e.g. ORD-000001)
    mitra_id INTEGER REFERENCES users(id) ON DELETE SET NULL, -- Mitra who created the order
    driver_id INTEGER REFERENCES users(id) ON DELETE SET NULL, -- Driver assigned to deliver
    status VARCHAR(50) NOT NULL,                        -- 'PICKING_UP', 'DELIVERING', 'COMPLETED', 'CANCELLED'
    pharmacy_name VARCHAR(255) NOT NULL,
    pharmacy_address TEXT NOT NULL,
    delivery_address TEXT NOT NULL,
    customer_name VARCHAR(255) NOT NULL,
    customer_phone VARCHAR(50) NOT NULL,
    medicine_summary TEXT NOT NULL,                     -- Encodes armada, rate_type, and invoice numbers
    delivery_fee NUMERIC(10,2) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP
);

-- Performance indexes for orders
CREATE INDEX IF NOT EXISTS idx_orders_driver_id ON orders(driver_id);
CREATE INDEX IF NOT EXISTS idx_orders_driver_status ON orders(driver_id, status);
CREATE INDEX IF NOT EXISTS idx_orders_mitra_id ON orders(mitra_id);
CREATE INDEX IF NOT EXISTS idx_orders_dispatch_id ON orders(dispatch_id);
