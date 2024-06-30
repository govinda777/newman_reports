#!/bin/bash

# Verificar se os parâmetros foram fornecidos
if [ "$#" -ne 3 ]; then
  echo "Uso: $0 [environment] [swagger_file] [tiger_token]"
  echo "Exemplo: $0 local /path/to/swagger.yaml \"BearerYourTokenHere\""
  exit 1
fi

# Atribuir parâmetros a variáveis
ENVIRONMENT=$1
SWAGGER_FILE=$2
TIGER_TOKEN=$3

echo "Arquivo de entrada: $SWAGGER_FILE"

# Verificar se o arquivo Swagger existe
if [ ! -f "$SWAGGER_FILE" ]; then
  echo "Erro: Arquivo Swagger '$SWAGGER_FILE' não encontrado."
  exit 1
fi

# Navegar para o diretório de testes
cd tests/postman || exit

# Instalar dependências necessárias
echo "Instalando dependências necessárias..."
npm install newman newman-reporter-htmlextra --force

# Gerar coleção do Postman a partir do arquivo Swagger
echo "Gerando coleção do Postman a partir do arquivo Swagger..."
npx openapi2postmanv2 -s "$SWAGGER_FILE" -o swagger_postman_collection.json

# Verificar se o arquivo da coleção foi criado
COLLECTION_FILE="swagger_postman_collection.json"
if [ ! -f "$COLLECTION_FILE" ]; then
  echo "Erro: Arquivo de coleção '$COLLECTION_FILE' não foi criado."
  exit 1
fi
echo "Arquivo de coleção '$COLLECTION_FILE' criado com sucesso."

# Criar ou atualizar o arquivo de ambiente com a URL base e o token tiger
ENV_FILE="${ENVIRONMENT}_environment.json"
echo "Criando arquivo de ambiente '$ENV_FILE'..."

cat > $ENV_FILE <<EOL
{
  "id": "local-environment",
  "name": "Local Environment",
  "values": [
    {
      "key": "baseUrl",
      "value": "http://localhost:45610",
      "type": "default",
      "enabled": true
    },
    {
      "key": "tiger_token",
      "value": "$TIGER_TOKEN",
      "type": "default",
      "enabled": true
    }
  ]
}
EOL
echo "Arquivo de ambiente '$ENV_FILE' criado com sucesso."

# Certificar-se de que estamos no diretório correto
echo "Diretório atual: $(pwd)"

# Executar o script para injetar os scripts de pré-requisição e teste na coleção
echo "Injetando scripts na coleção..."
node inject_scripts.js "$COLLECTION_FILE"

# Verificar se o inject_scripts.js foi executado com sucesso e se o arquivo da coleção está presente
if [ $? -ne 0 ]; then
  echo "Erro: Falha ao injetar scripts no arquivo '$COLLECTION_FILE'."
  exit 1
fi
echo "Scripts injetados com sucesso no arquivo '$COLLECTION_FILE'."

# Executar os testes com os parâmetros fornecidos
echo "Executando testes com Newman..."
npx newman run "$COLLECTION_FILE" \
    -e $ENV_FILE \
    --env-var baseUrl="http://localhost:45610" \
    --env-var tiger_token="$TIGER_TOKEN" \
    --reporters cli,htmlextra,junit,json \
    --reporter-cli-show-timestamps \
    --reporter-json-export report-json.json \
    --reporter-junit-export report-xml.xml \
    --reporter-htmlextra-export report-htmlextra.html \
    --reporter-htmlextra-template custom_template.hbs \
    --reporter-htmlextra-title "AuthZ tests" \
    --reporter-htmlextra-titleSize 4 \
    --reporter-htmlextra-showEnvVars \
    --reporter-htmlextra-showGlobalData \
    --reporter-htmlextra-showMarkdownLinks \
    --reporter-htmlextra-logs \
    --reporter-htmlextra-skipHeaders "Authorization" \
    --reporter-htmlextra-showFolderDescription \
    --reporter-htmlextra-timezone "America/Sao_Paulo" \
    --reporter-htmlextra-displayProgressBar \
    --timeout-request 5000

# Verificar se o relatório foi gerado
if [ ! -f "report-htmlextra.html" ]; then
  echo "Erro: Relatório HTML extra não foi gerado. report_htmlextra.html"
  exit 1
fi

if [ ! -f "integration_tests_report.html" ]; then
  echo "Erro: Relatório HTML extra não foi gerado. integration_tests_report.html"
  exit 1
fi

# Abrir os relatórios no navegador
echo "Abrindo relatórios no navegador..."
open report-htmlextra.html

# Abrir os relatórios no navegador
echo "Abrindo relatórios no navegador..."
open_browser() {
  if command -v xdg-open > /dev/null; then
    xdg-open "$1"
  elif command -v open > /dev/null; then
    open "$1"
  elif command -v start > /dev/null; then
    start "$1"
  else
    echo "Não foi possível determinar o comando para abrir o navegador. Por favor, abra manualmente: $1"
  fi
}

open_browser "http://localhost:63342/newman-reports/tests/postman/integration_tests_report.html"

# Mostrar link do relatório gerado
echo "=============================="
echo "Testes executados com ambiente: ${ENVIRONMENT}, arquivo swagger: ${SWAGGER_FILE} e token tiger: ${TIGER_TOKEN}"
echo "Relatório HTML gerado (HTML extra): $(pwd)/report_htmlextra.html"
echo "Relatório HTML Custom gerado (HTML extra): $(pwd)/integration_tests_report.html"
echo "=============================="
