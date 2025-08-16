import { Router } from 'express';
import { body } from 'express-validator';
import { SoftwareController } from '../controllers/softwareController';
import { authenticateToken, requireEditor } from '../middleware/auth';

const router = Router();

// Validation rules
const softwareValidation = [
  body('servico').notEmpty().withMessage('Serviço/Plataforma é obrigatório').isLength({ min: 1, max: 255 }),
  body('hosting').notEmpty().withMessage('Hosting é obrigatório').isIn(['OnPremises', 'Cloud', 'Cloudstack', 'SaaSPublico']),
  body('acesso').optional().isIn(['Interno', 'Externo']),
  body('sso').optional().isIn(['Aplicavel', 'Integrado', 'PossivelUpgrade', 'SemPossibilidade', 'Desenvolver']),
  body('mfa').optional().isIn(['NaoTemPossibilidade', 'Habilitado', 'NaoAplicavel']),
  body('criticidade').optional().isIn(['Alta', 'Media', 'Baixa']),
  body('url').optional().isLength({ max: 500 }),
  body('description').optional().isLength({ max: 1000 }),
  body('responsible').optional().isLength({ max: 500 }),
  body('namedUser').optional().isIn(['Sim', 'SemAutenticacao', 'Nao']),
  body('integratedUser').optional().isIn(['Sim', 'Nao', 'Integrador', 'Ambos']),
  body('onboarding').optional().isLength({ max: 1000 }),
  body('offboarding').optional().isIn(['RemoverManual', 'RemocaoAutomatica', 'NA']),
  body('offboardingType').optional().isIn(['Alta', 'Media', 'Baixa']),
  body('affectedTeams').optional().isArray(),
  body('logsInfo').optional().isIn(['LogsAcesso', 'LogsSistema', 'Ambos', 'NenhumLog']),
  body('logsRetention').optional().isIn(['Nenhum', 'Semanal', 'Mensal', 'Diario']),
  body('mfaPolicy').optional().isIn(['Sim', 'Nao', 'NaoAplicavel']),
  body('mfaSMS').optional().isIn(['Nao', 'Sim']),
  body('regionBlock').optional().isIn(['Sim', 'Nao', 'NaoAplicavel', 'NaoPossuiFuncionalidade']),
  body('passwordPolicy').optional().isIn(['Sim', 'Nao']),
  body('sensitiveData').optional().isIn(['Sim', 'Nao'])
];

// Routes
router.get('/', authenticateToken, SoftwareController.list);
router.get('/stats', authenticateToken, SoftwareController.getStats);
router.get('/:id', authenticateToken, SoftwareController.getById);
router.post('/', authenticateToken, requireEditor, softwareValidation, SoftwareController.create);
router.put('/:id', authenticateToken, requireEditor, softwareValidation, SoftwareController.update);
router.delete('/:id', authenticateToken, requireEditor, SoftwareController.delete);
router.post('/export', authenticateToken, SoftwareController.exportCSV);

export default router; 