-- ============================================
-- Migration 005: Auction Engine (MPGA workflow)
-- Tenant-scoped auction assets with strict stage machine
-- ============================================

-- Valid stages: F0 -> F1 -> ... -> F9 (no skip)
-- Due diligence: occupancy, debts, legal_risks, zoning
-- Risk score 0-100; HIGH risk disables bidding at API level

CREATE TABLE IF NOT EXISTS auction_assets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Tenant isolation (mandatory)
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,

    -- MPGA stage (F0 through F9 only; enforced in API)
    current_stage VARCHAR(2) NOT NULL DEFAULT 'F0',
    CONSTRAINT valid_auction_stage CHECK (current_stage IN ('F0','F1','F2','F3','F4','F5','F6','F7','F8','F9')),

    -- Linked documents (e.g. deeds, DD reports)
    linked_document_ids UUID[] NOT NULL DEFAULT '{}',

    -- Due diligence checklist (API enforces structure)
    -- Each key: occupancy | debts | legal_risks | zoning
    -- Value: { "status": "ok"|"risk"|"pending", "notes": "..." }
    due_diligence_checklist JSONB NOT NULL DEFAULT '{
        "occupancy": {"status": "pending", "notes": null},
        "debts": {"status": "pending", "notes": null},
        "legal_risks": {"status": "pending", "notes": null},
        "zoning": {"status": "pending", "notes": null}
    }'::jsonb,

    -- Risk score 0-100 (computed from checklist; API recalc on checklist update)
    risk_score INTEGER NOT NULL DEFAULT 0,
    CONSTRAINT valid_risk_score CHECK (risk_score >= 0 AND risk_score <= 100),

    -- Optional asset identification
    asset_reference VARCHAR(255),
    title VARCHAR(500),

    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

CREATE INDEX idx_auction_assets_tenant_id ON auction_assets(tenant_id);
CREATE INDEX idx_auction_assets_current_stage ON auction_assets(tenant_id, current_stage);
CREATE INDEX idx_auction_assets_risk_score ON auction_assets(tenant_id, risk_score);
CREATE INDEX idx_auction_assets_created_at ON auction_assets(created_at);

COMMENT ON TABLE auction_assets IS 'Auction assets with MPGA workflow (F0-F9); tenant-scoped; bidding disabled when risk HIGH';
COMMENT ON COLUMN auction_assets.current_stage IS 'MPGA stage; transitions F0->F1->...->F9 only (no skip)';
COMMENT ON COLUMN auction_assets.due_diligence_checklist IS 'occupancy, debts, legal_risks, zoning; each status ok|risk|pending';
COMMENT ON COLUMN auction_assets.risk_score IS '0-100; HIGH (e.g. >=70) disables bidding at API';

-- Bids table (tenant-scoped; bidding blocked at API when asset risk is HIGH)
CREATE TABLE IF NOT EXISTS auction_bids (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    auction_asset_id UUID NOT NULL REFERENCES auction_assets(id) ON DELETE CASCADE,
    bidder_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    amount_cents BIGINT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT positive_bid CHECK (amount_cents > 0)
);

CREATE INDEX idx_auction_bids_tenant_id ON auction_bids(tenant_id);
CREATE INDEX idx_auction_bids_asset_id ON auction_bids(auction_asset_id);
