const { PrismaClient } = require('@prisma/client');

const prisma = new PrismaClient();

async function generateTestLogs() {
  try {
    console.log('🌱 Gerando logs de teste...');

    // Buscar um usuário admin
    const admin = await prisma.user.findFirst({
      where: { role: 'Admin' }
    });

    if (!admin) {
      console.error('❌ Nenhum usuário admin encontrado!');
      return;
    }

    // Tipos de logs para criar
    const logTypes = [
      { type: 'login', action: 'Login no sistema', details: 'Login bem-sucedido via formulário web' },
      { type: 'create', action: 'Criou software', details: 'Microsoft Office 365 foi adicionado ao sistema' },
      { type: 'update', action: 'Atualizou software', details: 'Atualizou informações de segurança do Slack' },
      { type: 'delete', action: 'Removeu software', details: 'Software legado removido do inventário' },
      { type: 'export', action: 'Exportou dados', details: 'Exportou relatório de softwares em CSV' },
      { type: 'filter', action: 'Aplicou filtro', details: 'Filtrou softwares por criticidade Alta' }
    ];

    // Criar logs variados
    const promises = [];
    
    for (let i = 0; i < 20; i++) {
      const logType = logTypes[Math.floor(Math.random() * logTypes.length)];
      const hoursAgo = Math.floor(Math.random() * 72); // Últimas 72 horas
      
      promises.push(
        prisma.auditLog.create({
          data: {
            userId: admin.id,
            userName: admin.name,
            action: logType.action,
            details: logType.details,
            type: logType.type,
            createdAt: new Date(Date.now() - hoursAgo * 60 * 60 * 1000)
          }
        })
      );
    }

    await Promise.all(promises);
    
    console.log('✅ 20 logs de teste criados com sucesso!');
    
    // Verificar total de logs
    const totalLogs = await prisma.auditLog.count();
    console.log(`📊 Total de logs no sistema: ${totalLogs}`);
    
  } catch (error) {
    console.error('❌ Erro ao gerar logs:', error);
  } finally {
    await prisma.$disconnect();
  }
}

// Executar
generateTestLogs();