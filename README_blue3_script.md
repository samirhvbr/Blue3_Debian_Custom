# 🚀 Blue3 Provisioning Script

Script de pré-configuração automatizada para servidores Debian Trixie, utilizado no provisionamento em ambientes de Data Center da Blue3.

---

## 🧠 Objetivo

Automatizar a configuração inicial de servidores utilizando o phpIPAM como fonte de verdade, com base no FQDN (hostname + domínio).

---

## ⚙️ Funcionalidades

- Bootstrap de rede com IP fixo temporário
- Consulta automática ao phpIPAM via API
- Configuração completa de rede (IP, gateway, máscara, VLAN)
- Configuração de hostname e DNS
- Instalação automática de dependências
- Integração com repositório de provisionamento
- Execução de script padrão da Blue3

---

## 🔄 Fluxo de Execução

[ Boot Debian ] 
↓ 
[ script.sh ] 
↓ 
[ Rede bootstrap ] 
↓ 
[ Input: hostname + domínio ] 
↓ 
[ Consulta phpIPAM ] 
↓ 
[ Aplicação da rede final ] 
↓ 
[ Clone do repositório Linux-Start ] 
↓ 
[ Provisionamento completo ] 

---

## 🌐 Integração com IPAM

O script utiliza o :contentReference[oaicite:0]{index=0} como fonte de verdade para:

- Endereço IP
- Gateway
- Máscara de rede
- VLAN

A busca é realizada utilizando o FQDN:
hostname.dominio

---

## 🛠️ Dependências

O script garante a instalação dos seguintes pacotes:

- curl
- jq
- ipcalc
- vlan
- git

---

## 🔐 Configuração de Credenciais

As credenciais da API não devem ser armazenadas no script.

### 📄 Arquivo recomendado:
/root/.env

### Exemplo:

IPAM_API=http://ipam.seudominio.local/api/SEU_APP_ID 

IPAM_TOKEN=SEU_TOKEN_AQUI 



## Execute o script após a instalação do sistema:
bash blue3_script.sh


### O script solicitará:

Hostname (ex: srv01)
Domínio (default: b3.local)

VLAN

Se o IPAM retornar uma VLAN:

O script perguntará se deseja aplicar na interface