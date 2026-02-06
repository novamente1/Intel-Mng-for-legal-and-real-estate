'use client';

import { useParams, useSearchParams } from 'next/navigation';
import { DocumentViewer } from '@/components/DocumentViewer';
import { fetchViewerContext, fetchViewerAssetBlob } from '@/lib/api';

/**
 * Secure, no-download document viewer.
 * - Embedded PDF viewer (no direct file URLs; asset streamed via API)
 * - Download/print/copy disabled
 * - Dynamic watermark: user email, user id, IP, timestamp
 * - Optional fact highlight (bounding box) when opened from fact source (?fact_id=)
 * - Access requires tenant_id + RBAC (enforced by API); ACCESS events logged via AuditService
 */
export default function DocumentViewPage() {
  const params = useParams();
  const searchParams = useSearchParams();
  const documentId = params?.id as string;
  const factId = searchParams?.get('fact_id') ?? null;

  if (!documentId) {
    return (
      <div style={{ padding: 24 }}>
        <p>Missing document ID.</p>
      </div>
    );
  }

  return (
    <div className="viewer-page" style={{ width: '100%', minHeight: '100vh' }}>
      <DocumentViewer
        documentId={documentId}
        factId={factId}
        fetchContext={fetchViewerContext}
        fetchAsset={fetchViewerAssetBlob}
      />
    </div>
  );
}
