const bcrypt = require('bcryptjs');

const password = 'admin123';
const saltRounds = 10;

bcrypt.hash(password, saltRounds, function(err, hash) {
    if (err) {
        console.error('Erro ao gerar hash:', err);
        return;
    }
    console.log('Hash para senha "admin123":', hash);
});