-- ============================================
-- Migration 015: Unified Dashboards Module
-- KPIs, real-time updates, role-based visibility
-- ============================================

-- Dashboard Configurations table (defines dashboards per role)
CREATE TABLE IF NOT EXISTS dashboard_configs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Tenant isolation (mandatory)
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    
    -- Dashboard identification
    dashboard_name VARCHAR(255) NOT NULL,
    dashboard_type VARCHAR(100) NOT NULL, -- 'EXECUTIVE', 'OPERATIONAL', 'FINANCIAL', 'LEGAL', 'CUSTOM'
    
    -- Role-based visibility
    visible_to_roles TEXT[] NOT NULL, -- Roles that can view this dashboard
    visible_to_permissions TEXT[], -- Permissions required to view
    
    -- Dashboard layout
    layout_config JSONB DEFAULT '{}'::jsonb, -- Widget layout configuration
    kpi_widgets JSONB DEFAULT '[]'::jsonb, -- KPI widgets to display
    
    -- Refresh settings
    auto_refresh_interval_seconds INTEGER DEFAULT 60, -- Auto-refresh interval
    cache_ttl_seconds INTEGER DEFAULT 300, -- Cache TTL for KPI data
    
    -- Status
    is_active BOOLEAN DEFAULT true,
    is_default BOOLEAN DEFAULT false, -- Default dashboard for role
    
    -- Ownership
    created_by UUID REFERENCES users(id),
    updated_by UUID REFERENCES users(id),
    
    -- Metadata
    metadata JSONB DEFAULT '{}'::jsonb,
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    deleted_at TIMESTAMP WITH TIME ZONE,
    deleted_by UUID REFERENCES users(id),
    
    -- Constraints
    CONSTRAINT valid_refresh_interval CHECK (auto_refresh_interval_seconds >= 10),
    CONSTRAINT valid_cache_ttl CHECK (cache_ttl_seconds >= 0)
);

CREATE INDEX idx_dashboard_configs_tenant_id ON dashboard_configs(tenant_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_dashboard_configs_type ON dashboard_configs(tenant_id, dashboard_type) WHERE deleted_at IS NULL;
CREATE INDEX idx_dashboard_configs_roles ON dashboard_configs USING GIN(visible_to_roles) WHERE deleted_at IS NULL;
CREATE INDEX idx_dashboard_configs_active ON dashboard_configs(tenant_id, is_active) WHERE deleted_at IS NULL AND is_active = true;

COMMENT ON TABLE dashboard_configs IS 'Dashboard configurations with role-based visibility';
COMMENT ON COLUMN dashboard_configs.visible_to_roles IS 'Roles that can view this dashboard - enforced at API level';

-- Dashboard KPI Cache table (caches calculated KPI values)
CREATE TABLE IF NOT EXISTS dashboard_kpi_cache (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Tenant isolation (mandatory)
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    
    -- KPI identification
    kpi_type VARCHAR(100) NOT NULL, -- 'CASH_FLOW', 'DEADLINES', 'ROI', 'RISK_EXPOSURE', 'CUSTOM'
    kpi_name VARCHAR(255) NOT NULL,
    
    -- KPI value
    kpi_value JSONB NOT NULL, -- KPI data (structured, no raw SQL)
    kpi_metadata JSONB DEFAULT '{}'::jsonb, -- Additional metadata
    
    -- Time period
    period_type VARCHAR(50) NOT NULL, -- 'REALTIME', 'DAILY', 'WEEKLY', 'MONTHLY', 'YEARLY'
    period_start DATE,
    period_end DATE,
    
    -- Cache management
    calculated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    cache_version INTEGER DEFAULT 1, -- Version for cache invalidation
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    
    -- Constraints
    CONSTRAINT valid_period_type CHECK (
        period_type IN ('REALTIME', 'DAILY', 'WEEKLY', 'MONTHLY', 'YEARLY', 'CUSTOM')
    ),
    CONSTRAINT unique_kpi_cache UNIQUE(tenant_id, kpi_type, kpi_name, period_type, period_start, period_end)
);

CREATE INDEX idx_dashboard_kpi_cache_tenant_id ON dashboard_kpi_cache(tenant_id);
CREATE INDEX idx_dashboard_kpi_cache_type ON dashboard_kpi_cache(tenant_id, kpi_type);
CREATE INDEX idx_dashboard_kpi_cache_expires ON dashboard_kpi_cache(expires_at) WHERE expires_at > CURRENT_TIMESTAMP;
CREATE INDEX idx_dashboard_kpi_cache_period ON dashboard_kpi_cache(tenant_id, period_type, period_start, period_end);

COMMENT ON TABLE dashboard_kpi_cache IS 'Cached KPI values - no raw SQL exposure, structured data only';
COMMENT ON COLUMN dashboard_kpi_cache.kpi_value IS 'Structured KPI data (JSONB) - no raw SQL queries exposed';

-- Dashboard User Preferences table (user-specific dashboard settings)
CREATE TABLE IF NOT EXISTS dashboard_user_preferences (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Tenant isolation (mandatory)
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    
    -- User reference
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    -- Dashboard preferences
    default_dashboard_id UUID REFERENCES dashboard_configs(id) ON DELETE SET NULL,
    favorite_dashboards UUID[], -- Favorite dashboard IDs
    hidden_dashboards UUID[], -- Hidden dashboard IDs
    
    -- Display preferences
    refresh_interval_seconds INTEGER DEFAULT 60,
    show_notifications BOOLEAN DEFAULT true,
    
    -- Layout preferences
    custom_layout JSONB DEFAULT '{}'::jsonb,
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    
    -- Constraints
    CONSTRAINT unique_user_preferences UNIQUE(tenant_id, user_id)
);

CREATE INDEX idx_dashboard_user_preferences_tenant_id ON dashboard_user_preferences(tenant_id);
CREATE INDEX idx_dashboard_user_preferences_user_id ON dashboard_user_preferences(user_id);

COMMENT ON TABLE dashboard_user_preferences IS 'User-specific dashboard preferences and settings';

-- Triggers for updated_at
CREATE TRIGGER update_dashboard_configs_updated_at 
    BEFORE UPDATE ON dashboard_configs
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_dashboard_kpi_cache_updated_at 
    BEFORE UPDATE ON dashboard_kpi_cache
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_dashboard_user_preferences_updated_at 
    BEFORE UPDATE ON dashboard_user_preferences
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
