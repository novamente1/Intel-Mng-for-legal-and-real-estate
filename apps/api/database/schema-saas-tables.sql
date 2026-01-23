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
    status VARCHAR(50) NOT NULL DEFAULT 'ACTIVE', -- uppercase status values
    tier VARCHAR(50) DEFAULT 'STANDARD',
    max_users INTEGER DEFAULT 10,
    max_storage_gb INTEGER DEFAULT 10,
    
    -- isolation settings
    database_schema VARCHAR(100), -- dedicated schema (when isolation_level = 'physical')
    isolation_level VARCHAR(50) DEFAULT 'logical', -- 'logical' or 'physical'
    
    -- Metadata
    metadata JSONB DEFAULT '{}'::jsonb, -- tenant-specific configurations
    settings JSONB DEFAULT '{}'::jsonb, -- preferences and settings
    
    -- dynamic rules (JSONB for flexible rule configuration)
    dynamic_rules JSONB DEFAULT '{}'::jsonb, -- dynamic business rules and policies
    
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
    CONSTRAINT valid_status CHECK (status IN ('ACTIVE', 'SUSPENDED', 'INACTIVE', 'TRIAL', 'EXPIRED')),
    CONSTRAINT valid_tier CHECK (tier IN ('TRIAL', 'STANDARD', 'PREMIUM', 'ENTERPRISE')),
    CONSTRAINT valid_isolation_level CHECK (isolation_level IN ('logical', 'physical')),
    CONSTRAINT tenant_id_format CHECK (tenant_id ~ '^[a-z0-9_-]+$')
);

-- Indexes for performance and isolation
CREATE INDEX idx_saas_tenants_tenant_id ON saas_tenants(tenant_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_saas_tenants_status ON saas_tenants(status) WHERE deleted_at IS NULL;
CREATE INDEX idx_saas_tenants_domain ON saas_tenants(domain) WHERE deleted_at IS NULL;
CREATE INDEX idx_saas_tenants_subdomain ON saas_tenants(subdomain) WHERE deleted_at IS NULL;
CREATE INDEX idx_saas_tenants_created_at ON saas_tenants(created_at);

-- GIN index for dynamic_rules JSONB
CREATE INDEX idx_saas_tenants_dynamic_rules ON saas_tenants USING GIN(dynamic_rules) WHERE deleted_at IS NULL;

-- Documentation comments
COMMENT ON TABLE saas_tenants IS 'Multi-tenant isolation table (SaaS)';
COMMENT ON COLUMN saas_tenants.tenant_id IS 'Unique tenant identifier - used for data isolation in all tables';
COMMENT ON COLUMN saas_tenants.isolation_level IS 'Isolation level: logical (shared DB with tenant_id) or physical (dedicated DB)';
COMMENT ON COLUMN saas_tenants.database_schema IS 'Dedicated PostgreSQL schema for physical isolation (when isolation_level = physical)';
COMMENT ON COLUMN saas_tenants.dynamic_rules IS 'JSONB field for dynamic business rules and policies configuration';
COMMENT ON COLUMN saas_tenants.status IS 'Tenant status in uppercase (ACTIVE, SUSPENDED, INACTIVE, TRIAL, EXPIRED)';

-- ============================================
-- SYSTEM_AUDIT_TRAIL TABLE
-- Audit trail with hash chain
-- ============================================
CREATE TABLE system_audit_trail (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- hash chain (immutable audit chain)
    prev_hash VARCHAR(64), -- hash of previous record (NULL for first)
    curr_hash VARCHAR(64) NOT NULL, -- hash of current record (SHA-256)
    hash_chain_index BIGSERIAL, -- sequential index in chain
    chain_id UUID, -- chain identifier for grouping related audit records
    chain_sequence BIGINT, -- sequence number within the chain
    
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

-- Indexes for performance
CREATE INDEX idx_audit_trail_tenant_id ON system_audit_trail(tenant_id);
CREATE INDEX idx_audit_trail_hash_chain_index ON system_audit_trail(hash_chain_index DESC);
CREATE INDEX idx_audit_trail_chain_id ON system_audit_trail(chain_id) WHERE chain_id IS NOT NULL;
CREATE INDEX idx_audit_trail_chain_sequence ON system_audit_trail(chain_id, chain_sequence) WHERE chain_id IS NOT NULL;
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

-- Composite indexes for common queries
CREATE INDEX idx_audit_trail_tenant_time ON system_audit_trail(tenant_id, created_at DESC);
CREATE INDEX idx_audit_trail_user_time ON system_audit_trail(user_id, created_at DESC);
CREATE INDEX idx_audit_trail_resource_time ON system_audit_trail(resource_type, resource_id, created_at DESC);

-- GIN indexes for JSONB
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
    p_chain_id UUID,
    p_chain_sequence BIGINT,
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
    -- concatenate relevant fields to form the hash (including chain fields)
    hash_input := COALESCE(p_id::TEXT, '') || '|' ||
                  COALESCE(p_prev_hash, '') || '|' ||
                  COALESCE(p_tenant_id, '') || '|' ||
                  COALESCE(p_chain_id::TEXT, '') || '|' ||
                  COALESCE(p_chain_sequence::TEXT, '') || '|' ||
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
    
    -- generate chain_id if not provided (for grouping related records)
    IF NEW.chain_id IS NULL THEN
        NEW.chain_id := uuid_generate_v4();
    END IF;
    
    -- set chain_sequence if not provided
    IF NEW.chain_sequence IS NULL THEN
        SELECT COALESCE(MAX(chain_sequence), 0) + 1 INTO NEW.chain_sequence
        FROM system_audit_trail
        WHERE chain_id = NEW.chain_id;
    END IF;
    
    -- calculate hash of current record
    NEW.curr_hash := calculate_audit_hash(
        NEW.id,
        NEW.prev_hash,
        NEW.tenant_id,
        NEW.chain_id,
        NEW.chain_sequence,
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
            chain_id,
            chain_sequence,
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
                ot.chain_id,
                ot.chain_sequence,
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

-- Documentation comments
COMMENT ON TABLE system_audit_trail IS 'Immutable audit trail with hash chain';
COMMENT ON COLUMN system_audit_trail.prev_hash IS 'SHA-256 hash of previous record (NULL for first)';
COMMENT ON COLUMN system_audit_trail.curr_hash IS 'SHA-256 hash of current record, calculated automatically';
COMMENT ON COLUMN system_audit_trail.hash_chain_index IS 'Sequential index in chain (per tenant)';
COMMENT ON COLUMN system_audit_trail.chain_id IS 'Chain identifier for grouping related audit records';
COMMENT ON COLUMN system_audit_trail.chain_sequence IS 'Sequence number within the chain';
COMMENT ON COLUMN system_audit_trail.tenant_id IS 'Each tenant has its own hash chain';
COMMENT ON FUNCTION calculate_audit_hash IS 'Calculates SHA-256 hash including prev_hash to form chain';
COMMENT ON FUNCTION validate_audit_hash_chain IS 'Validates hash chain integrity';

-- ============================================
-- DOCUMENTS TABLE
-- Document management with CPO (Quality Control) support
-- ============================================
CREATE TABLE documents (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- multi-tenant isolation
    tenant_id VARCHAR(100) NOT NULL REFERENCES saas_tenants(tenant_id) ON DELETE CASCADE,
    
    -- document identification
    document_number VARCHAR(100) NOT NULL, -- human-readable document identifier
    title VARCHAR(500) NOT NULL,
    description TEXT,
    document_type VARCHAR(100) NOT NULL, -- 'contract', 'legal_document', 'real_estate_deed', etc.
    category VARCHAR(100), -- document category
    
    -- file information
    file_name VARCHAR(500) NOT NULL,
    file_path VARCHAR(1000), -- storage path
    file_size BIGINT, -- file size in bytes
    mime_type VARCHAR(100), -- MIME type
    file_hash VARCHAR(64), -- SHA-256 hash of file content for integrity
    
    -- document status
    status VARCHAR(50) NOT NULL DEFAULT 'DRAFT', -- 'DRAFT', 'PENDING_REVIEW', 'APPROVED', 'REJECTED', 'ARCHIVED'
    version INTEGER DEFAULT 1, -- document version number
    is_current_version BOOLEAN DEFAULT true, -- flag for current version
    
    -- CPO (Quality Control) fields
    cpo_status VARCHAR(50), -- 'PENDING', 'IN_REVIEW', 'APPROVED', 'REJECTED', 'REQUIRES_REVISION'
    cpo_reviewer_id UUID REFERENCES users(id) ON DELETE SET NULL, -- who reviewed
    cpo_reviewed_at TIMESTAMP WITH TIME ZONE, -- when reviewed
    cpo_notes TEXT, -- CPO review notes
    cpo_checklist JSONB DEFAULT '{}'::jsonb, -- CPO quality control checklist
    cpo_approval_required BOOLEAN DEFAULT false, -- requires CPO approval
    cpo_approved_by UUID REFERENCES users(id) ON DELETE SET NULL,
    cpo_approved_at TIMESTAMP WITH TIME ZONE,
    
    -- ownership and assignment
    owner_id UUID REFERENCES users(id) ON DELETE SET NULL,
    created_by UUID REFERENCES users(id) ON DELETE SET NULL,
    updated_by UUID REFERENCES users(id) ON DELETE SET NULL,
    
    -- relationships
    parent_document_id UUID REFERENCES documents(id) ON DELETE SET NULL, -- for document versions
    related_document_ids UUID[], -- array of related document IDs
    process_id UUID, -- reference to process/workflow
    
    -- dates
    document_date DATE, -- document date (not creation date)
    expiration_date DATE, -- document expiration date
    effective_date DATE, -- when document becomes effective
    
    -- metadata
    metadata JSONB DEFAULT '{}'::jsonb, -- flexible document-specific data
    tags TEXT[], -- document tags
    keywords TEXT[], -- search keywords
    
    -- compliance
    confidentiality_level VARCHAR(20) DEFAULT 'INTERNAL', -- 'PUBLIC', 'INTERNAL', 'CONFIDENTIAL', 'RESTRICTED'
    retention_policy VARCHAR(100), -- retention policy identifier
    retention_until TIMESTAMP WITH TIME ZONE, -- when document can be deleted
    
    -- timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    deleted_at TIMESTAMP WITH TIME ZONE,
    deleted_by UUID REFERENCES users(id),
    
    -- constraints
    CONSTRAINT valid_status CHECK (status IN ('DRAFT', 'PENDING_REVIEW', 'APPROVED', 'REJECTED', 'ARCHIVED')),
    CONSTRAINT valid_cpo_status CHECK (cpo_status IS NULL OR cpo_status IN ('PENDING', 'IN_REVIEW', 'APPROVED', 'REJECTED', 'REQUIRES_REVISION')),
    CONSTRAINT valid_confidentiality CHECK (confidentiality_level IN ('PUBLIC', 'INTERNAL', 'CONFIDENTIAL', 'RESTRICTED')),
    CONSTRAINT unique_document_number_tenant UNIQUE (tenant_id, document_number)
);

-- Indexes for documents table
CREATE INDEX idx_documents_tenant_id ON documents(tenant_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_documents_document_number ON documents(document_number) WHERE deleted_at IS NULL;
CREATE INDEX idx_documents_status ON documents(status) WHERE deleted_at IS NULL;
CREATE INDEX idx_documents_cpo_status ON documents(cpo_status) WHERE deleted_at IS NULL AND cpo_status IS NOT NULL;
CREATE INDEX idx_documents_document_type ON documents(document_type) WHERE deleted_at IS NULL;
CREATE INDEX idx_documents_owner ON documents(owner_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_documents_created_by ON documents(created_by) WHERE deleted_at IS NULL;
CREATE INDEX idx_documents_parent ON documents(parent_document_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_documents_process ON documents(process_id) WHERE deleted_at IS NULL AND process_id IS NOT NULL;
CREATE INDEX idx_documents_document_date ON documents(document_date) WHERE deleted_at IS NULL;
CREATE INDEX idx_documents_expiration_date ON documents(expiration_date) WHERE deleted_at IS NULL AND expiration_date IS NOT NULL;
CREATE INDEX idx_documents_created_at ON documents(created_at);

-- Composite indexes
CREATE INDEX idx_documents_tenant_status ON documents(tenant_id, status) WHERE deleted_at IS NULL;
CREATE INDEX idx_documents_tenant_cpo ON documents(tenant_id, cpo_status) WHERE deleted_at IS NULL AND cpo_status IS NOT NULL;
CREATE INDEX idx_documents_version ON documents(parent_document_id, version) WHERE deleted_at IS NULL AND parent_document_id IS NOT NULL;

-- GIN indexes for JSONB and arrays
CREATE INDEX idx_documents_metadata ON documents USING GIN(metadata) WHERE deleted_at IS NULL;
CREATE INDEX idx_documents_cpo_checklist ON documents USING GIN(cpo_checklist) WHERE deleted_at IS NULL AND cpo_checklist IS NOT NULL;
CREATE INDEX idx_documents_tags ON documents USING GIN(tags) WHERE deleted_at IS NULL;
CREATE INDEX idx_documents_keywords ON documents USING GIN(keywords) WHERE deleted_at IS NULL;

-- Documentation comments
COMMENT ON TABLE documents IS 'Document management table with CPO (Quality Control) support';
COMMENT ON COLUMN documents.tenant_id IS 'Multi-tenant isolation - each tenant has isolated documents';
COMMENT ON COLUMN documents.cpo_status IS 'CPO (Quality Control) review status';
COMMENT ON COLUMN documents.cpo_checklist IS 'JSONB field for CPO quality control checklist items';
COMMENT ON COLUMN documents.cpo_approval_required IS 'Flag indicating if CPO approval is required before document can be finalized';
COMMENT ON COLUMN documents.file_hash IS 'SHA-256 hash of file content for integrity verification';

