-- Migration 000016: Fix Dispatch Delivery Fees
-- Restores correct calculated Mitra delivery_fee for orders where dispatch logic previously overwrote delivery_fee with flat 15000

UPDATE orders
SET delivery_fee = CASE 
    -- Zona 1: Driver Fee 10.500 -> Mitra Fee 15.000
    WHEN driver_fee = 10500 THEN 15000
    -- Zona 2: Driver Fee 17.500 -> Mitra Fee 25.000
    WHEN driver_fee = 17500 THEN 25000
    -- Zona 3: Driver Fee 24.500 -> Mitra Fee 35.000
    WHEN driver_fee = 24500 THEN 35000
    -- Non-Zona / KM Rate: Driver Fee (1750/km) -> Mitra Fee (2000/km)
    WHEN driver_fee > 0 AND (delivery_fee = 15000 OR delivery_fee = 0) THEN ROUND(driver_fee / 1750.0 * 2000.0)
    ELSE delivery_fee
END
WHERE driver_fee > 0 AND (delivery_fee = 15000 OR delivery_fee = 0 OR (driver_fee > delivery_fee));
