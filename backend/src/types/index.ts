import { Request } from 'express';

export interface AuthRequest extends Request {
  user?: {
    id: string;
    name: string;
    email: string;
    role: string;
  };
}

export interface SoftwareData {
  id?: string;
  servico: string;
  description?: string;
  url?: string;
  hosting: string;
  acesso: string;
  responsible?: string;
  namedUser?: string;
  integratedUser?: string;
  sso: string;
  onboarding?: string;
  offboarding?: string;
  offboardingType?: string;
  affectedTeams?: string[];
  logsInfo?: string;
  logsRetention?: string;
  mfaPolicy?: string;
  mfa: string;
  mfaSMS?: string;
  regionBlock?: string;
  passwordPolicy?: string;
  sensitiveData?: string;
  criticidade: string;
}

export interface UserData {
  id?: string;
  name: string;
  email: string;
  password?: string;
  role: string;
  status: string;
  avatar?: string;
}

export interface AuditLogData {
  userId?: string;
  userName: string;
  action: string;
  details: string;
  type: string;
}

export interface PaginationParams {
  page?: number;
  limit?: number;
  search?: string;
}

export interface SoftwareFilters extends PaginationParams {
  hosting?: string;
  acesso?: string;
  sso?: string;
  mfa?: string;
  criticidade?: string;
  [key: string]: any;
} 