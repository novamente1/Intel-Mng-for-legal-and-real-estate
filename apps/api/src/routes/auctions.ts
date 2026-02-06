import { Router, Request, Response } from 'express';
import { z } from 'zod';
import { asyncHandler, authenticate, requirePermission, validateRequest } from '../middleware';
import { getTenantContext } from '../utils/tenant-context';
import { NotFoundError, ValidationError, AuthorizationError } from '../utils/errors';
import { AuditService, AuditAction, AuditEventCategory } from '../services/audit';
import {
  AuctionAssetModel,
  AuctionBidModel,
  AUCTION_STAGES,
  type DueDiligenceItem,
  isRiskHigh,
} from '../models/auction-asset';

const router = Router();

const createAssetSchema = z.object({
  body: z.object({
    linked_document_ids: z.array(z.string().uuid()).optional(),
    asset_reference: z.string().max(255).optional(),
    title: z.string().max(500).optional(),
  }),
});

const transitionSchema = z.object({
  params: z.object({ id: z.string().uuid() }),
  body: z.object({ to_stage: z.enum([...AUCTION_STAGES] as [string, ...string[]]) }),
});

const dueDiligenceItemSchema = z.object({
  status: z.enum(['ok', 'risk', 'pending']),
  notes: z.string().nullable().optional(),
});
const updateDueDiligenceSchema = z.object({
  params: z.object({ id: z.string().uuid() }),
  body: z.object({
    occupancy: dueDiligenceItemSchema.optional(),
    debts: dueDiligenceItemSchema.optional(),
    legal_risks: dueDiligenceItemSchema.optional(),
    zoning: dueDiligenceItemSchema.optional(),
  }),
});

const placeBidSchema = z.object({
  params: z.object({ id: z.string().uuid() }),
  body: z.object({ amount_cents: z.number().int().positive() }),
});

const listSchema = z.object({
  query: z.object({
    stage: z.enum([...AUCTION_STAGES] as [string, ...string[]]).optional(),
    limit: z.string().transform(Number).optional(),
    offset: z.string().transform(Number).optional(),
  }),
});

/**
 * POST /auctions/assets
 * Create auction asset (tenant-scoped). Stage starts at F0.
 */
router.post(
  '/assets',
  authenticate,
  requirePermission('auctions:create'),
  validateRequest(createAssetSchema),
  asyncHandler(async (req: Request, res: Response) => {
    const { tenantId, userId } = getTenantContext(req);
    const { linked_document_ids, asset_reference, title } = req.body;

    const asset = await AuctionAssetModel.create({
      tenant_id: tenantId,
      linked_document_ids,
      asset_reference,
      title,
    });

    await AuditService.log({
      tenant_id: tenantId,
      event_type: 'auction_asset.create',
      event_category: AuditEventCategory.DATA_MODIFICATION,
      action: AuditAction.CREATE,
      user_id: userId,
      user_email: req.user!.email,
      user_role: req.context?.role,
      resource_type: 'auction_asset',
      resource_id: asset.id,
      description: 'Auction asset created',
      details: { initial_stage: 'F0' },
      ip_address: req.ip ?? req.socket?.remoteAddress,
      user_agent: req.get('user-agent'),
      request_id: req.headers['x-request-id'] as string | undefined,
      session_id: req.headers['x-session-id'] as string | undefined,
      success: true,
      compliance_flags: ['legal'],
      retention_category: 'legal',
    });

    res.status(201).json({
      success: true,
      data: formatAsset(asset),
    });
  })
);

/**
 * GET /auctions/assets
 * List auction assets for tenant. Optional filter by stage.
 */
router.get(
  '/assets',
  authenticate,
  requirePermission('auctions:read'),
  validateRequest(listSchema),
  asyncHandler(async (req: Request, res: Response) => {
    const { tenantId } = getTenantContext(req);
    const { stage, limit, offset } = req.query as { stage?: string; limit?: number; offset?: number };

    const assets = await AuctionAssetModel.listByTenant(tenantId, {
      stage: stage as typeof AUCTION_STAGES[number] | undefined,
      limit,
      offset,
    });

    res.json({
      success: true,
      data: { assets: assets.map(formatAsset), pagination: { limit: limit ?? 50, offset: offset ?? 0 } },
    });
  })
);

/**
 * GET /auctions/assets/:id
 * Get single asset (tenant-scoped).
 */
router.get(
  '/assets/:id',
  authenticate,
  requirePermission('auctions:read'),
  asyncHandler(async (req: Request, res: Response) => {
    const { tenantId } = getTenantContext(req);
    const { id } = req.params;

    const asset = await AuctionAssetModel.findById(id, tenantId);
    if (!asset) throw new NotFoundError('Auction asset');

    res.json({ success: true, data: formatAsset(asset) });
  })
);

/**
 * POST /auctions/assets/:id/transition
 * Move to next stage only (F0->F1->...->F9). Invalid transitions throw 400.
 * Audit every stage transition.
 */
router.post(
  '/assets/:id/transition',
  authenticate,
  requirePermission('auctions:update'),
  validateRequest(transitionSchema),
  asyncHandler(async (req: Request, res: Response) => {
    const { tenantId, userId } = getTenantContext(req);
    const { id } = req.params;
    const { to_stage } = req.body;

    const { asset, previous_stage } = await AuctionAssetModel.transitionStage(id, tenantId, to_stage);

    await AuditService.log({
      tenant_id: tenantId,
      event_type: 'auction_asset.stage_transition',
      event_category: AuditEventCategory.DATA_MODIFICATION,
      action: AuditAction.UPDATE,
      user_id: userId,
      user_email: req.user!.email,
      user_role: req.context?.role,
      resource_type: 'auction_asset',
      resource_id: id,
      description: `Auction asset stage transition ${previous_stage} -> ${to_stage}`,
      details: { from_stage: previous_stage, to_stage },
      ip_address: req.ip ?? req.socket?.remoteAddress,
      user_agent: req.get('user-agent'),
      request_id: req.headers['x-request-id'] as string | undefined,
      session_id: req.headers['x-session-id'] as string | undefined,
      success: true,
      compliance_flags: ['legal'],
      retention_category: 'legal',
    });

    res.json({
      success: true,
      data: { asset: formatAsset(asset), previous_stage, to_stage },
    });
  })
);

/**
 * PUT /auctions/assets/:id/due-diligence
 * Update due diligence checklist (occupancy, debts, legal_risks, zoning). Risk score recalculated.
 */
router.put(
  '/assets/:id/due-diligence',
  authenticate,
  requirePermission('auctions:update'),
  validateRequest(updateDueDiligenceSchema),
  asyncHandler(async (req: Request, res: Response) => {
    const { tenantId } = getTenantContext(req);
    const { id } = req.params;
    const { occupancy, debts, legal_risks, zoning } = req.body;

    const input: {
      occupancy?: DueDiligenceItem;
      debts?: DueDiligenceItem;
      legal_risks?: DueDiligenceItem;
      zoning?: DueDiligenceItem;
    } = {};
    if (occupancy) input.occupancy = occupancy as DueDiligenceItem;
    if (debts) input.debts = debts as DueDiligenceItem;
    if (legal_risks) input.legal_risks = legal_risks as DueDiligenceItem;
    if (zoning) input.zoning = zoning as DueDiligenceItem;

    const asset = await AuctionAssetModel.updateDueDiligence(id, tenantId, input);

    res.json({
      success: true,
      data: {
        asset: formatAsset(asset),
        risk_score: asset.risk_score,
        risk_level: isRiskHigh(asset.risk_score) ? 'HIGH' : asset.risk_score >= 40 ? 'MEDIUM' : 'LOW',
      },
    });
  })
);

/**
 * GET /auctions/assets/:id/risk
 * Get risk score and level (LOW/MEDIUM/HIGH). HIGH disables bidding at API.
 */
router.get(
  '/assets/:id/risk',
  authenticate,
  requirePermission('auctions:read'),
  asyncHandler(async (req: Request, res: Response) => {
    const { tenantId } = getTenantContext(req);
    const { id } = req.params;

    const asset = await AuctionAssetModel.findById(id, tenantId);
    if (!asset) throw new NotFoundError('Auction asset');

    const high = isRiskHigh(asset.risk_score);
    res.json({
      success: true,
      data: {
        risk_score: asset.risk_score,
        risk_level: high ? 'HIGH' : asset.risk_score >= 40 ? 'MEDIUM' : 'LOW',
        bidding_disabled: high,
      },
    });
  })
);

/**
 * POST /auctions/assets/:id/bids
 * Place a bid. API enforces: bidding disabled when risk is HIGH (403).
 */
router.post(
  '/assets/:id/bids',
  authenticate,
  requirePermission('auctions:bid'),
  validateRequest(placeBidSchema),
  asyncHandler(async (req: Request, res: Response) => {
    const { tenantId, userId } = getTenantContext(req);
    const { id } = req.params;
    const { amount_cents } = req.body;

    const asset = await AuctionAssetModel.findById(id, tenantId);
    if (!asset) throw new NotFoundError('Auction asset');

    if (isRiskHigh(asset.risk_score)) {
      throw new AuthorizationError(
        'Bidding is disabled for this asset due to HIGH risk score. Complete due diligence to lower risk.'
      );
    }

    const bid = await AuctionBidModel.create(tenantId, id, userId, amount_cents);

    await AuditService.log({
      tenant_id: tenantId,
      event_type: 'auction_bid.create',
      event_category: AuditEventCategory.DATA_MODIFICATION,
      action: AuditAction.CREATE,
      user_id: userId,
      user_email: req.user!.email,
      user_role: req.context?.role,
      resource_type: 'auction_bid',
      resource_id: bid.id,
      target_resource_id: id,
      description: 'Auction bid placed',
      details: { amount_cents, asset_id: id },
      ip_address: req.ip ?? req.socket?.remoteAddress,
      user_agent: req.get('user-agent'),
      request_id: req.headers['x-request-id'] as string | undefined,
      session_id: req.headers['x-session-id'] as string | undefined,
      success: true,
      compliance_flags: ['legal'],
      retention_category: 'legal',
    });

    res.status(201).json({
      success: true,
      data: { id: bid.id, amount_cents },
    });
  })
);

function formatAsset(asset: {
  id: string;
  current_stage: string;
  linked_document_ids: string[];
  due_diligence_checklist: unknown;
  risk_score: number;
  asset_reference: string | null;
  title: string | null;
  created_at: Date;
  updated_at: Date;
}) {
  return {
    id: asset.id,
    current_stage: asset.current_stage,
    linked_document_ids: asset.linked_document_ids,
    due_diligence_checklist: asset.due_diligence_checklist,
    risk_score: asset.risk_score,
    risk_level: isRiskHigh(asset.risk_score) ? 'HIGH' : asset.risk_score >= 40 ? 'MEDIUM' : 'LOW',
    bidding_disabled: isRiskHigh(asset.risk_score),
    asset_reference: asset.asset_reference,
    title: asset.title,
    created_at: asset.created_at,
    updated_at: asset.updated_at,
  };
}

export default router;
