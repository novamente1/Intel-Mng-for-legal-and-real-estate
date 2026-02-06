-- ============================================
-- Migration 006: ROI calculation engine for auction assets
-- Versioned, logged, linked to auction asset; audit all recalculations
-- ============================================

-- Current ROI state per asset (1:1). Auto-updated when any input changes.
CREATE TABLE IF NOT EXISTS auction_asset_roi (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    auction_asset_id UUID NOT NULL REFERENCES auction_assets(id) ON DELETE CASCADE,
    UNIQUE(auction_asset_id),

    -- Inputs (all in cents for precision)
    acquisition_price_cents BIGINT NOT NULL DEFAULT 0,
    taxes_itbi_cents BIGINT NOT NULL DEFAULT 0,
    legal_costs_cents BIGINT NOT NULL DEFAULT 0,
    renovation_estimate_cents BIGINT NOT NULL DEFAULT 0,
    expected_resale_value_cents BIGINT NOT NULL DEFAULT 0,
    expected_resale_date DATE,

    -- Outputs (computed)
    total_cost_cents BIGINT NOT NULL DEFAULT 0,
    net_profit_cents BIGINT NOT NULL DEFAULT 0,
    roi_percentage DECIMAL(10, 2) NOT NULL DEFAULT 0,
    break_even_date DATE,

    -- Versioning
    version_number INTEGER NOT NULL DEFAULT 1,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,

    CONSTRAINT non_negative_inputs CHECK (
        acquisition_price_cents >= 0 AND taxes_itbi_cents >= 0 AND legal_costs_cents >= 0
        AND renovation_estimate_cents >= 0 AND expected_resale_value_cents >= 0
    )
);

CREATE INDEX idx_auction_asset_roi_tenant_id ON auction_asset_roi(tenant_id);
CREATE UNIQUE INDEX idx_auction_asset_roi_asset_id ON auction_asset_roi(auction_asset_id);

-- Versioned history: every recalculation logged
CREATE TABLE IF NOT EXISTS roi_calculation_versions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    auction_asset_id UUID NOT NULL REFERENCES auction_assets(id) ON DELETE CASCADE,

    version_number INTEGER NOT NULL,
    -- Snapshot of inputs at calculation time
    inputs_snapshot JSONB NOT NULL,
    -- Outputs
    total_cost_cents BIGINT NOT NULL,
    net_profit_cents BIGINT NOT NULL,
    roi_percentage DECIMAL(10, 2) NOT NULL,
    break_even_date DATE,

    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

CREATE INDEX idx_roi_versions_tenant_id ON roi_calculation_versions(tenant_id);
CREATE INDEX idx_roi_versions_asset_id ON roi_calculation_versions(auction_asset_id);
CREATE INDEX idx_roi_versions_created_at ON roi_calculation_versions(auction_asset_id, created_at DESC);

COMMENT ON TABLE auction_asset_roi IS 'Current ROI state per auction asset; auto-updated when inputs change';
COMMENT ON TABLE roi_calculation_versions IS 'Versioned ROI calculations; one row per recalculation for audit';
