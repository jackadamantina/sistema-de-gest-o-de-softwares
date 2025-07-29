import { PrismaClient } from '@prisma/client';
import { AuditLogData } from '../types';

const prisma = new PrismaClient();

export class AuditService {
  static async log(data: AuditLogData) {
    try {
      await prisma.auditLog.create({
        data: {
          userId: data.userId,
          userName: data.userName,
          action: data.action,
          details: data.details,
          type: data.type as any
        }
      });
    } catch (error) {
      console.error('Error logging audit:', error);
      // Não falhar a operação principal por erro de log
    }
  }

  static async getLogs(filters: {
    userId?: string;
    userName?: string;
    type?: string;
    startDate?: Date;
    endDate?: Date;
    page?: number;
    limit?: number;
  }) {
    const { userId, userName, type, startDate, endDate, page = 1, limit = 50 } = filters;
    const skip = (page - 1) * limit;

    const where: any = {};

    if (userId) where.userId = userId;
    if (userName) where.userName = { contains: userName, mode: 'insensitive' };
    if (type) where.type = type;
    if (startDate || endDate) {
      where.createdAt = {};
      if (startDate) where.createdAt.gte = startDate;
      if (endDate) where.createdAt.lte = endDate;
    }

    const [logs, total] = await Promise.all([
      prisma.auditLog.findMany({
        where,
        skip,
        take: limit,
        orderBy: { createdAt: 'desc' },
        include: {
          user: {
            select: {
              id: true,
              name: true,
              email: true
            }
          }
        }
      }),
      prisma.auditLog.count({ where })
    ]);

    return {
      data: logs,
      pagination: {
        page,
        limit,
        total,
        pages: Math.ceil(total / limit)
      }
    };
  }

  static async getStats() {
    const [
      totalLogs,
      todayLogs,
      userStats,
      actionStats
    ] = await Promise.all([
      prisma.auditLog.count(),
      prisma.auditLog.count({
        where: {
          createdAt: {
            gte: new Date(new Date().setHours(0, 0, 0, 0))
          }
        }
      }),
      prisma.auditLog.groupBy({
        by: ['userName'],
        _count: true,
        orderBy: {
          _count: {
            userName: 'desc'
          }
        },
        take: 10
      }),
      prisma.auditLog.groupBy({
        by: ['type'],
        _count: true
      })
    ]);

    return {
      totalLogs,
      todayLogs,
      userStats: userStats.map(stat => ({
        userName: stat.userName,
        count: stat._count
      })),
      actionStats: actionStats.map(stat => ({
        type: stat.type,
        count: stat._count
      }))
    };
  }
}

export const auditService = AuditService; 