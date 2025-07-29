import { Response } from 'express';
import { AuthRequest } from '../types';
import { auditService } from '../services/auditService';

export class AuditController {
  // GET /api/audit - Get audit logs with filters
  static async getLogs(req: AuthRequest, res: Response) {
    try {
      const {
        page = 1,
        limit = 50,
        userId,
        userName,
        type,
        startDate,
        endDate
      } = req.query;

      const filters = {
        userId: userId as string,
        userName: userName as string,
        type: type as string,
        startDate: startDate ? new Date(startDate as string) : undefined,
        endDate: endDate ? new Date(endDate as string) : undefined,
        page: Number(page),
        limit: Number(limit)
      };

      const result = await auditService.getLogs(filters);

      res.json(result);

    } catch (error) {
      console.error('Error fetching audit logs:', error);
      res.status(500).json({
        error: 'Failed to fetch audit logs',
        message: error instanceof Error ? error.message : 'Unknown error'
      });
    }
  }

  // GET /api/audit/stats - Get audit statistics
  static async getStats(req: AuthRequest, res: Response) {
    try {
      const stats = await auditService.getStats();

      res.json(stats);

    } catch (error) {
      console.error('Error fetching audit stats:', error);
      res.status(500).json({
        error: 'Failed to fetch audit statistics',
        message: error instanceof Error ? error.message : 'Unknown error'
      });
    }
  }
} 