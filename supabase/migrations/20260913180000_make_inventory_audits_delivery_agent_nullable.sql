-- Migration: Make delivery_agent_id nullable in inventory_audits to allow DC-level inventory audits
-- and ensure notes column exists.

ALTER TABLE IF EXISTS inventory_audits 
    ALTER COLUMN delivery_agent_id DROP NOT NULL;

ALTER TABLE IF EXISTS inventory_audits 
    ADD COLUMN IF NOT EXISTS notes TEXT;
