const fs = require('fs');
const path = require('path');

// Obter o caminho do arquivo da coleção a partir dos parâmetros
const collectionFilePath = process.argv[2];

if (!collectionFilePath) {
  console.error('Erro: Caminho do arquivo da coleção não fornecido.');
  process.exit(1);
}

const test_authz_exec_path = path.resolve(__dirname, 'test_authz_exec.js');
if (!fs.existsSync(test_authz_exec_path)) {
  console.error(`Erro: Arquivo de script de teste '${test_authz_exec_path}' não encontrado.`);
  process.exit(1);
}

const test_authz_exec = fs.readFileSync(test_authz_exec_path, 'utf8');

const test_authz_prerequest_path = path.resolve(__dirname, 'test_authz_prerequest.js');
if (!fs.existsSync(test_authz_prerequest_path)) {
  console.error(`Erro: Arquivo de script de pré-requisição '${test_authz_prerequest_path}' não encontrado.`);
  process.exit(1);
}

const test_authz_prerequest = fs.readFileSync(test_authz_prerequest_path, 'utf8');

console.log(`Verificando se o arquivo de coleção existe: ${collectionFilePath}`);

// Verifique se o arquivo da coleção existe antes de tentar lê-lo
if (!fs.existsSync(collectionFilePath)) {
  console.error(`Erro: Arquivo de coleção '${collectionFilePath}' não encontrado.`);
  process.exit(1);
}

console.log('Arquivo de coleção encontrado. Lendo o arquivo...');

// Leia o arquivo de coleção
let collection = JSON.parse(fs.readFileSync(collectionFilePath, 'utf8'));
console.log('Arquivo de coleção lido com sucesso. Injetando scripts...');

// Função para injetar scripts nas requisições
const injectScripts = (item) => {
    if (item.item) {
        item.item.forEach(injectScripts);
    } else {
        item.event = item.event || [];
        item.event.push(
            {
                listen: 'prerequest',
                script: {
                    exec: test_authz_prerequest.split('\n'),
                    type: 'text/javascript'
                }
            },
            {
                listen: 'test',
                script: {
                    exec: test_authz_exec.split('\n'),
                    type: 'text/javascript'
                }
            }
        );
    }
};

// Injetar scripts em todas as requisições
collection.item.forEach(injectScripts);

console.log('Scripts injetados com sucesso. Salvando o arquivo de coleção...');

// Escrever o arquivo de coleção atualizado
fs.writeFileSync(collectionFilePath, JSON.stringify(collection, null, 2), 'utf8');

console.log('Arquivo de coleção salvo com sucesso com os scripts injetados!');
