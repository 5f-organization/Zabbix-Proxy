#!/bin/bash
# Script para INSTALAR o Zabbix Proxy (do zero) no Debian 12

LOGFILE="$HOME/install_zabbix_proxy_$(date +%F_%H-%M-%S).log"

echo "========================== INÍCIO DA INSTALAÇÃO DO ZABBIX PROXY: $(date '+%Y-%m-%d %H:%M:%S') ==========================" | tee -a "$LOGFILE"

# --- Seleção do Backend do Banco de Dados ---
# O Zabbix Proxy precisa de um backend. Escolha um:
# 1 = MySQL (Recomendado, compatível com MariaDB)
# 2 = PostgreSQL
# 3 = SQLite3 (Não recomendado para produção)

echo "Qual backend de banco de dados você usará para o Zabbix Proxy?"
echo "  1) MySQL / MariaDB (Recomendado)"
echo "  2) PostgreSQL"
echo "  3) SQLite3 (Apenas para testes)"
read -p "Digite o número (1, 2 ou 3): " DB_CHOICE

case $DB_CHOICE in
    1)
        PROXY_PACKAGE="zabbix-proxy-mysql"
        ;;
    2)
        PROXY_PACKAGE="zabbix-proxy-pgsql"
        ;;
    3)
        PROXY_PACKAGE="zabbix-proxy-sqlite3"
        ;;
    *)
        echo "Opção inválida. Saindo." | tee -a "$LOGFILE"
        exit 1
        ;;
esac

echo "Pacote selecionado: $PROXY_PACKAGE" | tee -a "$LOGFILE"

# --- Fim da Seleção ---

echo "Instalando dependências (wget)..." | tee -a "$LOGFILE"
apt update | tee -a "$LOGFILE"
apt install -y wget | tee -a "$LOGFILE"

if [ $? -ne 0 ]; then
    echo "ERRO CRÍTICO: Falha ao instalar o 'wget'. Verifique seu acesso à internet ou ao apt." | tee -a "$LOGFILE"
    exit 1
fi

echo "Baixando o pacote do repositório Zabbix 7.4..." | tee -a "$LOGFILE"
wget -O /tmp/zabbix-release_latest+debian12_all.deb https://repo.zabbix.com/zabbix/7.4/release/debian/pool/main/z/zabbix-release/zabbix-release_latest+debian12_all.deb

if [ $? -ne 0 ]; then
    echo "ERRO CRÍTICO: Falha ao baixar o pacote do repositório. O script será interrompido." | tee -a "$LOGFILE"
    exit 1
fi

echo "Instalando o novo repositório..." | tee -a "$LOGFILE"
dpkg -i /tmp/zabbix-release_latest+debian12_all.deb | tee -a "$LOGFILE"

echo "Atualizando a lista de pacotes (apt update) após adicionar o repo..." | tee -a "$LOGFILE"
apt update | tee -a "$LOGFILE"

echo "Instalando os pacotes do Zabbix Proxy e Agente..." | tee -a "$LOGFILE"
# Instala o pacote do proxy (baseado na escolha) e o agent2
apt install -y $PROXY_PACKAGE zabbix-agent2 | tee -a "$LOGFILE"

if [ $? -ne 0 ]; then
    echo "ERRO CRÍTICO: O comando 'apt install' falhou. Verifique o log." | tee -a "$LOGFILE"
    exit 1
fi

echo "Habilitando o serviço zabbix-proxy para iniciar no boot (após configuração manual)..." | tee -a "$LOGFILE"
systemctl enable zabbix-proxy
systemctl enable zabbix-agent2

echo ""
echo "========================== INSTALAÇÃO DOS PACOTES CONCLUÍDA ==========================" | tee -a "$LOGFILE"
echo ""
echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!! AÇÃO MANUAL NECESSÁRIA !!!!!!!!!!!!!!!!!!!!!!!!!!!!!" | tee -a "$LOGFILE"
echo ""
echo "O Zabbix Proxy NÃO foi iniciado. Você precisa configurá-lo primeiro." | tee -a "$LOGFILE"
echo ""
echo "PRÓXIMOS PASSOS OBRIGATÓRIOS:" | tee -a "$LOGFILE"
echo "1. Crie um banco de dados e um usuário para o Zabbix Proxy (ex: no MySQL, MariaDB ou PostgreSQL)." | tee -a "$LOGFILE"
echo "2. Importe o schema inicial do Zabbix para o banco de dados criado. O arquivo está em:" | tee -a "$LOGFILE"
if [ "$PROXY_PACKAGE" = "zabbix-proxy-mysql" ]; then
    echo "   /usr/share/zabbix-sql-scripts/mysql/proxy.sql" | tee -a "$LOGFILE"
    echo "   (Ex: zcat /usr/share/zabbix-sql-scripts/mysql/proxy.sql | mysql -u'zabbix_proxy' -p'senha' 'zabbix_proxy_db')" | tee -a "$LOGFILE"
elif [ "$PROXY_PACKAGE" = "zabbix-proxy-pgsql" ]; then
    echo "   /usr/share/zabbix-sql-scripts/postgresql/proxy.sql" | tee -a "$LOGFILE"
    echo "   (Ex: zcat /usr/share/zabbix-sql-scripts/postgresql/proxy.sql | sudo -u zabbix psql 'zabbix_proxy_db')" | tee -a "$LOGFILE"
else
    echo "   /usr/share/zabbix-sql-scripts/sqlite3/proxy.sql" | tee -a "$LOGFILE"
    echo "   (Ex: cat /usr/share/zabbix-sql-scripts/sqlite3/proxy.sql | sqlite3 /var/lib/zabbix/zabbix_proxy.db)" | tee -a "$LOGFILE"
fi
echo "3. Edite o arquivo de configuração: /etc/zabbix/zabbix_proxy.conf" | tee -a "$LOGFILE"
echo "   - Configure 'Server=' (IP ou DNS do seu Zabbix Server)" | tee -a "$LOGFILE"
echo "   - Configure 'Hostname=' (Nome exato deste proxy, como cadastrado no Zabbix Server)" | tee -a "$LOGFILE"
echo "   - Configure as linhas de 'DBName', 'DBUser', 'DBPassword' (e 'DBHost' se o banco for remoto)." | tee -a "$LOGFILE"
echo "4. Inicie o serviço: sudo systemctl start zabbix-proxy" | tee -a "$LOGFILE"
echo "5. Verifique os logs: tail -f /var/log/zabbix/zabbix_proxy.log" | tee -a "$LOGFILE"
echo "==================================================================================================" | tee -a "$LOGFILE"
