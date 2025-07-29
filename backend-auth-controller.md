```typescript
import { Request, Response } from 'express';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { PrismaClient } from '@prisma/client';
import { validationResult } from 'express-validator';
import { AuthRequest } from '../types';
import { auditService } from '../services/auditService';

const prisma = new PrismaClient();

export class AuthController {
  // POST /api/auth/login - User login
  static async login(req: Request, res: Response) {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({
          error: 'Validation failed',
          details: errors.array()
        });
      }

      const { email, password } = req.body;

      // Find user by email
      const user = await prisma.user.findUnique({
        where: { email: email.toLowerCase() },
        select: {
          id: true,
          name: true,
          email: true,
          passwordHash: true,
          role: true,
          status: true,
          avatar: true,
          lastAccess: true
        }
      });

      if (!user) {
        return res.status(401).json({
          error: 'Invalid credentials'
        });
      }

      // Check if user is active
      if (user.status !== 'Ativo') {
        return res.status(401).json({
          error: 'Account is inactive'
        });
      }

      // Verify password
      const isValidPassword = await bcrypt.compare(password, user.passwordHash);
      if (!isValidPassword) {
        return res.status(401).json({
          error: 'Invalid credentials'
        });
      }

      // Update last access
      await prisma.user.update({
        where: { id: user.id },
        data: { lastAccess: new Date() }
      });

      // Generate JWT token
      const token = jwt.sign(
        {
          id: user.id,
          email: user.email,
          role: user.role
        },
        process.env.JWT_SECRET!,
        { 
          expiresIn: process.env.JWT_EXPIRES_IN || '24h',
          issuer: 'softwarehub',
          audience: 'softwarehub-client'
        }
      );

      // Log successful login
      await auditService.log({
        userId: user.id,
        userName: user.name,
        action: 'Login',
        details: `Login realizado por ${user.name}`,
        type: 'login'
      });

      // Remove sensitive data
      const { passwordHash, ...userResponse } = user;

      res.json({
        message: 'Login successful',
        user: userResponse,
        token,
        expiresIn: process.env.JWT_EXPIRES_IN || '24h'
      });

    } catch (error) {
      console.error('Login error:', error);
      res.status(500).json({
        error: 'Login failed',
        message: error instanceof Error ? error.message : 'Unknown error'
      });
    }
  }

  // POST /api/auth/logout - User logout
  static async logout(req: AuthRequest, res: Response) {
    try {
      // Log logout
      if (req.user) {
        await auditService.log({
          userId: req.user.id,
          userName: req.user.name,
          action: 'Logout',
          details: `Logout realizado por ${req.user.name}`,
          type: 'login'
        });
      }

      res.json({
        message: 'Logout successful'
      });

    } catch (error) {
      console.error('Logout error:', error);
      res.status(500).json({
        error: 'Logout failed',
        message: error instanceof Error ? error.message : 'Unknown error'
      });
    }
  }

  // GET /api/auth/me - Get current user info
  static async getProfile(req: AuthRequest, res: Response) {
    try {
      if (!req.user) {
        return res.status(401).json({
          error: 'Not authenticated'
        });
      }

      const user = await prisma.user.findUnique({
        where: { id: req.user.id },
        select: {
          id: true,
          name: true,
          email: true,
          role: true,
          status: true,
          avatar: true,
          lastAccess: true,
          createdAt: true,
          updatedAt: true
        }
      });

      if (!user) {
        return res.status(404).json({
          error: 'User not found'
        });
      }

      res.json(user);

    } catch (error) {
      console.error('Profile fetch error:', error);
      res.status(500).json({
        error: 'Failed to fetch profile',
        message: error instanceof Error ? error.message : 'Unknown error'
      });
    }
  }

  // PUT /api/auth/profile - Update current user profile
  static async updateProfile(req: AuthRequest, res: Response) {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({
          error: 'Validation failed',
          details: errors.array()
        });
      }

      if (!req.user) {
        return res.status(401).json({
          error: 'Not authenticated'
        });
      }

      const { name, email } = req.body;

      // Check if email is already taken by another user
      if (email && email !== req.user.email) {
        const existingUser = await prisma.user.findUnique({
          where: { email: email.toLowerCase() }
        });

        if (existingUser && existingUser.id !== req.user.id) {
          return res.status(400).json({
            error: 'Email already in use'
          });
        }
      }

      const updateData: any = {};
      if (name) updateData.name = name;
      if (email) updateData.email = email.toLowerCase();

      // Generate new avatar if name changed
      if (name) {
        updateData.avatar = name.split(' ')
          .map(n => n[0])
          .join('')
          .toUpperCase()
          .substring(0, 2);
      }

      const updatedUser = await prisma.user.update({
        where: { id: req.user.id },
        data: updateData,
        select: {
          id: true,
          name: true,
          email: true,
          role: true,
          status: true,
          avatar: true,
          lastAccess: true,
          createdAt: true,
          updatedAt: true
        }
      });

      // Log profile update
      await auditService.log({
        userId: req.user.id,
        userName: req.user.name,
        action: 'Atualização de perfil',
        details: `Perfil do usuário ${req.user.name} foi atualizado`,
        type: 'update'
      });

      res.json(updatedUser);

    } catch (error) {
      console.error('Profile update error:', error);
      res.status(500).json({
        error: 'Failed to update profile',
        message: error instanceof Error ? error.message : 'Unknown error'
      });
    }
  }

  // PUT /api/auth/password - Change password
  static async changePassword(req: AuthRequest, res: Response) {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({
          error: 'Validation failed',
          details: errors.array()
        });
      }

      if (!req.user) {
        return res.status(401).json({
          error: 'Not authenticated'
        });
      }

      const { currentPassword, newPassword } = req.body;

      // Get current user with password
      const user = await prisma.user.findUnique({
        where: { id: req.user.id },
        select: {
          id: true,
          name: true,
          passwordHash: true
        }
      });

      if (!user) {
        return res.status(404).json({
          error: 'User not found'
        });
      }

      // Verify current password
      const isValidCurrentPassword = await bcrypt.compare(currentPassword, user.passwordHash);
      if (!isValidCurrentPassword) {
        return res.status(400).json({
          error: 'Current password is incorrect'
        });
      }

      // Hash new password
      const saltRounds = 12;
      const newPasswordHash = await bcrypt.hash(newPassword, saltRounds);

      // Update password
      await prisma.user.update({
        where: { id: req.user.id },
        data: { passwordHash: newPasswordHash }
      });

      // Log password change
      await auditService.log({
        userId: req.user.id,
        userName: req.user.name,
        action: 'Alteração de senha',
        details: `Senha do usuário ${req.user.name} foi alterada`,
        type: 'update'
      });

      res.json({
        message: 'Password changed successfully'
      });

    } catch (error) {
      console.error('Password change error:', error);
      res.status(500).json({
        error: 'Failed to change password',
        message: error instanceof Error ? error.message : 'Unknown error'
      });
    }
  }

  // POST /api/auth/refresh - Refresh JWT token
  static async refreshToken(req: AuthRequest, res: Response) {
    try {
      if (!req.user) {
        return res.status(401).json({
          error: 'Not authenticated'
        });
      }

      // Verify user still exists and is active
      const user = await prisma.user.findUnique({
        where: { id: req.user.id },
        select: {
          id: true,
          name: true,
          email: true,
          role: true,
          status: true
        }
      });

      if (!user || user.status !== 'Ativo') {
        return res.status(401).json({
          error: 'User not found or inactive'
        });
      }

      // Generate new token
      const token = jwt.sign(
        {
          id: user.id,
          email: user.email,
          role: user.role
        },
        process.env.JWT_SECRET!,
        { 
          expiresIn: process.env.JWT_EXPIRES_IN || '24h',
          issuer: 'softwarehub',
          audience: 'softwarehub-client'
        }
      );

      res.json({
        token,
        expiresIn: process.env.JWT_EXPIRES_IN || '24h'
      });

    } catch (error) {
      console.error('Token refresh error:', error);
      res.status(500).json({
        error: 'Failed to refresh token',
        message: error instanceof Error ? error.message : 'Unknown error'
      });
    }
  }

  // POST /api/auth/validate - Validate token
  static async validateToken(req: AuthRequest, res: Response) {
    try {
      if (!req.user) {
        return res.status(401).json({
          error: 'Invalid or expired token',
          valid: false
        });
      }

      res.json({
        valid: true,
        user: {
          id: req.user.id,
          name: req.user.name,
          email: req.user.email,
          role: req.user.role
        }
      });

    } catch (error) {
      console.error('Token validation error:', error);
      res.status(500).json({
        error: 'Token validation failed',
        valid: false,
        message: error instanceof Error ? error.message : 'Unknown error'
      });
    }
  }
}
```
