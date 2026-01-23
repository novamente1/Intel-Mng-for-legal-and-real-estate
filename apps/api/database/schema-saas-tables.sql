-- ============================================
-- SAAS MULTI-TENANT AND AUDIT TRAIL TABLES
-- Schema for Milestone 1 Compliance
-- ============================================

-- enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto"; -- for cryptographic functions (SHA-256)

-- ============================================
-- SAAS_TENANTS TABLE
-- Multi-tenant isolation table
-- ============================================
CREATE TABLE saas_tenants (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- tenant identification
    tenant_id VARCHAR(100) UNIQUE NOT NULL, -- used for data isolation
    name VARCHAR(255) NOT NULL,
    domain VARCHAR(255) UNIQUE, -- custom domain (optional)
    subdomain VARCHAR(100) UNIQUE, -- tenant subdomain
    
    -- status and configuration
    status VARCHAR(50) NOT NULL DEFAULT 'active',
    tier VARCHAR(50) DEFAULT 'standard',
    max_users INTEGER DEFAULT 10,
    max_storage_gb INTEGER DEFAULT 10,
    
    -- isolation settings
    database_schema VARCHAR(100), -- dedicated schema (when isolation_level = 'physical')
    isolation_level VARCHAR(50) DEFAULT 'logical', -- 'logical' or 'physical'
    
    -- Metadata
    metadata JSONB DEFAULT '{}'::jsonb, -- Configurações específicas do tenant
    settings JSONB DEFAULT '{}'::jsonb, -- Preferências e configurações
    
    -- Compliance e Auditoria
    data_residency VARCHAR(100), -- Região de residência dos dados (GDPR)
    compliance_flags TEXT[], -- ['gdpr', 'hipaa', 'sox', 'lgpd']
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    activated_at TIMESTAMP WITH TIME ZONE,
    suspended_at TIMESTAMP WITH TIME ZONE,
    deleted_at TIMESTAMP WITH TIME ZONE,
    deleted_by UUID REFERENCES users(id),
    
    -- Constraints
    CONSTRAINT valid_status CHECK (status IN ('active', 'suspended', 'inactive', 'trial', 'expired')),
    CONSTRAINT valid_tier CHECK (tier IN ('trial', 'standard', 'premium', 'enterprise')),
    CONSTRAINT valid_isolation_level CHECK (isolation_level IN ('logical', 'physical')),
    CONSTRAINT tenant_id_format CHECK (tenant_id ~ '^[a-z0-9_-]+$')
);

-- Índices para performance e isolamento
CREATE INDEX idx_saas_tenants_tenant_id ON saas_tenants(tenant_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_saas_tenants_status ON saas_tenants(status) WHERE deleted_at IS NULL;
CREATE INDEX idx_saas_tenants_domain ON saas_tenants(domain) WHERE deleted_at IS NULL;
CREATE INDEX idx_saas_tenants_subdomain ON saas_tenants(subdomain) WHERE deleted_at IS NULL;
CREATE INDEX idx_saas_tenants_created_at ON saas_tenants(created_at);

-- Comentários para documentação
COMMENT ON TABLE saas_tenants IS 'Tabela de tenants para isolamento multi-tenant (SaaS)';
COMMENT ON COLUMN saas_tenants.tenant_id IS 'Identificador único do tenant - usado para isolamento de dados em todas as tabelas';
COMMENT ON COLUMN saas_tenants.isolation_level IS 'Nível de isolamento: logical (shared DB com tenant_id) ou physical (dedicated DB)';
COMMENT ON COLUMN saas_tenants.database_schema IS 'Schema PostgreSQL dedicado para isolamento físico (quando isolation_level = physical)';

-- ============================================
-- SYSTEM_AUDIT_TRAIL TABLE
-- Audit trail with hash chain
-- ============================================
CREATE TABLE system_audit_trail (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- hash chain
    prev_hash VARCHAR(64), -- hash of previous record (NULL for first)
    curr_hash VARCHAR(64) NOT NULL, -- hash of current record (SHA-256)
    hash_chain_index BIGSERIAL, -- sequential index in chain
    
    -- multi-tenant isolation
    tenant_id VARCHAR(100) REFERENCES saas_tenants(tenant_id) ON DELETE CASCADE,
    
    -- event identification
    event_type VARCHAR(100) NOT NULL,
    event_category VARCHAR(50) NOT NULL,
    action VARCHAR(50) NOT NULL,
    severity VARCHAR(20) DEFAULT 'info',
    
    -- who executed
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    user_email VARCHAR(255), -- denormalized for historical accuracy
    user_role VARCHAR(100),
    session_id VARCHAR(100),
    
    -- affected resource
    resource_type VARCHAR(100),
    resource_id UUID,
    resource_identifier VARCHAR(500),
    
    -- event details
    description TEXT NOT NULL,
    details JSONB DEFAULT '{}'::jsonb,
    before_state JSONB, -- previous state (for updates/deletes)
    after_state JSONB, -- new state (for creates/updates)
    
    -- request context
    ip_address INET,
    user_agent TEXT,
    request_id VARCHAR(100),
    request_method VARCHAR(10),
    request_path VARCHAR(500),
    
    -- result
    success BOOLEAN DEFAULT true,
    error_code VARCHAR(50),
    error_message TEXT,
    http_status_code INTEGER,
    
    -- compliance
    compliance_flags TEXT[],
    retention_category VARCHAR(50),
    legal_hold BOOLEAN DEFAULT false,
    
    -- timestamp (immutable)
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    
    -- Constraints
    CONSTRAINT valid_event_category CHECK (
        event_category IN ('authentication', 'authorization', 'data_access', 'data_modification', 'system', 'compliance', 'security')
    ),
    CONSTRAINT valid_action CHECK (
        action IN ('create', 'read', 'update', 'delete', 'login', 'logout', 'grant', 'revoke', 'export', 'import', 'approve', 'reject', 'access')
    ),
    CONSTRAINT valid_severity CHECK (
        severity IN ('debug', 'info', 'warning', 'error', 'critical')
    ),
    CONSTRAINT curr_hash_format CHECK (curr_hash ~ '^[a-f0-9]{64}$'), -- SHA-256 hex
    CONSTRAINT prev_hash_format CHECK (prev_hash IS NULL OR prev_hash ~ '^[a-f0-9]{64}$')
);

-- Índices para performance
CREATE INDEX idx_audit_trail_tenant_id ON system_audit_trail(tenant_id);
CREATE INDEX idx_audit_trail_hash_chain_index ON system_audit_trail(hash_chain_index DESC);
CREATE INDEX idx_audit_trail_curr_hash ON system_audit_trail(curr_hash);
CREATE INDEX idx_audit_trail_prev_hash ON system_audit_trail(prev_hash) WHERE prev_hash IS NOT NULL;
CREATE INDEX idx_audit_trail_user_id ON system_audit_trail(user_id);
CREATE INDEX idx_audit_trail_event_type ON system_audit_trail(event_type);
CREATE INDEX idx_audit_trail_event_category ON system_audit_trail(event_category);
CREATE INDEX idx_audit_trail_resource ON system_audit_trail(resource_type, resource_id);
CREATE INDEX idx_audit_trail_created_at ON system_audit_trail(created_at DESC);
CREATE INDEX idx_audit_trail_request_id ON system_audit_trail(request_id) WHERE request_id IS NOT NULL;
CREATE INDEX idx_audit_trail_session_id ON system_audit_trail(session_id) WHERE session_id IS NOT NULL;
CREATE INDEX idx_audit_trail_compliance ON system_audit_trail(compliance_flags) WHERE compliance_flags IS NOT NULL;
CREATE INDEX idx_audit_trail_legal_hold ON system_audit_trail(legal_hold) WHERE legal_hold = true;

-- Índice composto para consultas comuns
CREATE INDEX idx_audit_trail_tenant_time ON system_audit_trail(tenant_id, created_at DESC);
CREATE INDEX idx_audit_trail_user_time ON system_audit_trail(user_id, created_at DESC);
CREATE INDEX idx_audit_trail_resource_time ON system_audit_trail(resource_type, resource_id, created_at DESC);

-- Índice GIN para JSONB
CREATE INDEX idx_audit_trail_details ON system_audit_trail USING GIN(details);
CREATE INDEX idx_audit_trail_before_state ON system_audit_trail USING GIN(before_state) WHERE before_state IS NOT NULL;
CREATE INDEX idx_audit_trail_after_state ON system_audit_trail USING GIN(after_state) WHERE after_state IS NOT NULL;

-- ============================================
-- FUNCTIONS FOR HASH CHAIN
-- ============================================

-- function that calculates SHA-256 hash of the record
CREATE OR REPLACE FUNCTION calculate_audit_hash(
    p_id UUID,
    p_prev_hash VARCHAR(64),
    p_tenant_id VARCHAR(100),
    p_event_type VARCHAR(100),
    p_action VARCHAR(50),
    p_user_id UUID,
    p_resource_type VARCHAR(100),
    p_resource_id UUID,
    p_description TEXT,
    p_details JSONB,
    p_created_at TIMESTAMP WITH TIME ZONE
) RETURNS VARCHAR(64) AS $$
DECLARE
    hash_input TEXT;
    calculated_hash VARCHAR(64);
BEGIN
    -- concatenate relevant fields to form the hash
    hash_input := COALESCE(p_id::TEXT, '') || '|' ||
                  COALESCE(p_prev_hash, '') || '|' ||
                  COALESCE(p_tenant_id, '') || '|' ||
                  COALESCE(p_event_type, '') || '|' ||
                  COALESCE(p_action, '') || '|' ||
                  COALESCE(p_user_id::TEXT, '') || '|' ||
                  COALESCE(p_resource_type, '') || '|' ||
                  COALESCE(p_resource_id::TEXT, '') || '|' ||
                  COALESCE(p_description, '') || '|' ||
                  COALESCE(p_details::TEXT, '') || '|' ||
                  COALESCE(p_created_at::TEXT, '');
    
    -- calculate SHA-256
    calculated_hash := encode(digest(hash_input, 'sha256'), 'hex');
    
    RETURN calculated_hash;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- trigger that calculates hash before insert
CREATE OR REPLACE FUNCTION set_audit_trail_hash()
RETURNS TRIGGER AS $$
DECLARE
    prev_hash_value VARCHAR(64);
    hash_index BIGINT;
BEGIN
    -- get hash from last record of same tenant
    SELECT curr_hash, hash_chain_index INTO prev_hash_value, hash_index
    FROM system_audit_trail
    WHERE tenant_id = COALESCE(NEW.tenant_id, 'system')
    ORDER BY hash_chain_index DESC
    LIMIT 1;
    
    -- set prev_hash and increment index
    NEW.prev_hash := prev_hash_value;
    NEW.hash_chain_index := COALESCE(hash_index, 0) + 1;
    
    -- calculate hash of current record
    NEW.curr_hash := calculate_audit_hash(
        NEW.id,
        NEW.prev_hash,
        NEW.tenant_id,
        NEW.event_type,
        NEW.action,
        NEW.user_id,
        NEW.resource_type,
        NEW.resource_id,
        NEW.description,
        NEW.details,
        NEW.created_at
    );
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger BEFORE INSERT
CREATE TRIGGER set_audit_trail_hash_trigger
    BEFORE INSERT ON system_audit_trail
    FOR EACH ROW
    EXECUTE FUNCTION set_audit_trail_hash();

-- function that prevents modifications (ensures immutability)
CREATE OR REPLACE FUNCTION prevent_audit_trail_modification()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'system_audit_trail is immutable. Updates and deletes are not allowed.';
END;
$$ LANGUAGE plpgsql;

-- triggers that prevent UPDATE and DELETE
CREATE TRIGGER prevent_audit_trail_update
    BEFORE UPDATE ON system_audit_trail
    FOR EACH ROW
    EXECUTE FUNCTION prevent_audit_trail_modification();

CREATE TRIGGER prevent_audit_trail_delete
    BEFORE DELETE ON system_audit_trail
    FOR EACH ROW
    EXECUTE FUNCTION prevent_audit_trail_modification();

-- function to validate hash chain integrity
CREATE OR REPLACE FUNCTION validate_audit_hash_chain(p_tenant_id VARCHAR(100) DEFAULT NULL)
RETURNS TABLE(
    hash_chain_index BIGINT,
    curr_hash VARCHAR(64),
    prev_hash VARCHAR(64),
    calculated_hash VARCHAR(64),
    is_valid BOOLEAN,
    created_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    WITH ordered_trail AS (
        SELECT 
            hash_chain_index,
            id,
            prev_hash,
            curr_hash,
            tenant_id,
            event_type,
            action,
            user_id,
            resource_type,
            resource_id,
            description,
            details,
            created_at
        FROM system_audit_trail
        WHERE (p_tenant_id IS NULL OR tenant_id = p_tenant_id)
        ORDER BY hash_chain_index
    ),
    validation AS (
        SELECT 
            ot.hash_chain_index,
            ot.curr_hash,
            ot.prev_hash,
            calculate_audit_hash(
                ot.id,
                ot.prev_hash,
                ot.tenant_id,
                ot.event_type,
                ot.action,
                ot.user_id,
                ot.resource_type,
                ot.resource_id,
                ot.description,
                ot.details,
                ot.created_at
            ) AS calculated_hash,
            ot.created_at
        FROM ordered_trail ot
    )
    SELECT 
        v.hash_chain_index,
        v.curr_hash,
        v.prev_hash,
        v.calculated_hash,
        (v.curr_hash = v.calculated_hash) AS is_valid,
        v.created_at
    FROM validation v;
END;
$$ LANGUAGE plpgsql;

-- Comentários para documentação
COMMENT ON TABLE system_audit_trail IS 'Immutable audit trail with hash chain';
COMMENT ON COLUMN system_audit_trail.prev_hash IS 'SHA-256 hash of previous record (NULL for first)';
COMMENT ON COLUMN system_audit_trail.curr_hash IS 'SHA-256 hash of current record, calculated automatically';
COMMENT ON COLUMN system_audit_trail.hash_chain_index IS 'Sequential index in chain (per tenant)';
COMMENT ON COLUMN system_audit_trail.tenant_id IS 'Each tenant has its own hash chain';
COMMENT ON FUNCTION calculate_audit_hash IS 'Calculates SHA-256 hash including prev_hash to form chain';
COMMENT ON FUNCTION validate_audit_hash_chain IS 'Validates hash chain integrity';

