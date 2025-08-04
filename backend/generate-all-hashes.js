const bcrypt = require('bcryptjs');

const passwords = [
    { user: 'admin', password: 'admin123' },
    { user: 'editor', password: 'editor123' },
    { user: 'viewer', password: 'viewer123' }
];

const saltRounds = 10;

passwords.forEach(({ user, password }) => {
    bcrypt.hash(password, saltRounds, function(err, hash) {
        if (err) {
            console.error(`Erro ao gerar hash para ${user}:`, err);
            return;
        }
        console.log(`-- ${user} (senha: ${password})`);
        console.log(`Hash: ${hash}`);
        console.log('');
    });
});