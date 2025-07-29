```typescript
import { Request, Response } from 'express';
import { PrismaClient } from '@prisma/client';
import { validationResult } from 'express-validator';
import { AuthRequest } from '../types';
import { auditService } from '../services/auditService';

const prisma = new PrismaClient();

export class SoftwareController {
  // GET /api/softwares - List all softwares with optional filters
  static async list(req: AuthRequest, res: Response) {
    try {
      const {
        page = 1,
        limit = 50,
        search,
        hosting,
        acesso,
        sso,
        mfa,
        criticidade,
        ...filters
      } = req.query;

      const skip = (Number(page) - 1) * Number(limit);
      const take = Number(limit);

      // Build where clause for filtering
      const where: any = {};

      if (search) {
        where.OR = [
          { servico: { contains: search as string, mode: 'insensitive' } },
          { description: { contains: search as string, mode: 'insensitive' } },
          { url: { contains: search as string, mode: 'insensitive' } },
          { responsible: { contains: search as string, mode: 'insensitive' } },
        ];
      }

      // Apply specific filters
      if (hosting) where.hosting = hosting;
      if (acesso) where.acesso = acesso;
      if (sso) where.sso = sso;
      if (mfa) where.mfa = mfa;
      if (criticidade) where.criticidade = criticidade;

      // Apply any additional filters from query params
      Object.keys(filters).forEach(key => {
        if (filters[key] && key !== 'page' && key !== 'limit') {
          where[key] = filters[key];
        }
      });

      const [softwares, total] = await Promise.all([
        prisma.software.findMany({
          where,
          skip,
          take,
          include: {
            creator: {
              select: { id: true, name: true, email: true }
            },
            updater: {
              select: { id: true, name: true, email: true }
            }
          },
          orderBy: { createdAt: 'desc' }
        }),
        prisma.software.count({ where })
      ]);

      // Transform data to match frontend expectations
      const transformedSoftwares = softwares.map(software => ({
        id: software.id,
        servico: software.servico,
        description: software.description,
        url: software.url,
        hosting: software.hosting,
        acesso: software.acesso,
        responsible: software.responsible,
        namedUser: software.namedUser,
        integratedUser: software.integratedUser,
        sso: software.sso,
        onboarding: software.onboarding,
        offboarding: software.offboarding,
        offboardingType: software.offboardingType,
        affectedTeams: software.affectedTeams,
        logsInfo: software.logsInfo,
        logsRetention: software.logsRetention,
        logs: software.logsInfo, // Compatibility field
        mfaPolicy: software.mfaPolicy,
        mfa: software.mfa,
        mfaSMS: software.mfaSMS,
        bloqueio: software.regionBlock, // Compatibility field
        regionBlock: software.regionBlock,
        passwordPolicy: software.passwordPolicy,
        sensitiveData: software.sensitiveData,
        criticidade: software.criticidade,
        createdAt: software.createdAt,
        updatedAt: software.updatedAt,
        creator: software.creator,
        updater: software.updater
      }));

      res.json({
        data: transformedSoftwares,
        pagination: {
          page: Number(page),
          limit: Number(limit),
          total,
          pages: Math.ceil(total / Number(limit))
        }
      });

    } catch (error) {
      console.error('Error listing softwares:', error);
      res.status(500).json({
        error: 'Failed to fetch softwares',
        message: error instanceof Error ? error.message : 'Unknown error'
      });
    }
  }

  // GET /api/softwares/:id - Get single software
  static async getById(req: AuthRequest, res: Response) {
    try {
      const { id } = req.params;

      const software = await prisma.software.findUnique({
        where: { id },
        include: {
          creator: {
            select: { id: true, name: true, email: true }
          },
          updater: {
            select: { id: true, name: true, email: true }
          }
        }
      });

      if (!software) {
        return res.status(404).json({
          error: 'Software not found'
        });
      }

      res.json(software);

    } catch (error) {
      console.error('Error fetching software:', error);
      res.status(500).json({
        error: 'Failed to fetch software',
        message: error instanceof Error ? error.message : 'Unknown error'
      });
    }
  }

  // POST /api/softwares - Create new software
  static async create(req: AuthRequest, res: Response) {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({
          error: 'Validation failed',
          details: errors.array()
        });
      }

      const softwareData = {
        ...req.body,
        createdBy: req.user?.id,
        updatedBy: req.user?.id
      };

      const software = await prisma.software.create({
        data: softwareData,
        include: {
          creator: {
            select: { id: true, name: true, email: true }
          }
        }
      });

      // Log the creation
      await auditService.log({
        userId: req.user?.id,
        userName: req.user?.name || 'System',
        action: 'Criação de software',
        details: `Software '${software.servico}' foi criado`,
        type: 'create'
      });

      res.status(201).json(software);

    } catch (error) {
      console.error('Error creating software:', error);
      res.status(500).json({
        error: 'Failed to create software',
        message: error instanceof Error ? error.message : 'Unknown error'
      });
    }
  }

  // PUT /api/softwares/:id - Update software
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

      // Check if software exists
      const existingSoftware = await prisma.software.findUnique({
        where: { id }
      });

      if (!existingSoftware) {
        return res.status(404).json({
          error: 'Software not found'
        });
      }

      const updateData = {
        ...req.body,
        updatedBy: req.user?.id
      };

      const software = await prisma.software.update({
        where: { id },
        data: updateData,
        include: {
          creator: {
            select: { id: true, name: true, email: true }
          },
          updater: {
            select: { id: true, name: true, email: true }
          }
        }
      });

      // Log the update
      await auditService.log({
        userId: req.user?.id,
        userName: req.user?.name || 'System',
        action: 'Atualização de software',
        details: `Software '${software.servico}' foi atualizado`,
        type: 'update'
      });

      res.json(software);

    } catch (error) {
      console.error('Error updating software:', error);
      res.status(500).json({
        error: 'Failed to update software',
        message: error instanceof Error ? error.message : 'Unknown error'
      });
    }
  }

  // DELETE /api/softwares/:id - Delete software
  static async delete(req: AuthRequest, res: Response) {
    try {
      const { id } = req.params;

      // Check if software exists
      const existingSoftware = await prisma.software.findUnique({
        where: { id }
      });

      if (!existingSoftware) {
        return res.status(404).json({
          error: 'Software not found'
        });
      }

      await prisma.software.delete({
        where: { id }
      });

      // Log the deletion
      await auditService.log({
        userId: req.user?.id,
        userName: req.user?.name || 'System',
        action: 'Exclusão de software',
        details: `Software '${existingSoftware.servico}' foi removido`,
        type: 'delete'
      });

      res.status(204).send();

    } catch (error) {
      console.error('Error deleting software:', error);
      res.status(500).json({
        error: 'Failed to delete software',
        message: error instanceof Error ? error.message : 'Unknown error'
      });
    }
  }

  // GET /api/softwares/stats - Get dashboard statistics
  static async getStats(req: AuthRequest, res: Response) {
    try {
      const [
        total,
        cloudServices,
        mfaEnabled,
        criticidadeStats,
        hostingStats,
        securityStats
      ] = await Promise.all([
        prisma.software.count(),
        prisma.software.count({
          where: {
            hosting: {
              in: ['Cloud', 'SaaSPublico']
            }
          }
        }),
        prisma.software.count({
          where: { mfa: 'Habilitado' }
        }),
        prisma.software.groupBy({
          by: ['criticidade'],
          _count: true
        }),
        prisma.software.groupBy({
          by: ['hosting'],
          _count: true
        }),
        Promise.all([
          prisma.software.count({ where: { mfa: 'Habilitado' } }),
          prisma.software.count({ where: { sso: 'Integrado' } }),
          prisma.software.count({ where: { logsInfo: { not: 'NenhumLog' } } }),
          prisma.software.count({ where: { regionBlock: 'Sim' } })
        ])
      ]);

      const stats = {
        totalSoftwares: total,
        cloudServices,
        mfaEnabled,
        criticidade: criticidadeStats.reduce((acc: any, item) => {
          acc[item.criticidade] = item._count;
          return acc;
        }, {}),
        hosting: hostingStats.reduce((acc: any, item) => {
          acc[item.hosting] = item._count;
          return acc;
        }, {}),
        security: {
          mfaEnabled: securityStats[0],
          ssoIntegrated: securityStats[1],
          logsActive: securityStats[2],
          regionBlockEnabled: securityStats[3]
        }
      };

      res.json(stats);

    } catch (error) {
      console.error('Error fetching stats:', error);
      res.status(500).json({
        error: 'Failed to fetch statistics',
        message: error instanceof Error ? error.message : 'Unknown error'
      });
    }
  }

  // POST /api/softwares/export - Export softwares to CSV
  static async exportCSV(req: AuthRequest, res: Response) {
    try {
      const softwares = await prisma.software.findMany({
        include: {
          creator: { select: { name: true } },
          updater: { select: { name: true } }
        },
        orderBy: { createdAt: 'desc' }
      });

      // Transform data for CSV export
      const csvData = softwares.map(software => ({
        'ID': software.id,
        'Serviço/Plataforma': software.servico,
        'Descrição': software.description || '',
        'URL': software.url || '',
        'Hosting': software.hosting,
        'Acesso': software.acesso,
        'Responsável pelo Sistema': software.responsible || '',
        'Usuário Nomeado': software.namedUser || '',
        'Usuário Integrado': software.integratedUser || '',
        'SSO': software.sso,
        'Criação no Onboarding': software.onboarding || '',
        'Offboarding': software.offboarding || '',
        'Tipo do Offboarding': software.offboardingType || '',
        'Times Afetados': software.affectedTeams.join('; '),
        'Informações de Logs': software.logsInfo || '',
        'Retenção de Logs': software.logsRetention || '',
        'Política de MFA': software.mfaPolicy || '',
        'MFA': software.mfa,
        'MFA Habilitado por SMS': software.mfaSMS || '',
        'Bloqueio por Região': software.regionBlock || '',
        'Política de Complexidade de Senha': software.passwordPolicy || '',
        'Dados Sensíveis': software.sensitiveData || '',
        'Criticidade': software.criticidade,
        'Data de Criação': software.createdAt.toISOString(),
        'Criado por': software.creator?.name || ''
      }));

      // Log the export
      await auditService.log({
        userId: req.user?.id,
        userName: req.user?.name || 'System',
        action: 'Exportação de dados',
        details: `Exportação CSV de ${softwares.length} softwares realizada`,
        type: 'export'
      });

      res.json({
        data: csvData,
        count: softwares.length,
        exportedAt: new Date().toISOString()
      });

    } catch (error) {
      console.error('Error exporting softwares:', error);
      res.status(500).json({
        error: 'Failed to export softwares',
        message: error instanceof Error ? error.message : 'Unknown error'
      });
    }
  }
}
```
