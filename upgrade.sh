#!/bin/bash
# Script para atualizar o Zabbix PROXY para 7.4 no Debian 12

LOGFILE="$HOME/upgrade_zabbix_proxy_$(date +%F_%H-%M-%S).log"

echo "========================== INÍCIO DO UPGRADE DO ZABBIX PROXY: $(date '+%Y-%m-%d %H:%M:%S') ==========================" | tee -a "$LOGFILE"

# --- PASSO CRÍTICO: PARAR O SERVIÇO ---
echo "Parando o serviço Zabbix Proxy..." | tee -a "$LOGFILE"
systemctl stop zabbix-proxy
if [ $? -ne 0 ]; then
    echo "AVISO: Não foi possível parar o serviço zabbix-proxy. O script continuará, mas isso não é o ideal." | tee -a "$LOGFILE"
fi
# --- FIM DO PASSO CRÍTICO ---

echo "Limpando configurações de repositório antigas..." | tee -a "$LOGFILE"
rm -f /etc/apt/sources.list.d/zabbix.list
dpkg -P zabbix-release &>> "$LOGFILE"
rm -f /tmp/zabbix-release_latest+debian12_all.deb

echo "Baixando o novo pacote do repositório Zabbix 7.4..." | tee -a "$LOGFILE"
wget -O /tmp/zabbix-release_latest+debian12_all.deb https://repo.zabbix.com/zabbix/7.4/release/debian/pool/main/z/zabbix-release/zabbix-release_latest+debian12_all.deb

if [ $? -ne 0 ]; then
    echo "ERRO CRÍTICO: Falha ao baixar o pacote do repositório. O script será interrompido." | tee -a "$LOGFILE"
    exit 1
fi

echo "Instalando o novo repositório..." | tee -a "$LOGFILE"
dpkg -i /tmp/zabbix-release_latest+debian12_all.deb | tee -a "$LOGFILE"

echo "Atualizando a lista de pacotes (apt update)..." | tee -a "$LOGFILE"
apt update | tee -a "$LOGFILE"

echo "Atualizando os pacotes do Zabbix Proxy..." | tee -a "$LOGFILE"
# Adicionamos a opção '--allow-downgrades' para segurança
# O comando tentará atualizar qualquer um dos backends de proxy (mysql, pgsql, sqlite3).
# O apt irá ignorar os que não estiverem instalados e atualizará apenas o que existir.
apt install -y --only-upgrade --allow-downgrades \
  zabbix-proxy-mysql zabbix-proxy-pgsql zabbix-proxy-sqlite3 \
  zabbix-agent zabbix-agent2 | tee -a "$LOGFILE"

if [ $? -ne 0 ]; then
    echo "ERRO CRÍTICO: O comando 'apt install' falhou. Verifique o log." | tee -a "$LOGFILE"
    echo "O serviço zabbix-proxy NÃO será iniciado automaticamente." | tee -a "$LOGFILE"
    exit 1
fi

# --- REINICIAR O SERVIÇO ---
echo "Iniciando o serviço Zabbix Proxy atualizado..." | tee -a "$LOGFILE"
systemctl start zabbix-proxy

echo "Aguardando 5 segundos para o serviço iniciar..." | tee -a "$LOGFILE"
sleep 5

echo "Verificando o status do serviço..." | tee -a "$LOGFILE"
systemctl status zabbix-proxy --no-pager | tee -a "$LOGFILE"

echo "========================== FIM DO SCRIPT DE UPGRADE DO PROXY: $(date '+%Y-%m-%d %H:%M:%S') ==========================" | tee -a "$LOGFILE"
echo "Verifique a saída e os logs do Zabbix Proxy em /var/log/zabbix/zabbix_proxy.log para confirmar a inicialização correta."
