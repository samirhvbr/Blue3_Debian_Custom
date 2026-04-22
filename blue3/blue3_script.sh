#!/bin/bash
set -e

# ==========================
# CONFIGURAÇÕES
# ==========================
LOG_FILE="/var/log/blue3-install.log"


# ==========================
# CARREGAR VARIÁVEIS DO .env (PHPIPAM)
# ==========================
ENV_FILE="/root/.env"

if [ ! -f "$ENV_FILE" ]; then
    echo "Arquivo de configuração não encontrado: $ENV_FILE"
    exit 1
fi
# carrega variáveis
set -a
source "$ENV_FILE"
set +a

DEFAULT_DOMAIN="b3.local"

BOOT_IP="100.64.66.88"
BOOT_NETMASK="255.255.255.0"
BOOT_GW="100.64.66.1"
BOOT_DNS="100.64.66.231"


# ==========================
# LOG
# ==========================
exec > >(tee -a $LOG_FILE) 2>&1

echo "================================="
echo " BLUE3 PROVISIONING START "
echo "================================="

# ==========================
# FUNÇÕES
# ==========================
valida_ip() {
    [[ $1 =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]
}

# ==========================
# DETECTAR INTERFACE
# ==========================
mapfile -t IFACES < <(ip -o link show | awk -F': ' '{print $2}' | grep -E '^(en|eth)')

if [ ${#IFACES[@]} -eq 0 ]; then
    echo "Nenhuma interface encontrada!"
    exit 1
fi

echo "Interfaces disponíveis:"
for i in "${!IFACES[@]}"; do
    echo "[$i] ${IFACES[$i]}"
done

read -p "Escolha interface: " IDX
IFACE=${IFACES[$IDX]}

echo "Usando interface: $IFACE"

# ==========================
# REDE BOOTSTRAP
# ==========================
echo "Configurando rede bootstrap..."

cat > /etc/network/interfaces <<EOF
auto lo
iface lo inet loopback

auto $IFACE
iface $IFACE inet static
    address $BOOT_IP
    netmask $BOOT_NETMASK
    gateway $BOOT_GW
    dns-nameservers $BOOT_DNS 170.233.231.231
EOF

ifdown $IFACE || true
ifup $IFACE || { echo "Falha ao configurar rede bootstrap"; }
sleep 2

# remover imutabilidade se existir
chattr -i /etc/resolv.conf 2>/dev/null || true
# remover arquivo atual (se for symlink)
rm -f /etc/resolv.conf
# recriar
cat > /etc/resolv.conf <<EOF
nameserver $BOOT_DNS
EOF

# ==========================
# TESTE
# ==========================
ping -c 3 $BOOT_DNS || { echo "Falha rede bootstrap"; exit 1; }


# ==========================
# INSTALANDO APPS
# ==========================
PACKAGES=(curl jq ipcalc vlan git)
NEED_INSTALL=0
for pkg in "${PACKAGES[@]}"; do
    if ! dpkg -s "$pkg" >/dev/null 2>&1; then
        NEED_INSTALL=1
        break
    fi
done
if [ "$NEED_INSTALL" -eq 1 ]; then
    echo "Instalando dependências..."
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y "${PACKAGES[@]}"
else
    echo "Todas dependências já instaladas"
fi


# ==========================
# HOSTNAME / FQDN
# ==========================
read -p "Hostname (ex: srv01): " HOST

read -p "Domínio [$DEFAULT_DOMAIN]: " DOMAIN
DOMAIN=${DOMAIN:-$DEFAULT_DOMAIN}

FQDN="$HOST.$DOMAIN"

echo "FQDN: $FQDN"

# ==========================
# CONSULTA IPAM
# ==========================
echo "Consultando IPAM..."

RESULT=$(curl -s -H "token: $IPAM_TOKEN" \
    "$IPAM_API/addresses/search_hostname/$FQDN/")

IP=$(echo "$RESULT" | jq -r '.data[0].ip')
SUBNET_ID=$(echo "$RESULT" | jq -r '.data[0].subnetId')

if [ "$IP" == "null" ] || [ -z "$IP" ]; then
    echo "Hostname não encontrado no IPAM!"
    exit 1
fi

echo "IP encontrado: $IP"

# ==========================
# SUBNET INFO
# ==========================
SUBNET_DATA=$(curl -s -H "token: $IPAM_TOKEN" \
    "$IPAM_API/subnets/$SUBNET_ID/")

SUBNET=$(echo "$SUBNET_DATA" | jq -r '.data.subnet')
MASK=$(echo "$SUBNET_DATA" | jq -r '.data.mask')
GATEWAY=$(echo "$SUBNET_DATA" | jq -r '.data.gateway.ip_addr')

cidr_to_netmask() {
    local i mask=""
    local full_octets=$(( $1 / 8 ))
    local partial_octet=$(( $1 % 8 ))

    for ((i=0;i<4;i++)); do
        if [ $i -lt $full_octets ]; then
            mask+=255
        elif [ $i -eq $full_octets ]; then
            mask+=$((256 - 2**(8 - $partial_octet)))
        else
            mask+=0
        fi
        [ $i -lt 3 ] && mask+=.
    done
    echo $mask
}
NETMASK=$(cidr_to_netmask $MASK)


# 🔥 VALIDAÇÃO
if [ -z "$IP" ] || [ "$IP" = "null" ] || \
   [ -z "$GATEWAY" ] || [ "$GATEWAY" = "null" ] || \
   [ -z "$NETMASK" ]; then
    echo "Erro: parâmetros de rede inválidos!"
    echo "IP: $IP"
    echo "Gateway: $GATEWAY"
    echo "Netmask: $NETMASK"
    exit 1
fi
echo "Subnet: $SUBNET/$MASK"
echo "Gateway: $GATEWAY"
echo "Netmask: $NETMASK"


# ==========================
# VLAN (se existir)
# ==========================
VLAN_ID=$(echo "$SUBNET_DATA" | jq -r '.data.vlanId')

if [ "$VLAN_ID" != "null" ] && [ -n "$VLAN_ID" ]; then
    echo "VLAN detectada no IPAM: $VLAN_ID"

    read -p "Deseja configurar VLAN na VM? (y/n): " USE_VLAN

    if [ "$USE_VLAN" == "y" ]; then
        echo "Configurando VLAN $VLAN_ID"
        ip link add link $IFACE name ${IFACE}.${VLAN_ID} type vlan id $VLAN_ID
        ip link set up ${IFACE}.${VLAN_ID}
        IFACE=${IFACE}.${VLAN_ID}
    else
        echo "VLAN ignorada (provavelmente tratada no hypervisor)"
    fi
fi

# ==========================
# CONFIG FINAL
# ==========================
echo "Aplicando configuração final..."

hostnamectl set-hostname "$FQDN"

cat > /etc/hosts <<EOF
127.0.0.1 localhost
127.0.1.1 $FQDN $HOST
$IP $FQDN $HOST
EOF

cat > /etc/resolv.conf <<EOF
domain $DOMAIN
nameserver $BOOT_DNS
nameserver 170.233.231.231
nameserver 170.233.231.232
nameserver 1.1.1.1
EOF

chattr +i /etc/resolv.conf || true

cat > /etc/network/interfaces <<EOF
auto lo
iface lo inet loopback

auto $IFACE
iface $IFACE inet static
    address $IP
    netmask $NETMASK
    gateway $GATEWAY
    dns-nameservers $BOOT_DNS 170.233.231.231 170.233.231.232 1.1.1.1
EOF

# ==========================
# APLICAR REDE FINAL
# ==========================
echo "Reiniciando rede..."

ifdown $IFACE || true
ifup $IFACE || { echo "Falha ao configurar rede final"; }
sleep 2

ping -c 2 $GATEWAY || { echo "Falha rede final"; exit 1; }

# ==========================
# CLONE
# ==========================
cd /root
if [ -d "Linux-Start" ]; then
    echo "Repositório já existe, atualizando..."
    cd Linux-Start
    git pull
    chmod +x *.sh || true
    [ -f ./start.sh ] && ./start.sh
else
    echo "Clonando repositório..."
    git clone https://github.com/samirhvbr/Linux-Start.git
    cd Linux-Start
    chmod +x *.sh || true
    [ -f ./start.sh ] && ./start.sh
fi

echo "================================="
echo " PROVISIONAMENTO FINALIZADO "
echo "================================="