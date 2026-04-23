# Blue3 Debian ISO Custom

Projeto para gerar uma ISO customizada do Debian com instalacao automatizada via preseed e arquivos de configuracao Blue3 embutidos.

## Objetivo

Este diretorio guarda o material versionavel necessario para reconstruir a ISO:

- `script-iso.sh`: extrai a ISO base, injeta os arquivos Blue3, ajusta o boot e gera a nova ISO
- `blue3/preseed.cfg`: define a instalacao automatica
- `blue3/`: arquivos que entram na ISO em `/blue3` e sao aplicados no sistema instalado no `late_command`

Artefatos de build, como `isofiles/`, `*.iso` e `custom.log`, ficam fora do versionamento pelo `.gitignore`.

## Padrao de Automacao

Para deixar o processo o mais automatizavel possivel, a ISO base deve ficar neste diretorio com nome fixo:

```text
debian.iso
```

Isso evita editar o script a cada nova imagem. Pode ser uma ISO netinst, DVD ou outra variante do Debian, desde que seja renomeada para `debian.iso` antes do build.

O script tambem valida essa ISO logo no inicio. Se `debian.iso` nao existir, ele aborta antes da limpeza com mensagem clara no terminal e no `custom.log`.

## Arquico blue3_script.sh

Arquivo README_blue3_script.md para entender o funcionamento do /root/blue3_script.sh

## Variaveis de Ajuste Rapido

Para evitar sair procurando pontos sensiveis no script, os ajustes de usuario e grupo ficam concentrados no inicio:

```bash
BUILD_USER="${BUILD_USER:-$USER}"
BUILD_GROUP="${BUILD_GROUP:-$USER}"
```

Essas variaveis controlam os `chown` aplicados em `isofiles/`, `blue3/` e na ISO final gerada.

Se outro usuario for utilizar o build, basta ajustar essas variaveis no inicio do script ou chamar assim:

```bash
BUILD_USER=outro_usuario BUILD_GROUP=outro_grupo bash script-iso.sh
```

## Estrutura do Projeto

```text
.
├── blue3/
│   ├── blue3_script.sh
│   ├── service.one_shot
│   ├── 10-uname
│   ├── 20-blue3
│   ├── bashrc
│   ├── blue3.png
│   ├── grub.cfg
│   ├── issue
│   ├── issue.net
│   ├── motd
│   ├── preseed.cfg
│   ├── sources.list
│   └── ssh/
|       ├── ipauth.conf
|       ├── keyregeneration.conf
|       ├── thosts.conf
|       ├── sshd_config
|       └── useprivilegeseparation.conf
├── script-iso.sh
├── debian.iso
├── README.md
└── isofiles/
```

## Como o Build Funciona

O fluxo atual e este:

1. O `script-iso.sh` valida se `debian.iso` existe.
2. O script remove `isofiles/` e a ISO de saida anterior do dia.
3. A ISO base `debian.iso` e extraida para `isofiles/`.
4. O conteudo da pasta `blue3/` e copiado para `isofiles/blue3/`.
5. O script valida a existencia de `isofiles/blue3/preseed.cfg`.
6. O `initrd` do instalador e reempacotado sem os componentes de `speakup` e acessibilidade.
7. Os menus de boot BIOS e UEFI recebem os parametros para instalacao automatica usando `preseed/file=/cdrom/blue3/preseed.cfg`.
8. O `md5sum.txt` da ISO extraida e recriado.
9. A nova ISO e gerada com nome no formato `blue3-debian-YYYYMMDD.iso`.

## O que o `script-iso.sh` monta

### Entrada Esperada

- ISO base: `debian.iso`
- Diretorio de customizacao: `blue3/`

### Estrutura Gerada no Build

- `isofiles/`: arvore temporaria com a ISO extraida
- `isofiles/blue3/`: copia dos arquivos locais de customizacao
- `custom.log`: log do processo de build
- `blue3-debian-YYYYMMDD.iso`: ISO final gerada

### Alteracoes Feitas pelo Script

- Valida a existencia de `debian.iso` antes de iniciar a limpeza
- Extrai a ISO original com `xorriso`
- Ajusta dono e permissoes dos arquivos copiados para a pasta `blue3` interna
- Garante permissao executavel para `10-uname` e `20-blue3`
- Remove `speakup` e arquivos relacionados de `install.amd/initrd.gz` e `install.amd/gtk/initrd.gz`
- Ajusta o boot do instalador para usar preseed automatico e desabilitar fala
- Recalcula `md5sum.txt`
- Gera a ISO final em modo hibrido BIOS/UEFI

### Parametros de Boot Injetados

```text
auto=true priority=critical preseed/file=/cdrom/blue3/preseed.cfg vga=788 \
debian-installer/speech=false speakup.synth=none speakup.synth=off \
debian-installer/disable-speech=true noaccessibility DEBCONF_DEBUG=5
```

## O Que o `blue3/preseed.cfg` Configura

O `preseed.cfg` automatiza a instalacao e define o padrao do sistema instalado.

### Instalador

- Instalacao automatica com `debconf/priority=critical`
- `preseed/interactive=false` para reduzir perguntas durante a instalacao
- Fala e acessibilidade desabilitadas
- Locale `pt_BR.UTF-8`
- Idioma `pt`
- Teclado `us`

### Rede

Durante a instalacao, a configuracao de rede automatica e bloqueada para nao interferir no processo.

- Hostname: `blue3`
- Dominio: `b3.local`
- IPv4: desabilitado
- DNS: `170.233.231.231 170.233.231.232 1.1.1.1`
- IPv6: desabilitado
- É copiado um arquivo default do /etc/network/interfaces para facilitar seu preenchimento posterior.

### Mirror e Pacotes

- Mirror configurado: `mirror.blue3.com.br/debian`
- `apt-setup/use_mirror` esta em `false`
- Task selecionada: `standard`
- Pacotes adicionais: `sudo`, `vim`, `openssh-server`, `zstd`, `xfsprogs`, `btrfs-progs`

Para uso realmente offline, o ideal e usar uma ISO Debian que ja contenha os pacotes necessarios, tipicamente uma ISO DVD renomeada para `debian.iso`.

### Usuarios

- Nao cria usuario interativo durante o instalador
- Define o usuario `root`
- Define o usuario `samir` como usuario adicional sudo
- As senhas ficam gravadas em hash dentro do preseed
  - Podem ser alterada a senha default criando uma nova com o comando abaixo copiando todo o resultado e substituindo a partir do 'password'
  ```text
  mkpasswd -m sha-512 "sua-senha-aqui"
  ```

Observacao: os comentarios do arquivo indicam senha padrao `blue3`. Se isso for mantido fora de ambiente controlado, o ideal e trocar esse segredo antes de publicar ou usar em producao.


### Fuso e Horario

- Timezone: `America/Sao_Paulo`
- NTP: `ntp.blue3.com.br`

### Particionamento Automatico

- Lembrando que a finalidade é um servidor sem ambiente gráfico, utilizando apenas o mínimo necessário em cada partição. O restante do espaço físico permanece livre no VG do LVM, podendo ser utilizado posteriormente para ajustes nas partições. O uso de /var, /log e /tmp em Btrfs permite aplicar compactação de arquivos.
- A separação do diretório /var/log em uma partição dedicada tem como objetivo evitar que o crescimento excessivo de arquivos de log comprometa o funcionamento do sistema.
- A separação do diretório /tmp permite aplicar diretamente no /etc/fstab opções de segurança, como restrições de execução e outras proteções.

- Disco alvo: `/dev/sda`
- Volume group: `vg0`
- Layout:
  - EFI em GPT para boot UEFI
  - `/boot` em `ext4`
  - `swap` em LVM
  - `/` em LVM `xfs`
  - `/var` em LVM `btrfs`
  - `/var/log` em LVM `btrfs`
  - `/tmp` em LVM `btrfs`

## Arquivos Blue3 Aplicados no `late_command`

Ao final da instalacao, o `late_command` copia arquivos da ISO para o sistema instalado.

| Origem na ISO | Destino no sistema instalado | Finalidade |
| --- | --- | --- |
| `blue3/blue3_script.sh` | `/root/blue3_script.sh` | Script inicial para ajustes e configuracoes iniciais |
| `blue3/.env` | `/root/.env` | Arquivo de configuração da API do PHPIPAM |
| `blue3/.env.example`        | Arquivo de exemplo da configuração da API do PHPIPAM, configure conforme seu PHPIPAM |
| `blue3/service.one_shot` | `/etc/systemd/system/blue3-firstboot.service` | Script inicial forçando no boot |
| `blue3/20-blue3` | `/etc/update-motd.d/20-blue3` | MOTD dinamico da Blue3 |
| `blue3/10-uname` | `/etc/update-motd.d/10-uname` | informacoes de sistema no login |
| `blue3/issue.net` | `/etc/issue.net` | banner remoto |
| `blue3/issue` | `/etc/issue` | banner local |
| `blue3/motd` | `/etc/motd` | MOTD base |
| `blue3/bashrc` | `/root/.bashrc` | ambiente do root |
| `blue3/bashrc` | `/home/samir/.bashrc` | ambiente do usuario `samir` |
| `blue3/ssh/sshd_config` | `/etc/ssh/sshd_config` | configuracao principal do SSH |
| `blue3/ssh/ipauth.conf` | `/etc/ssh/sshd_config.d/ipauth.conf` | IPs que permitem o acesso direto com usuario root |
| `blue3/ssh/keyregeneration.conf` | `/etc/ssh/sshd_config.d/keyregeneration.conf` | Lifetime e tamanho (verão 1) |
| `blue3/ssh/rhosts.conf` | `/etc/ssh/sshd_config.d/rhosts.conf` | Configurações de permissões de hosts |
| `blue3/ssh/useprivilegeseparation.conf` | `/etc/ssh/sshd_config.d/useprivilegeseparation.conf` | Separação de previlégios |

Acoes finais executadas:

- Cria diretorios necessarios em `/target`
- Ajusta dono da home do usuario `samir`
- Habilita o servico `ssh`
- Tenta marcar os scripts de `update-motd.d` como executaveis
- Copia `sources.list` personalizado para `/etc/apt/sources.list`

## Dependencias

Pacotes esperados no host de build:

```bash
sudo apt install xorriso isolinux syslinux-utils cpio gzip
```

Tambem sao usados `md5sum`, `find`, `sed`, `xargs` e permissao `sudo` para limpeza e ajuste de ownership.

## Como Gerar a ISO

1. Coloque a ISO Debian de origem neste diretorio com o nome `debian.iso`.
2. Confirme que `blue3/preseed.cfg` e os arquivos de `blue3/` estao atualizados.
3. Execute:

```bash
cd /home/samir/Webs/b3files/www/files.b3.rs/blue3/debian_blue3_iso
sudo bash script-iso.sh
```

Saida esperada:

- ISO gerada em `blue3-debian-YYYYMMDD.iso`
- Log salvo em `custom.log`

## Observacoes Importantes

- O nome correto do script atual e `script-iso.sh`.
- Os `chown` do processo usam as variaveis `BUILD_USER` e `BUILD_GROUP` definidas no inicio do script.
- O caminho de boot correto do preseed e `/cdrom/blue3/preseed.cfg`.
- O arquivo `blue3/grub.cfg` existe no projeto, mas o fluxo atual do script nao o copia diretamente para a ISO; o ajuste de boot e feito por `sed` sobre a ISO extraida.
- O arquivo `blue3/blue3.png` existe no projeto, mas nao e manipulado diretamente pelo script atual.
- Se a intencao for publicar isso fora de ambiente controlado, vale revisar IPs, senhas e regras de SSH antes de subir para um repositorio remoto.
- O processo de instalação completo usando máquina virtual com 8 vCPU, 8 GB de RAM e 60 GB de SSD
  - Windows Server 2022 - Hyper-V levou 3 minutos e 33 segundos
  - Proxmox 9.1 levou 3 minutos e 10 segundos