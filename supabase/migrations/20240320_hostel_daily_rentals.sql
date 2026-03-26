-- ============================================
-- Migration: Hostel & Daily Rentals Module
-- Description: Adds support for daily bookings (hostels, apartments, guest houses)
-- ============================================

-- ============================================
-- 1. FIX ORGANIZATIONS TABLE
-- ============================================

-- Add missing columns to organizations table
ALTER TABLE organizations ADD COLUMN IF NOT EXISTS owner_id UUID REFERENCES profiles(id) ON DELETE SET NULL;
ALTER TABLE organizations ADD COLUMN IF NOT EXISTS type TEXT DEFAULT 'salon';

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_organizations_owner_id ON organizations(owner_id);

-- ============================================
-- 2. ADD CATEGORIES AND SPECIALTIES
-- ============================================

-- Insert the main category for Hostels & Housing
INSERT INTO categories (id, name, icon, created_at)
VALUES (
  gen_random_uuid(),
  'Хостелы и Жилье',
  'hotel',
  NOW()
) ON CONFLICT (name) DO NOTHING;

-- Get the category ID for linking specialties
DO $$
DECLARE
    category_uuid UUID;
BEGIN
    SELECT id INTO category_uuid FROM categories WHERE name = 'Хостелы и Жилье' LIMIT 1;

    IF category_uuid IS NOT NULL THEN
        -- Insert specialties linked to this category
        INSERT INTO specialties (id, name, category_id, created_at)
        VALUES
            (gen_random_uuid(), 'Владелец хостела', category_uuid, NOW()),
            (gen_random_uuid(), 'Квартира посуточно', category_uuid, NOW()),
            (gen_random_uuid(), 'Гостевой дом', category_uuid, NOW())
        ON CONFLICT (name, category_id) DO NOTHING;
    END IF;
END $$;

-- ============================================
-- 3. ADD BOOKING_TYPE AND CAPACITY TO SERVICES
-- ============================================

-- Add booking_type column (default: 'time_slot', can be 'daily')
ALTER TABLE services ADD COLUMN IF NOT EXISTS booking_type TEXT DEFAULT 'time_slot' CHECK (booking_type IN ('time_slot', 'daily'));

-- Add capacity column (number of beds/spots available)
ALTER TABLE services ADD COLUMN IF NOT EXISTS capacity INTEGER DEFAULT 1 CHECK (capacity > 0);

-- Create index for filtering daily booking services
CREATE INDEX IF NOT EXISTS idx_services_booking_type ON services(booking_type);

-- ============================================
-- 4. ADD BOOKING_TYPE AND CAPACITY TO BOOKINGS
-- ============================================

-- Add booking_type to bookings
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS booking_type TEXT DEFAULT 'time_slot' CHECK (booking_type IN ('time_slot', 'daily'));

-- Add capacity to bookings (number of guests/spots booked)
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS capacity INTEGER DEFAULT 1 CHECK (capacity > 0);

-- Create index for filtering daily bookings
CREATE INDEX IF NOT EXISTS idx_bookings_booking_type ON bookings(booking_type);
CREATE INDEX IF NOT EXISTS idx_bookings_service_id_start_time ON bookings(service_id, start_time);

-- ============================================
-- 5. CREATE RPC FUNCTION: count_daily_bookings
-- ============================================

CREATE OR REPLACE FUNCTION count_daily_bookings(
    p_service_id UUID,
    p_start_date TIMESTAMPTZ,
    p_end_date TIMESTAMPTZ
)
RETURNS TABLE(booking_date DATE, booked_count BIGINT)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        d.date AS booking_date,
        COALESCE(SUM(b.capacity), 0)::BIGINT AS booked_count
    FROM
        generate_series(
            DATE(p_start_date),
            DATE(p_end_date),
            INTERVAL '1 day'
        ) AS d(date)
    LEFT JOIN bookings b
        ON b.service_id = p_service_id
        AND b.booking_type = 'daily'
        AND b.status != 'cancelled'
        AND DATE(b.start_time) <= d.date
        AND DATE(b.end_time) > d.date
    GROUP BY d.date
    ORDER BY d.date;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION count_daily_bookings(UUID, TIMESTAMPTZ, TIMESTAMPTZ) TO authenticated;

-- ============================================
-- 6. ADD ICAL_URL TO SERVICES (for sync configuration)
-- ============================================

ALTER TABLE services ADD COLUMN IF NOT EXISTS ical_url TEXT;

-- ============================================
-- 7. ADD ORGANIZATION_ID TO PROFILES (if not exists)
-- ============================================

ALTER TABLE profiles ADD COLUMN IF NOT EXISTS organization_id UUID REFERENCES organizations(id) ON DELETE SET NULL;

-- ============================================
-- 8. HELPER FUNCTION: Get available beds for a date range
-- ============================================

CREATE OR REPLACE FUNCTION get_available_beds(
    p_service_id UUID,
    p_check_in DATE,
    p_check_out DATE
)
RETURNS INTEGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_total_capacity INTEGER;
    v_max_occupied INTEGER;
BEGIN
    -- Get total capacity of the service
    SELECT capacity INTO v_total_capacity
    FROM services
    WHERE id = p_service_id;

    IF v_total_capacity IS NULL THEN
        v_total_capacity := 1;
    END IF;

    -- Find the maximum number of occupied beds on any single day in the range
    SELECT COALESCE(MAX(booked), 0) INTO v_max_occupied
    FROM (
        SELECT SUM(b.capacity) AS booked
        FROM bookings b
        WHERE b.service_id = p_service_id
          AND b.booking_type = 'daily'
          AND b.status != 'cancelled'
          AND DATE(b.start_time) < p_check_out
          AND DATE(b.end_time) > p_check_in
        GROUP BY DATE(b.start_time)
    ) AS daily_occupancy;

    RETURN v_total_capacity - v_max_occupied;
END;
$$;

GRANT EXECUTE ON FUNCTION get_available_beds(UUID, DATE, DATE) TO authenticated;

-- ============================================
-- 9. TRIGGER: Update profiles.organization_id when creating organization
-- ============================================

CREATE OR REPLACE FUNCTION update_owner_organization()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.owner_id IS NOT NULL THEN
        UPDATE profiles
        SET organization_id = NEW.id
        WHERE id = NEW.owner_id;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_update_owner_organization ON organizations;
CREATE TRIGGER trg_update_owner_organization
    AFTER INSERT OR UPDATE ON organizations
    FOR EACH ROW
    EXECUTE FUNCTION update_owner_organization();

-- ============================================
-- 10. COMMENTS FOR DOCUMENTATION
-- ============================================

COMMENT ON COLUMN services.booking_type IS 'Type of booking: time_slot (default) for appointments, daily for hostels/rentals';
COMMENT ON COLUMN services.capacity IS 'Number of beds/spots available for daily bookings';
COMMENT ON COLUMN bookings.booking_type IS 'Type of booking: time_slot (default) for appointments, daily for hostels/rentals';
COMMENT ON COLUMN bookings.capacity IS 'Number of guests/spots booked (for daily bookings)';
COMMENT ON FUNCTION count_daily_bookings IS 'Returns daily booking counts for a service within a date range. Used for calendar occupancy display.';
COMMENT ON FUNCTION get_available_beds IS 'Returns the minimum available beds for a date range. Used for availability checking.';
