import { Request, Response } from 'express';
import bcrypt from 'bcryptjs';
import { PrismaClient } from '@prisma/client';
import { validationResult } from 'express-validator';
import { AuthRequest } from '../types';
import { auditService } from '../services/auditService';

const prisma = new PrismaClient();

export class UserController {
  // GET /api/users - List all users
  static async list(req: AuthRequest, res: Response) {
    try {
      const {
        page = 1,
        limit = 50,
        search,
        role,
        status,
        ...filters
      } = req.query;

      const skip = (Number(page) - 1) * Number(limit);
      const take = Number(limit);

      // Build where clause for filtering
      const where: any = {};

      if (search) {
        where.OR = [
          { name: { contains: search as string, mode: 'insensitive' } },
          { email: { contains: search as string, mode: 'insensitive' } },
        ];
      }

      // Apply specific filters
      if (role) where.role = role;
      if (status) where.status = status;

      // Apply any additional filters from query params
      Object.keys(filters).forEach(key => {
        if (filters[key] && key !== 'page' && key !== 'limit') {
          where[key] = filters[key];
        }
      });

      const [users, total] = await Promise.all([
        prisma.user.findMany({
          where,
          skip,
          take,
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
          },
          orderBy: { createdAt: 'desc' }
        }),
        prisma.user.count({ where })
      ]);

      res.json({
        users,
        pagination: {
          page: Number(page),
          limit: Number(limit),
          total,
          pages: Math.ceil(total / Number(limit))
        }
      });

    } catch (error) {
      console.error('List users error:', error);
      res.status(500).json({
        error: 'Failed to list users',
        message: error instanceof Error ? error.message : 'Unknown error'
      });
    }
  }

  // GET /api/users/:id - Get user by ID
  static async getById(req: AuthRequest, res: Response) {
    try {
      const { id } = req.params;

      const user = await prisma.user.findUnique({
        where: { id: id },
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
      console.error('Get user error:', error);
      res.status(500).json({
        error: 'Failed to get user',
        message: error instanceof Error ? error.message : 'Unknown error'
      });
    }
  }

  // POST /api/users - Create new user
  static async create(req: AuthRequest, res: Response) {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({
          error: 'Validation failed',
          details: errors.array()
        });
      }

      const { name, email, role, status, password } = req.body;

      // Check if email already exists
      const existingUser = await prisma.user.findUnique({
        where: { email: email.toLowerCase() }
      });

      if (existingUser) {
        return res.status(400).json({
          error: 'Email already in use'
        });
      }

      // Hash password
      const saltRounds = 12;
      const passwordHash = await bcrypt.hash(password, saltRounds);

      // Generate avatar from name
      const avatar = name.split(' ')
        .map((n: string) => n[0])
        .join('')
        .toUpperCase()
        .substring(0, 2);

      const user = await prisma.user.create({
        data: {
          name,
          email: email.toLowerCase(),
          role,
          status,
          passwordHash,
          avatar
        },
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

      // Log user creation
      if (req.user) {
        await auditService.log({
          userId: req.user.id,
          userName: req.user.name,
          action: 'Criação de usuário',
          details: `Usuário '${user.name}' foi criado com perfil ${user.role}`,
          type: 'create'
        });
      }

      res.status(201).json(user);

    } catch (error) {
      console.error('Create user error:', error);
      res.status(500).json({
        error: 'Failed to create user',
        message: error instanceof Error ? error.message : 'Unknown error'
      });
    }
  }

  // PUT /api/users/:id - Update user
  static async update(req: AuthRequest, res: Response) {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({
          error: 'Validation failed',
          details: errors.array()
        });
      }

      const { id } = req.params;
      const { name, email, role, status } = req.body;

      // Check if user exists
      const existingUser = await prisma.user.findUnique({
        where: { id: id }
      });

      if (!existingUser) {
        return res.status(404).json({
          error: 'User not found'
        });
      }

      // Check if email is already taken by another user
      if (email && email !== existingUser.email) {
        const emailExists = await prisma.user.findUnique({
          where: { email: email.toLowerCase() }
        });

        if (emailExists) {
          return res.status(400).json({
            error: 'Email already in use'
          });
        }
      }

      // Generate new avatar if name changed
      const avatar = name ? name.split(' ')
        .map((n: string) => n[0])
        .join('')
        .toUpperCase()
        .substring(0, 2) : existingUser.avatar;

      const updateData: any = {};
      if (name) updateData.name = name;
      if (email) updateData.email = email.toLowerCase();
      if (role) updateData.role = role;
      if (status) updateData.status = status;
      if (name) updateData.avatar = avatar;

      const user = await prisma.user.update({
        where: { id: id },
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

      // Log user update
      if (req.user) {
        await auditService.log({
          userId: req.user.id,
          userName: req.user.name,
          action: 'Atualização de usuário',
          details: `Usuário '${user.name}' foi atualizado`,
          type: 'update'
        });
      }

      res.json(user);

    } catch (error) {
      console.error('Update user error:', error);
      res.status(500).json({
        error: 'Failed to update user',
        message: error instanceof Error ? error.message : 'Unknown error'
      });
    }
  }

  // PUT /api/users/:id/reset-password - Reset user password
  static async resetPassword(req: AuthRequest, res: Response) {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({
          error: 'Validation failed',
          details: errors.array()
        });
      }

      const { id } = req.params;
      const { newPassword } = req.body;

      // Check if user exists
      const existingUser = await prisma.user.findUnique({
        where: { id: id }
      });

      if (!existingUser) {
        return res.status(404).json({
          error: 'User not found'
        });
      }

      // Hash new password
      const saltRounds = 12;
      const passwordHash = await bcrypt.hash(newPassword, saltRounds);

      await prisma.user.update({
        where: { id: id },
        data: { passwordHash }
      });

      // Log password reset
      if (req.user) {
        await auditService.log({
          userId: req.user.id,
          userName: req.user.name,
          action: 'Reset de senha',
          details: `Senha do usuário '${existingUser.name}' foi resetada`,
          type: 'update'
        });
      }

      res.json({
        message: 'Password reset successfully'
      });

    } catch (error) {
      console.error('Reset password error:', error);
      res.status(500).json({
        error: 'Failed to reset password',
        message: error instanceof Error ? error.message : 'Unknown error'
      });
    }
  }

  // DELETE /api/users/:id - Delete user
  static async delete(req: AuthRequest, res: Response) {
    try {
      const { id } = req.params;

      // Check if user exists
      const existingUser = await prisma.user.findUnique({
        where: { id: id }
      });

      if (!existingUser) {
        return res.status(404).json({
          error: 'User not found'
        });
      }

      // Prevent deleting the current user
      if (req.user && req.user.id === id) {
        return res.status(400).json({
          error: 'Cannot delete your own account'
        });
      }

      await prisma.user.delete({
        where: { id: id }
      });

      // Log user deletion
      if (req.user) {
        await auditService.log({
          userId: req.user.id,
          userName: req.user.name,
          action: 'Exclusão de usuário',
          details: `Usuário '${existingUser.name}' foi removido do sistema`,
          type: 'delete'
        });
      }

      res.json({
        message: 'User deleted successfully'
      });

    } catch (error) {
      console.error('Delete user error:', error);
      res.status(500).json({
        error: 'Failed to delete user',
        message: error instanceof Error ? error.message : 'Unknown error'
      });
    }
  }

  // GET /api/users/stats - Get user statistics
  static async getStats(req: AuthRequest, res: Response) {
    try {
      const [totalUsers, activeUsers, inactiveUsers, adminUsers, editorUsers, viewerUsers] = await Promise.all([
        prisma.user.count(),
        prisma.user.count({ where: { status: 'Ativo' } }),
        prisma.user.count({ where: { status: 'Inativo' } }),
        prisma.user.count({ where: { role: 'Admin' } }),
        prisma.user.count({ where: { role: 'Editor' } }),
        prisma.user.count({ where: { role: 'Visualizador' } })
      ]);

      res.json({
        totalUsers,
        activeUsers,
        inactiveUsers,
        adminUsers,
        editorUsers,
        viewerUsers,
        activePercentage: totalUsers > 0 ? Math.round((activeUsers / totalUsers) * 100) : 0
      });

    } catch (error) {
      console.error('Get user stats error:', error);
      res.status(500).json({
        error: 'Failed to get user statistics',
        message: error instanceof Error ? error.message : 'Unknown error'
      });
    }
  }
} 