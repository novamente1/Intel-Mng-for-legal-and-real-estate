# Technical Evidence - Milestone 1
## Backbone Infrastructure (SaaS Infrastructure and DB) Compliance

**To:** Wanderlei  
**From:** Technical Team  
**Date:** January 26, 2024  
**Subject:** Compliance Evidence - Master Manual (Modules 7 and 9)

---

Hi Wanderlei,

As discussed, here are the technical evidences for the Backbone Infrastructure for the Milestone 1 deposit release. I've organized everything according to what your auditor requested.

---

## 1. Database Schema Sample

### 1.1. `saas_tenants` Table (Multi-Tenant Isolation)

**Complete SQL file:** `apps/api/database/schema-saas-tables.sql`

Here's the `saas_tenants` table script:

```sql
CREATE TABLE saas_tenants (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id VARCHAR(100) UNIQUE NOT NULL,  -- tenant_id column as requested
    name VARCHAR(255) NOT NULL,
    domain VARCHAR(255) UNIQUE,
    subdomain VARCHAR(100) UNIQUE,
    status VARCHAR(50) NOT NULL DEFAULT 'active',
    tier VARCHAR(50) DEFAULT 'standard',
    isolation_level VARCHAR(50) DEFAULT 'logical',  -- can be 'logical' or 'physical'
    database_schema VARCHAR(100),  -- used when isolation_level = 'physical'
    metadata JSONB DEFAULT '{}'::jsonb,
    settings JSONB DEFAULT '{}'::jsonb,
    data_residency VARCHAR(100),
    compliance_flags TEXT[],
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    activated_at TIMESTAMP WITH TIME ZONE,
    suspended_at TIMESTAMP WITH TIME ZONE,
    deleted_at TIMESTAMP WITH TIME ZONE,
    deleted_by UUID REFERENCES users(id),
    CONSTRAINT tenant_id_format CHECK (tenant_id ~ '^[a-z0-9_-]+$')
);

-- index to ensure performance on tenant_id queries
CREATE INDEX idx_saas_tenants_tenant_id ON saas_tenants(tenant_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_saas_tenants_status ON saas_tenants(status) WHERE deleted_at IS NULL;
```

**About isolation:**
The `tenant_id` column is implemented as NOT NULL, so it's mandatory for all records. We have a unique index to ensure no duplicates. The table supports both logical isolation (shared database) and physical isolation (dedicated schema), depending on tenant needs. The `system_audit_trail` table also references this table to maintain isolation in auditing.

---

### 1.2. `system_audit_trail` Table (Hash Chain)

Here's the `system_audit_trail` table with hash chain implementation:

```sql
CREATE TABLE system_audit_trail (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- hash chain as specified
    prev_hash VARCHAR(64),  -- hash of previous record (NULL for first)
    curr_hash VARCHAR(64) NOT NULL,  -- hash of current record (SHA-256)
    hash_chain_index BIGSERIAL,  -- sequential index in chain
    
    tenant_id VARCHAR(100) REFERENCES saas_tenants(tenant_id),
    event_type VARCHAR(100) NOT NULL,
    event_category VARCHAR(50) NOT NULL,
    action VARCHAR(50) NOT NULL,
    user_id UUID REFERENCES users(id),
    resource_type VARCHAR(100),
    resource_id UUID,
    description TEXT NOT NULL,
    details JSONB DEFAULT '{}'::jsonb,
    before_state JSONB,
    after_state JSONB,
    ip_address INET,
    user_agent TEXT,
    request_id VARCHAR(100),
    success BOOLEAN DEFAULT true,
    compliance_flags TEXT[],
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    
    CONSTRAINT curr_hash_format CHECK (curr_hash ~ '^[a-f0-9]{64}$'),
    CONSTRAINT prev_hash_format CHECK (prev_hash IS NULL OR prev_hash ~ '^[a-f0-9]{64}$')
);

-- trigger that calculates hash automatically before insert
CREATE TRIGGER set_audit_trail_hash_trigger
    BEFORE INSERT ON system_audit_trail
    FOR EACH ROW
    EXECUTE FUNCTION set_audit_trail_hash();

-- triggers that prevent modification (ensure immutability)
CREATE TRIGGER prevent_audit_trail_update
    BEFORE UPDATE ON system_audit_trail
    FOR EACH ROW
    EXECUTE FUNCTION prevent_audit_trail_modification();

CREATE TRIGGER prevent_audit_trail_delete
    BEFORE DELETE ON system_audit_trail
    FOR EACH ROW
    EXECUTE FUNCTION prevent_audit_trail_modification();
```

**About the hash chain:**
The `prev_hash` and `curr_hash` columns are implemented using SHA-256. The `set_audit_trail_hash_trigger` trigger runs before each INSERT and automatically calculates `curr_hash`, including the `prev_hash` from the last record of the same tenant. This forms the hash chain.

Each tenant has its own chain (isolated by `tenant_id`). The `validate_audit_hash_chain()` function allows validating the integrity of the entire chain when needed.

The hash calculation logic concatenates the main fields:
```
hash_input = id || '|' || prev_hash || '|' || tenant_id || '|' || 
             event_type || '|' || action || '|' || user_id || '|' || 
             resource_type || '|' || resource_id || '|' || description || 
             '|' || details || '|' || created_at
curr_hash = SHA256(hash_input)
```

The UPDATE and DELETE triggers ensure the table is immutable - any attempt to modify or delete a record will raise an exception.

---

## 2. Network Segregation

### 2.1. Docker Compose

The configuration is in `infrastructure/docker/docker-compose.yml`. The isolated network is configured like this:

```yaml
networks:
  platform-network:
    driver: bridge
    ipam:
      config:
        - subnet: 172.28.0.0/16
```

All services are connected to this network. PostgreSQL and Redis don't expose ports to the host - they're only accessible within the Docker network through service names (internal DNS). The API and intelligence service only expose the necessary ports (3000 and 8000 respectively) for external access, but communication between services happens only within the isolated network.

To validate, you can run:
```bash
docker network inspect platform-network
docker exec platform-api ping -c 3 postgres
docker exec platform-api ping -c 3 redis
docker ps --format "table {{.Names}}\t{{.Ports}}"
```

### 2.2. Kubernetes

In Kubernetes, services are configured as `ClusterIP` (file `infrastructure/k8s/api/service.yaml`), which means they're only accessible within the cluster. External access is done exclusively via Ingress, which is configured with mandatory SSL/TLS, rate limiting, and health checks.

To verify:
```bash
kubectl get svc -n platform
kubectl get networkpolicies -n platform  # if policies are applied
kubectl get pods -n platform -o wide
```

---

## 3. Reference Files

The complete SQL scripts are in `apps/api/database/schema-saas-tables.sql`. This file contains both tables (`saas_tenants` and `system_audit_trail`) with all triggers and functions.

Infrastructure configurations are in:
- `infrastructure/docker/docker-compose.yml` - Docker
- `infrastructure/k8s/api/service.yaml` and `infrastructure/k8s/ingress.yaml` - Kubernetes

There's also a validation script at `scripts/validate-network-segregation.sh` if you want to test network segregation automatically.

---

## 4. Compliance Summary

**Module 7 - Multi-Tenant Isolation:**
The `saas_tenants` table is implemented with the mandatory `tenant_id` column. Indexes are configured to ensure performance on isolation queries. The implementation supports both logical and physical isolation, depending on needs.

**Module 9 - Audit and Integrity:**
The `system_audit_trail` table is implemented with hash chain using SHA-256. The automatic trigger calculates the hash before each insert, and the validation function allows checking chain integrity when needed. Immutability is guaranteed by triggers that block UPDATE and DELETE. Each tenant has its own isolated hash chain.

**Network Security:**
The Docker network is isolated with a dedicated subnet. In Kubernetes, services are configured as ClusterIP for internal access only, and Ingress is configured with mandatory SSL/TLS, rate limiting, and health checks.

---

## 5. Next Steps

To validate, I suggest:

1. Apply the SQL schema in a test environment and verify that tables and triggers were created correctly
2. Run the network validation commands listed above and capture the results (screenshots or logs)
3. Do some test inserts into `system_audit_trail` and verify that the hash is being calculated correctly. Then run the `validate_audit_hash_chain()` function to confirm chain integrity

---

## Conclusion

The infrastructure is compliant with the Master Manual (Modules 7 and 9). We have:

- Multi-tenant isolation with the `saas_tenants` table and `tenant_id` column
- Audit hash chain in `system_audit_trail` with `prev_hash` and `curr_hash`
- Network segregation configured in both Docker and Kubernetes

We await your auditor's validation to release the deposit.

If you have any questions, just let me know.

---

**Best regards,**  
Technical Team

---

**Attachments:**
- `apps/api/database/schema-saas-tables.sql` - Complete SQL scripts
- `docs/compliance/MILESTONE1_TECHNICAL_EVIDENCE.md` - Detailed technical documentation

