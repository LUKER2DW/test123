#!/bin/bash

# ==============================================================================
# AGENTE NICE - TUDO-EM-UM (INSTALADOR E EXECUTOR)
# ==============================================================================
# Este script automatiza a instalação, configuração e execução do Agente Nice.
# Projetado para ser executado via Raw do GitHub:
# curl -sSL https://raw.githubusercontent.com/usuario/repo/main/nice.sh | bash
# ==============================================================================

# Cores para o terminal
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

clear
echo -e "${BLUE}===============================================${NC}"
echo -e "${GREEN}       _   _ _              _                    ${NC}"
echo -e "${GREEN}      | \ | (_)            / \   __ _  ___ _ __  ${NC}"
echo -e "${GREEN}      |  \| | | |   _     / _ \ / _\` |/ _ \ '_ \ ${NC}"
echo -e "${GREEN}      | |\  | | |__| |   / ___ \ (_| |  __/ | | |${NC}"
echo -e "${GREEN}      |_| \_|_|\____/   /_/   \_\__, |\___|_| |_|${NC}"
echo -e "${GREEN}                                |___/            ${NC}"
echo -e "${BLUE}===============================================${NC}"
echo -e "${YELLOW}    AGENTE NICE - SEU ASSISTENTE KALI LINUX    ${NC}"
echo -e "${BLUE}===============================================${NC}"

# 1. Criar pasta do projeto se não estivermos nela
PROJECT_DIR="$(pwd)/nice-agent"
if [[ "$(basename $(pwd))" != "nice-agent" && ! -d "nice-agent" ]]; then
    echo -e "[*] Criando diretório de trabalho: ${BLUE}nice-agent${NC}"
    mkdir -p "$PROJECT_DIR"
    cd "$PROJECT_DIR"
elif [[ -d "nice-agent" && "$(basename $(pwd))" != "nice-agent" ]]; then
    cd "nice-agent"
fi

# 2. Criar arquivo de configuração config.yaml
echo -e "[*] Configurando parâmetros do Agente..."
cat <<EOF > config.yaml
# Configuração do Open Interpreter para o Agente Nice
model: "ollama/deepseek-coder:6.7b"
context_window: 4096
max_tokens: 2048
auto_run: true
safe_mode: false
system_message: |
  Você é o "Agente Nice", um assistente especialista em segurança cibernética e administração de sistemas Linux (especificamente Kali Linux).
  Seu objetivo é ajudar o usuário a consertar o que está quebrado no sistema e executar comandos de terminal com precisão.
  Como você está rodando em um ambiente CLI (Terminal), seja direto, eficiente e explique o que cada comando faz antes de executá-lo.
  Sempre verifique o estado do sistema (logs, serviços, permissões) antes de propor correções.
  Você tem permissão total para executar comandos, mas sempre priorize a integridade do sistema.
EOF

# 3. Verificar/Instalar Ollama
if ! command -v ollama &> /dev/null; then
    echo -e "${YELLOW}[!] Ollama não encontrado. Instalando...${NC}"
    curl -fsSL https://ollama.com/install.sh | sh
else
    echo -e "${GREEN}[+] Ollama detectado.${NC}"
fi

# 4. Iniciar serviço Ollama
if ! pgrep -x "ollama" > /dev/null; then
    echo -e "[*] Iniciando serviço Ollama em background..."
    ollama serve > /dev/null 2>&1 &
    sleep 5
fi

# 5. Baixar Modelo
echo -e "[*] Verificando modelo DeepSeek (isso pode demorar na primeira vez)..."
ollama pull deepseek-coder:6.7b

# 6. Configurar Ambiente Python
echo -e "[*] Configurando ambiente Python..."
sudo apt-get update -y && sudo apt-get install -y python3-venv python3-pip python3-full

if [ ! -d "venv" ]; then
    python3 -m venv venv
fi

source venv/bin/activate
echo -e "[*] Instalando/Atualizando dependências Python..."
pip install --upgrade pip
pip install open-interpreter ollama

# 7. Execução do Agente
echo -e "${BLUE}-----------------------------------------------${NC}"
echo -e "${GREEN}[SUCCESS] Agente Nice está pronto!${NC}"
echo -e "[+] Conectando ao DeepSeek Coder via Ollama..."
echo -e "${BLUE}-----------------------------------------------${NC}"

# Comando para rodar
interpreter --config config.yaml
