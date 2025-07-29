import { Router } from 'express';
import { AuditController } from '../controllers/auditController';
import { authenticateToken, requireAdmin } from '../middleware/auth';

const router = Router();

// Routes
router.get('/', authenticateToken, requireAdmin, AuditController.getLogs);
router.get('/stats', authenticateToken, requireAdmin, AuditController.getStats);

export default router; 