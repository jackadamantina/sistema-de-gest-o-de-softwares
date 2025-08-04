const { PrismaClient } = require('@prisma/client');
const bcrypt = require('bcryptjs');

const prisma = new PrismaClient();

async function seedUsers() {
  try {
    console.log('🌱 Criando usuários padrão...');

    // Usuários padrão
    const users = [
      {
        email: 'admin@softwarehub.com',
        name: 'Administrador',
        password: 'admin123',
        role: 'Admin',
        avatar: 'AD'
      },
      {
        email: 'editor@softwarehub.com',
        name: 'Editor',
        password: 'editor123',
        role: 'Editor',
        avatar: 'ED'
      },
      {
        email: 'viewer@softwarehub.com',
        name: 'Visualizador',
        password: 'viewer123',
        role: 'Visualizador',
        avatar: 'VI'
      }
    ];

    for (const userData of users) {
      const hashedPassword = await bcrypt.hash(userData.password, 10);
      
      await prisma.user.upsert({
        where: { email: userData.email },
        update: {},
        create: {
          email: userData.email,
          name: userData.name,
          passwordHash: hashedPassword,
          role: userData.role,
          status: 'Ativo',
          avatar: userData.avatar
        }
      });
      
      console.log(`✅ Usuário ${userData.email} criado`);
    }

    // Criar um software de exemplo
    const admin = await prisma.user.findUnique({
      where: { email: 'admin@softwarehub.com' }
    });

    if (admin) {
      const existingSoftware = await prisma.software.findFirst({
        where: { servico: 'Microsoft Office 365' }
      });

      if (!existingSoftware) {
        await prisma.software.create({
          data: {
            servico: 'Microsoft Office 365',
            description: 'Suite de produtividade Microsoft',
            url: 'https://office.com',
            hosting: 'Cloud',
            acesso: 'Externo',
            responsible: 'TI - Infraestrutura',
            namedUser: 'Sim',
            integratedUser: 'Sim',
            sso: 'Integrado',
            onboarding: 'Automático via AD',
            offboarding: 'Remoção automática',
            offboardingType: 'Alta',
            affectedTeams: ['TI', 'RH', 'Financeiro'],
            logsInfo: 'Ambos',
            logsRetention: 'Mensal',
            mfaPolicy: 'Sim',
            mfa: 'Habilitado',
            mfaSMS: 'Sim',
            regionBlock: 'Sim',
            passwordPolicy: 'Sim',
            sensitiveData: 'Sim',
            criticidade: 'Alta',
            createdBy: admin.id,
            updatedBy: admin.id
          }
        });
        console.log('✅ Software de exemplo criado');
      }
    }

    console.log('🎉 Seed concluído com sucesso!');
  } catch (error) {
    console.error('❌ Erro no seed:', error);
    throw error;
  } finally {
    await prisma.$disconnect();
  }
}

// Executar se chamado diretamente
if (require.main === module) {
  seedUsers()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });
}

module.exports = seedUsers;