-- ============================================
-- Migration 004: Document Facts & Generated Documents
-- Legal traceability and proof lineage
-- ============================================

-- ============================================
-- DOCUMENT_FACTS TABLE (tenant-scoped)
-- Stores extracted facts with location and confidence for proof lineage
-- ============================================
CREATE TABLE IF NOT EXISTS document_facts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Multi-tenant isolation
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,

    -- Source document
    document_id UUID NOT NULL REFERENCES documents(id) ON DELETE CASCADE,

    -- Fact content
    fact_type VARCHAR(100) NOT NULL,   -- e.g. 'process_number', 'party', 'monetary_value', 'date'
    fact_value TEXT NOT NULL,

    -- Location in source document
    page_number INTEGER,              -- 1-based page number (null if unknown)
    bounding_box JSONB,               -- { "x": number, "y": number, "width": number, "height": number } in normalized coords

    -- Quality
    confidence_score DECIMAL(5, 2),   -- 0-100

    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

CREATE INDEX idx_document_facts_tenant_id ON document_facts(tenant_id);
CREATE INDEX idx_document_facts_document_id ON document_facts(document_id);
CREATE INDEX idx_document_facts_fact_type ON document_facts(tenant_id, fact_type);
CREATE INDEX idx_document_facts_created_at ON document_facts(created_at);

COMMENT ON TABLE document_facts IS 'Tenant-scoped facts extracted from documents for legal traceability';
COMMENT ON COLUMN document_facts.bounding_box IS 'Normalized bounding box (x, y, width, height) for jump-back to source';

-- ============================================
-- GENERATED_DOCUMENTS TABLE (tenant-scoped)
-- Documents generated from source facts with full lineage
-- ============================================
CREATE TABLE IF NOT EXISTS generated_documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Multi-tenant isolation
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,

    -- Content (e.g. report body, summary)
    content TEXT NOT NULL,

    -- Who generated (user id)
    generated_by UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,

    -- Proof lineage: fact IDs used as sources
    source_fact_ids UUID[] NOT NULL DEFAULT '{}',

    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,

    CONSTRAINT valid_source_fact_ids CHECK (array_length(source_fact_ids, 1) IS NULL OR array_length(source_fact_ids, 1) >= 0)
);

CREATE INDEX idx_generated_documents_tenant_id ON generated_documents(tenant_id);
CREATE INDEX idx_generated_documents_generated_by ON generated_documents(generated_by);
CREATE INDEX idx_generated_documents_created_at ON generated_documents(created_at);
CREATE INDEX idx_generated_documents_source_fact_ids ON generated_documents USING GIN(source_fact_ids);

COMMENT ON TABLE generated_documents IS 'Documents generated from document_facts with full source lineage';
COMMENT ON COLUMN generated_documents.source_fact_ids IS 'Array of document_facts.id for proof lineage';
