import { Router } from 'express';
import { body } from 'express-validator';
import { AuthController } from '../controllers/authController';
import { authenticateToken } from '../middleware/auth';

const router = Router();

// Validation rules
const loginValidation = [
  body('email').isEmail().normalizeEmail(),
  body('password').isLength({ min: 1 })
];

const profileValidation = [
  body('name').optional().isLength({ min: 2, max: 255 }),
  body('email').optional().isEmail().normalizeEmail()
];

const passwordValidation = [
  body('currentPassword').isLength({ min: 1 }),
  body('newPassword').isLength({ min: 6 })
];

// Routes
router.post('/login', loginValidation, AuthController.login);
router.post('/logout', authenticateToken, AuthController.logout);
router.get('/me', authenticateToken, AuthController.getProfile);
router.put('/profile', authenticateToken, profileValidation, AuthController.updateProfile);
router.put('/password', authenticateToken, passwordValidation, AuthController.changePassword);
router.post('/refresh', authenticateToken, AuthController.refreshToken);
router.post('/validate', authenticateToken, AuthController.validateToken);

export default router; 