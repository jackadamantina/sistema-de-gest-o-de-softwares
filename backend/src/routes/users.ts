import { Router } from 'express';
import { body } from 'express-validator';
import { UserController } from '../controllers/userController';
import { authenticateToken, requireRole } from '../middleware/auth';

const router = Router();

// Validation rules
const userValidation = [
  body('name').notEmpty().withMessage('Nome é obrigatório'),
  body('email').isEmail().withMessage('Email inválido'),
  body('role').isIn(['Admin', 'Editor', 'Visualizador']).withMessage('Perfil inválido'),
  body('status').isIn(['Ativo', 'Inativo']).withMessage('Status inválido')
];

const createUserValidation = [
  ...userValidation,
  body('password').isLength({ min: 6 }).withMessage('Senha deve ter pelo menos 6 caracteres')
];

const resetPasswordValidation = [
  body('newPassword').isLength({ min: 6 }).withMessage('Nova senha deve ter pelo menos 6 caracteres')
];

// Apply authentication middleware to all routes
router.use(authenticateToken);

// GET /api/users - List all users
router.get('/', requireRole(['Admin']), UserController.list);

// GET /api/users/stats - Get user statistics
router.get('/stats', requireRole(['Admin']), UserController.getStats);

// GET /api/users/:id - Get user by ID
router.get('/:id', requireRole(['Admin']), UserController.getById);

// POST /api/users - Create new user
router.post('/', requireRole(['Admin']), createUserValidation, UserController.create);

// PUT /api/users/:id - Update user
router.put('/:id', requireRole(['Admin']), userValidation, UserController.update);

// PUT /api/users/:id/reset-password - Reset user password
router.put('/:id/reset-password', requireRole(['Admin']), resetPasswordValidation, UserController.resetPassword);

// DELETE /api/users/:id - Delete user
router.delete('/:id', requireRole(['Admin']), UserController.delete);

export default router; 