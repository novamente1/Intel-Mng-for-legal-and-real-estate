-- ============================================
-- Migration 012: Knowledge Management Module
-- Legal theses, document templates, semantic search, success tracking
-- ============================================

-- Knowledge Entries table (legal theses, case outcomes, legal knowledge)
CREATE TABLE IF NOT EXISTS knowledge_entries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Tenant isolation (mandatory)
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    
    -- Entry identification
    entry_type VARCHAR(50) NOT NULL, -- 'LEGAL_THESIS', 'CASE_OUTCOME', 'LEGAL_PRECEDENT', 'LEGAL_OPINION'
    title VARCHAR(500) NOT NULL,
    summary TEXT,
    content TEXT NOT NULL, -- Full content for semantic search
    
    -- Categorization
    category VARCHAR(100), -- e.g., 'contract_law', 'property_law', 'corporate_law'
    tags TEXT[],
    keywords TEXT[], -- For search optimization
    
    -- Source case links (link to source cases/processes)
    source_case_ids UUID[] NOT NULL DEFAULT '{}', -- Links to processes table (cases)
    source_document_ids UUID[] NOT NULL DEFAULT '{}', -- Links to documents
    
    -- Legal metadata
    jurisdiction VARCHAR(100), -- Legal jurisdiction
    court_level VARCHAR(50), -- 'SUPREME', 'APPEAL', 'TRIAL', 'OTHER'
    decision_date DATE,
    case_number VARCHAR(255),
    judge_name VARCHAR(255),
    
    -- Outcome information
    outcome_type VARCHAR(50), -- 'FAVORABLE', 'UNFAVORABLE', 'MIXED', 'SETTLED'
    outcome_summary TEXT,
    key_legal_points TEXT[], -- Key legal points from the case
    
    -- Semantic search support
    embedding_vector REAL[], -- Vector embedding for semantic search (if using vector DB)
    search_text TEXT, -- Preprocessed text for full-text search
    
    -- Usage and relevance
    view_count INTEGER DEFAULT 0,
    last_viewed_at TIMESTAMP WITH TIME ZONE,
    relevance_score DECIMAL(5, 2), -- Calculated relevance score (0-100)
    
    -- Status
    is_active BOOLEAN DEFAULT true,
    is_verified BOOLEAN DEFAULT false, -- Verified by legal expert
    verified_by UUID REFERENCES users(id),
    verified_at TIMESTAMP WITH TIME ZONE,
    
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
    CONSTRAINT valid_entry_type CHECK (
        entry_type IN ('LEGAL_THESIS', 'CASE_OUTCOME', 'LEGAL_PRECEDENT', 'LEGAL_OPINION')
    ),
    CONSTRAINT valid_outcome_type CHECK (
        outcome_type IS NULL OR outcome_type IN ('FAVORABLE', 'UNFAVORABLE', 'MIXED', 'SETTLED')
    ),
    CONSTRAINT valid_relevance_score CHECK (
        relevance_score IS NULL OR (relevance_score >= 0 AND relevance_score <= 100)
    )
);

CREATE INDEX idx_knowledge_entries_tenant_id ON knowledge_entries(tenant_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_knowledge_entries_type ON knowledge_entries(tenant_id, entry_type) WHERE deleted_at IS NULL;
CREATE INDEX idx_knowledge_entries_category ON knowledge_entries(tenant_id, category) WHERE deleted_at IS NULL;
CREATE INDEX idx_knowledge_entries_source_cases ON knowledge_entries USING GIN(source_case_ids) WHERE deleted_at IS NULL;
CREATE INDEX idx_knowledge_entries_tags ON knowledge_entries USING GIN(tags) WHERE deleted_at IS NULL;
CREATE INDEX idx_knowledge_entries_keywords ON knowledge_entries USING GIN(keywords) WHERE deleted_at IS NULL;
CREATE INDEX idx_knowledge_entries_search_text ON knowledge_entries USING GIN(to_tsvector('portuguese', search_text)) WHERE deleted_at IS NULL;
CREATE INDEX idx_knowledge_entries_relevance ON knowledge_entries(tenant_id, relevance_score DESC) WHERE deleted_at IS NULL AND is_active = true;

COMMENT ON TABLE knowledge_entries IS 'Knowledge entries - legal theses, case outcomes, precedents';
COMMENT ON COLUMN knowledge_entries.source_case_ids IS 'Links to source cases/processes for traceability';
COMMENT ON COLUMN knowledge_entries.search_text IS 'Preprocessed text for full-text semantic search';

-- Document Templates table
CREATE TABLE IF NOT EXISTS document_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Tenant isolation (mandatory)
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    
    -- Template identification
    template_name VARCHAR(255) NOT NULL,
    template_type VARCHAR(100) NOT NULL, -- e.g., 'CONTRACT', 'PETITION', 'MOTION', 'LETTER'
    description TEXT,
    
    -- Template content
    template_content TEXT NOT NULL, -- Template with placeholders
    template_structure JSONB, -- Structured template definition (sections, fields)
    variables JSONB, -- Template variables/placeholders definition
    
    -- Categorization
    category VARCHAR(100),
    tags TEXT[],
    use_cases TEXT[], -- When to use this template
    
    -- Source knowledge links
    source_knowledge_entry_ids UUID[] NOT NULL DEFAULT '{}', -- Links to knowledge_entries
    source_case_ids UUID[] NOT NULL DEFAULT '{}', -- Links to processes (cases)
    
    -- Success tracking
    usage_count INTEGER DEFAULT 0, -- How many times template was used
    success_count INTEGER DEFAULT 0, -- How many times it led to favorable outcome
    failure_count INTEGER DEFAULT 0, -- How many times it led to unfavorable outcome
    success_rate DECIMAL(5, 2), -- Calculated: success_count / usage_count * 100
    last_used_at TIMESTAMP WITH TIME ZONE,
    
    -- Priority and ranking
    priority_score DECIMAL(5, 2) DEFAULT 50, -- Calculated priority (0-100, higher = more priority)
    is_recommended BOOLEAN DEFAULT false, -- Recommended template
    
    -- Versioning
    version_number INTEGER DEFAULT 1,
    parent_template_id UUID REFERENCES document_templates(id) ON DELETE SET NULL, -- For template versions
    is_current_version BOOLEAN DEFAULT true,
    
    -- Status
    is_active BOOLEAN DEFAULT true,
    is_verified BOOLEAN DEFAULT false,
    verified_by UUID REFERENCES users(id),
    verified_at TIMESTAMP WITH TIME ZONE,
    
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
    CONSTRAINT valid_success_rate CHECK (
        success_rate IS NULL OR (success_rate >= 0 AND success_rate <= 100)
    ),
    CONSTRAINT valid_priority_score CHECK (
        priority_score >= 0 AND priority_score <= 100
    ),
    CONSTRAINT positive_counts CHECK (
        usage_count >= 0 AND success_count >= 0 AND failure_count >= 0
    )
);

CREATE INDEX idx_document_templates_tenant_id ON document_templates(tenant_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_document_templates_type ON document_templates(tenant_id, template_type) WHERE deleted_at IS NULL;
CREATE INDEX idx_document_templates_category ON document_templates(tenant_id, category) WHERE deleted_at IS NULL;
CREATE INDEX idx_document_templates_success_rate ON document_templates(tenant_id, success_rate DESC) WHERE deleted_at IS NULL AND is_active = true;
CREATE INDEX idx_document_templates_priority ON document_templates(tenant_id, priority_score DESC) WHERE deleted_at IS NULL AND is_active = true;
CREATE INDEX idx_document_templates_recommended ON document_templates(tenant_id, is_recommended) WHERE deleted_at IS NULL AND is_active = true;
CREATE INDEX idx_document_templates_source_knowledge ON document_templates USING GIN(source_knowledge_entry_ids) WHERE deleted_at IS NULL;

COMMENT ON TABLE document_templates IS 'Document templates with success rate tracking';
COMMENT ON COLUMN document_templates.success_rate IS 'Success rate percentage - templates with higher rates are prioritized';
COMMENT ON COLUMN document_templates.priority_score IS 'Calculated priority score based on success rate and usage';

-- Template Usage Statistics table (tracks template usage and outcomes)
CREATE TABLE IF NOT EXISTS template_usage_stats (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Tenant isolation (mandatory)
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    
    -- Template reference
    template_id UUID NOT NULL REFERENCES document_templates(id) ON DELETE CASCADE,
    
    -- Usage information
    used_in_case_id UUID REFERENCES processes(id) ON DELETE SET NULL, -- Case where template was used
    used_in_document_id UUID REFERENCES documents(id) ON DELETE SET NULL, -- Generated document
    used_by UUID REFERENCES users(id),
    used_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    
    -- Outcome tracking
    outcome_type VARCHAR(50), -- 'SUCCESS', 'FAILURE', 'PENDING', 'PARTIAL'
    outcome_date DATE,
    outcome_notes TEXT,
    
    -- Feedback
    user_feedback VARCHAR(50), -- 'POSITIVE', 'NEUTRAL', 'NEGATIVE'
    user_rating INTEGER, -- 1-5 rating
    feedback_notes TEXT,
    
    -- Metadata
    metadata JSONB DEFAULT '{}'::jsonb,
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    
    -- Constraints
    CONSTRAINT valid_outcome_type CHECK (
        outcome_type IS NULL OR outcome_type IN ('SUCCESS', 'FAILURE', 'PENDING', 'PARTIAL')
    ),
    CONSTRAINT valid_user_rating CHECK (
        user_rating IS NULL OR (user_rating >= 1 AND user_rating <= 5)
    )
);

CREATE INDEX idx_template_usage_stats_tenant_id ON template_usage_stats(tenant_id);
CREATE INDEX idx_template_usage_stats_template_id ON template_usage_stats(template_id);
CREATE INDEX idx_template_usage_stats_case_id ON template_usage_stats(used_in_case_id) WHERE used_in_case_id IS NOT NULL;
CREATE INDEX idx_template_usage_stats_outcome ON template_usage_stats(tenant_id, outcome_type) WHERE outcome_type IS NOT NULL;
CREATE INDEX idx_template_usage_stats_date ON template_usage_stats(used_at DESC);

COMMENT ON TABLE template_usage_stats IS 'Tracks template usage and outcomes for success rate calculation';

-- Semantic Search Cache table (caches search results for performance)
CREATE TABLE IF NOT EXISTS semantic_search_cache (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Tenant isolation
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    
    -- Search query
    search_query TEXT NOT NULL,
    query_hash VARCHAR(64) NOT NULL, -- Hash of query for quick lookup
    query_type VARCHAR(50), -- 'CASE_SEARCH', 'OUTCOME_SEARCH', 'TEMPLATE_SEARCH'
    
    -- Search results
    result_ids UUID[] NOT NULL, -- IDs of matching knowledge entries/templates
    result_scores REAL[], -- Relevance scores for each result
    total_results INTEGER,
    
    -- Cache metadata
    cache_expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    
    -- Constraints
    CONSTRAINT valid_query_type CHECK (
        query_type IS NULL OR query_type IN ('CASE_SEARCH', 'OUTCOME_SEARCH', 'TEMPLATE_SEARCH', 'GENERAL_SEARCH')
    )
);

CREATE INDEX idx_semantic_search_cache_tenant_id ON semantic_search_cache(tenant_id);
CREATE INDEX idx_semantic_search_cache_query_hash ON semantic_search_cache(query_hash);
CREATE INDEX idx_semantic_search_cache_expires ON semantic_search_cache(cache_expires_at) WHERE cache_expires_at > CURRENT_TIMESTAMP;

COMMENT ON TABLE semantic_search_cache IS 'Caches semantic search results for performance';

-- Function to update template success rate
CREATE OR REPLACE FUNCTION update_template_success_rate()
RETURNS TRIGGER AS $$
DECLARE
    v_usage_count INTEGER;
    v_success_count INTEGER;
    v_failure_count INTEGER;
    v_success_rate DECIMAL(5, 2);
    v_priority_score DECIMAL(5, 2);
BEGIN
    -- Calculate statistics
    SELECT 
        COUNT(*)::INTEGER,
        COUNT(*) FILTER (WHERE outcome_type = 'SUCCESS')::INTEGER,
        COUNT(*) FILTER (WHERE outcome_type = 'FAILURE')::INTEGER
    INTO v_usage_count, v_success_count, v_failure_count
    FROM template_usage_stats
    WHERE template_id = COALESCE(NEW.template_id, OLD.template_id)
      AND tenant_id = COALESCE(NEW.tenant_id, OLD.tenant_id);
    
    -- Calculate success rate
    IF v_usage_count > 0 THEN
        v_success_rate := (v_success_count::DECIMAL / v_usage_count::DECIMAL) * 100;
    ELSE
        v_success_rate := NULL;
    END IF;
    
    -- Calculate priority score (based on success rate and usage)
    -- Higher success rate = higher priority, but also consider usage count
    IF v_usage_count > 0 THEN
        v_priority_score := v_success_rate * 0.7 + LEAST(v_usage_count / 10.0, 30) * 0.3;
    ELSE
        v_priority_score := 50; -- Default for unused templates
    END IF;
    
    -- Update template
    UPDATE document_templates
    SET usage_count = v_usage_count,
        success_count = v_success_count,
        failure_count = v_failure_count,
        success_rate = v_success_rate,
        priority_score = v_priority_score,
        is_recommended = CASE WHEN v_success_rate >= 70 AND v_usage_count >= 5 THEN true ELSE false END,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = COALESCE(NEW.template_id, OLD.template_id);
    
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- Trigger to update template success rate when usage stats change
CREATE TRIGGER update_template_success_rate_trigger
    AFTER INSERT OR UPDATE OR DELETE ON template_usage_stats
    FOR EACH ROW EXECUTE FUNCTION update_template_success_rate();

-- Triggers for updated_at
CREATE TRIGGER update_knowledge_entries_updated_at 
    BEFORE UPDATE ON knowledge_entries
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_document_templates_updated_at 
    BEFORE UPDATE ON document_templates
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_template_usage_stats_updated_at 
    BEFORE UPDATE ON template_usage_stats
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
