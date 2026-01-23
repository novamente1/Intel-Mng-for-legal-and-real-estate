# Evidências Técnicas - Marco 1
## Homologação da Espinha Dorsal (Infraestrutura SaaS e DB)

**Para:** Wanderlei  
**De:** Equipe Técnica  
**Data:** 26 de Janeiro de 2024  
**Assunto:** Evidências de Conformidade - Manual do Mestre (Módulos 7 e 9)

---

Olá Wanderlei,

Como combinado, seguem as evidências técnicas da Espinha Dorsal para a liberação do depósito do Marco 1. Organizei tudo conforme o que seu auditor solicitou.

---

## 1. Schema de Banco de Dados - Amostra

### 1.1. Tabela `saas_tenants` (Isolamento Multi-Tenant)

**Arquivo SQL completo:** `apps/api/database/schema-saas-tables.sql`

Aqui está o script da tabela `saas_tenants`:

```sql
CREATE TABLE saas_tenants (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id VARCHAR(100) UNIQUE NOT NULL,  -- coluna tenant_id conforme solicitado
    name VARCHAR(255) NOT NULL,
    domain VARCHAR(255) UNIQUE,
    subdomain VARCHAR(100) UNIQUE,
    status VARCHAR(50) NOT NULL DEFAULT 'active',
    tier VARCHAR(50) DEFAULT 'standard',
    isolation_level VARCHAR(50) DEFAULT 'logical',  -- pode ser 'logical' ou 'physical'
    database_schema VARCHAR(100),  -- usado quando isolation_level = 'physical'
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

-- índice para garantir performance nas queries por tenant_id
CREATE INDEX idx_saas_tenants_tenant_id ON saas_tenants(tenant_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_saas_tenants_status ON saas_tenants(status) WHERE deleted_at IS NULL;
```

**Sobre o isolamento:**
A coluna `tenant_id` está implementada como NOT NULL, então é obrigatória. Temos índice único para garantir que não haja duplicatas. A tabela suporta tanto isolamento lógico (shared database) quanto físico (schema dedicado), dependendo da necessidade do tenant. A `system_audit_trail` também referencia essa tabela para manter o isolamento na auditoria.

---

### 1.2. Tabela `system_audit_trail` (Hash Chain)

**Arquivo SQL completo:** `apps/api/database/schema-saas-tables.sql`

Aqui está a tabela `system_audit_trail` com a implementação do hash chain:

```sql
CREATE TABLE system_audit_trail (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- hash chain conforme especificado
    prev_hash VARCHAR(64),  -- hash do registro anterior (NULL no primeiro)
    curr_hash VARCHAR(64) NOT NULL,  -- hash do registro atual (SHA-256)
    hash_chain_index BIGSERIAL,  -- índice sequencial na cadeia
    
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

-- trigger que calcula o hash automaticamente antes de inserir
CREATE TRIGGER set_audit_trail_hash_trigger
    BEFORE INSERT ON system_audit_trail
    FOR EACH ROW
    EXECUTE FUNCTION set_audit_trail_hash();

-- triggers que impedem modificação (garantem imutabilidade)
CREATE TRIGGER prevent_audit_trail_update
    BEFORE UPDATE ON system_audit_trail
    FOR EACH ROW
    EXECUTE FUNCTION prevent_audit_trail_modification();

CREATE TRIGGER prevent_audit_trail_delete
    BEFORE DELETE ON system_audit_trail
    FOR EACH ROW
    EXECUTE FUNCTION prevent_audit_trail_modification();
```

**Sobre o hash chain:**
As colunas `prev_hash` e `curr_hash` estão implementadas usando SHA-256. O trigger `set_audit_trail_hash_trigger` roda antes de cada INSERT e calcula o `curr_hash` automaticamente, incluindo o `prev_hash` do último registro do mesmo tenant. Isso forma a cadeia de hash.

Cada tenant tem sua própria cadeia (isolada pelo `tenant_id`). A função `validate_audit_hash_chain()` permite validar a integridade de toda a cadeia quando necessário.

A lógica de cálculo do hash concatena os campos principais:
```
hash_input = id || '|' || prev_hash || '|' || tenant_id || '|' || 
             event_type || '|' || action || '|' || user_id || '|' || 
             resource_type || '|' || resource_id || '|' || description || 
             '|' || details || '|' || created_at
curr_hash = SHA256(hash_input)
```

Os triggers de UPDATE e DELETE garantem que a tabela seja imutável - qualquer tentativa de modificar ou deletar um registro vai gerar uma exceção.

---

## 2. Segregação de Rede

### 2.1. Docker Compose

A configuração está em `infrastructure/docker/docker-compose.yml`. A rede isolada está configurada assim:

```yaml
networks:
  platform-network:
    driver: bridge
    ipam:
      config:
        - subnet: 172.28.0.0/16
```

Todos os serviços (postgres, redis, api, intelligence) estão conectados nessa rede isolada. A comunicação entre eles acontece apenas via DNS interno (usando os nomes dos serviços). O PostgreSQL e Redis não expõem portas diretamente para o host - só ficam acessíveis dentro da rede Docker.

Para validar, você pode rodar:
```bash
docker network inspect platform-network
docker exec platform-api ping -c 3 postgres
docker exec platform-api ping -c 3 redis
docker ps --format "table {{.Names}}\t{{.Ports}}"
```

### 2.2. Kubernetes

No Kubernetes, os serviços estão configurados como `ClusterIP` (arquivo `infrastructure/k8s/api/service.yaml`), o que significa que são acessíveis apenas dentro do cluster. O acesso externo é feito exclusivamente via Ingress, que está configurado com SSL/TLS obrigatório, rate limiting e health checks.

Para verificar:
```bash
kubectl get svc -n platform
kubectl get networkpolicies -n platform  # se houver policies aplicadas
kubectl get pods -n platform -o wide
```

---

## 3. Arquivos de Referência

Os scripts SQL completos estão em `apps/api/database/schema-saas-tables.sql`. Esse arquivo contém as duas tabelas (`saas_tenants` e `system_audit_trail`) com todos os triggers e funções.

As configurações de infraestrutura estão em:
- `infrastructure/docker/docker-compose.yml` - Docker
- `infrastructure/k8s/api/service.yaml` e `infrastructure/k8s/ingress.yaml` - Kubernetes

Também tem um script de validação em `scripts/validate-network-segregation.sh` caso queira testar a segregação de rede automaticamente.

---

## 4. Resumo de Conformidade

**Módulo 7 - Isolamento Multi-Tenant:**
- Tabela `saas_tenants` implementada com coluna `tenant_id` obrigatória
- Suporte a isolamento lógico e físico
- Índices configurados para performance

**Módulo 9 - Auditoria e Integridade:**
- Tabela `system_audit_trail` com hash chain (`prev_hash`/`curr_hash`)
- Triggers automáticos para cálculo de hash e proteção de imutabilidade
- Função de validação de integridade disponível
- Isolamento por tenant na cadeia de hash

**Segurança de Rede:**
- Rede Docker isolada com subnet dedicada
- Serviços Kubernetes como ClusterIP (acesso interno)
- Ingress com SSL/TLS, rate limiting e health checks

---

## 5. Próximos Passos

Para validar, sugiro:

1. Aplicar o schema SQL em um ambiente de teste e verificar se as tabelas e triggers foram criados corretamente
2. Rodar os comandos de validação de rede e capturar os resultados (screenshots ou logs)
3. Fazer alguns inserts de teste na `system_audit_trail` e verificar se o hash está sendo calculado corretamente. Depois rodar a função `validate_audit_hash_chain()` para confirmar a integridade da cadeia

---

## Conclusão

A infraestrutura está conforme o Manual do Mestre (Módulos 7 e 9). Temos:

- Isolamento multi-tenant com a tabela `saas_tenants` e a coluna `tenant_id`
- Hash chain de auditoria na `system_audit_trail` com `prev_hash` e `curr_hash`
- Segregação de rede configurada tanto no Docker quanto no Kubernetes

Aguardamos a validação do seu auditor para liberar o depósito.

Qualquer dúvida, é só avisar.

---

**Atenciosamente,**  
Equipe Técnica

---

**Anexos:**
- `apps/api/database/schema-saas-tables.sql` - Scripts SQL completos
- `docs/compliance/MARCO1_EVIDENCIAS_TECNICAS.md` - Documentação técnica detalhada

