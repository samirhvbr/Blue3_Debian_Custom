# Blue3 Debian Custom ISO

Projeto para gerar uma ISO customizada do Debian com instalacao automatizada via preseed e configuracao Blue3 embutida.


## Objetivo

Este diretorio guarda o material versionavel para reconstruir a ISO Blue3:

- `script-iso.sh`: extrai a ISO original do Debian, injeta os arquivos Blue3, ajusta o boot e gera a nova ISO.
- `blue3/preseed.cfg`: define a instalacao automatica.
- `blue3/`: arquivos que entram dentro da ISO em `/blue3` e sao aplicados no sistema instalado no `late_command`.

Os artefatos gerados durante o build, como `isofiles/`, `*.iso` e `custom.log`, ficam fora do versionamento por causa do `.gitignore`.


## Fluxo real do projeto

O fluxo atual nao depende de copiar arquivos manualmente para `isolinux/` ou `boot/grub/`. O processo real e este:

1. O `script-iso.sh` extrai a ISO base `debian-13.4.0-amd64-netinst.iso` para `isofiles/`.
2. O conteudo da pasta `blue3/` e copiado para dentro da ISO em `isofiles/blue3/`.
3. O script valida a existencia de `isofiles/blue3/preseed.cfg`.
4. O `initrd` do instalador e reempacotado sem os componentes de `speakup` e acessibilidade.
5. Os menus de boot BIOS e UEFI recebem os parametros para instalacao automatica usando `preseed/file=/cdrom/blue3/preseed.cfg`.
6. O `md5sum.txt` da ISO extraida e recriado.
7. Uma nova ISO e gerada com nome no formato `blue3-debian-YYYYMMDD.iso`.

## O que o `script-iso.sh` monta


### Entrada esperada

- ISO base: `debian-13.4.0-amd64-netinst.iso`
- Diretorio de customizacao: `blue3/`


### Estrutura gerada no build

- `isofiles/`: arvore temporaria com a ISO extraida
- `isofiles/blue3/`: copia dos arquivos locais de customizacao
- `custom.log`: log do processo de build
- `blue3-debian-YYYYMMDD.iso`: ISO final gerada


### Alteracoes feitas pelo script

- Remove qualquer `isofiles/` anterior e a ISO de saida do dia.
- Extrai a ISO original com `xorriso`.
- Ajusta dono e permissoes dos arquivos copiados para a pasta `blue3` interna.
- Garante permissao executavel para `10-uname` e `20-blue3`.
- Remove `speakup` e arquivos relacionados de:
  - `install.amd/initrd.gz`
  - `install.amd/gtk/initrd.gz`
- Ajusta o boot do instalador para usar:
  - `auto=true`
  - `priority=critical`
  - `preseed/file=/cdrom/blue3/preseed.cfg`
  - parametros para desabilitar fala e acessibilidade
- Recalcula `md5sum.txt`.
- Gera a ISO final em modo hibrido BIOS/UEFI.


### Parametros de boot injetados

O script adiciona ao kernel do instalador:

```text
auto=true priority=critical preseed/file=/cdrom/blue3/preseed.cfg vga=788 \
debian-installer/speech=false speakup.synth=none speakup.synth=off \
debian-installer/disable-speech=true noaccessibility DEBCONF_DEBUG=5
```

## O que o `blue3/preseed.cfg` monta no sistema instalado

O `preseed.cfg` automatiza a instalacao e define o padrao do servidor instalado.


### Instalador

- Instalacao automatica com `debconf/priority=critical`
- Interface grafica do instalador habilitada
- Fala e acessibilidade desabilitadas
- Locale `pt_BR.UTF-8`
- Idioma `pt`
- Teclado `us`


### Rede

Durante a instalacao, a configuracao de rede automatica e bloqueada para nao interferir no processo.

Valores definidos no preseed:

- Hostname: `blue3`
- Dominio: `b3.local`
- IPv4: `100.64.66.88/24`
- Gateway: `100.64.66.1`
- DNS: `100.64.66.231 1.1.1.1`
- IPv6: desabilitado


### Mirror e pacotes

- Mirror configurado: `mirror.blue3.com.br/debian`
- `apt-setup/use_mirror` esta em `false`, entao a instalacao prioriza o fluxo offline do midia/preseed atual
- Task selecionada: `standard`
- Pacotes adicionais:
  - `sudo`
  - `vim`
  - `openssh-server`
  - `zstd`
  - `xfsprogs`
  - `btrfs-progs`


### Usuarios

- Nao cria usuario interativo durante o instalador
- Define `root`
- Define o usuario `samir` com UID `1000`
- As senhas estao gravadas em hash dentro do preseed

Observacao: os comentarios do arquivo indicam senha padrao `pwblue3`. Se isso for mantido para uso real, o ideal e trocar esse segredo antes de publicar ou usar em producao.


### Fuso e horario

- Timezone: `America/Sao_Paulo`
- NTP configurado para `ntp.blue3.com.br`


### Particionamento automatico

Disco alvo:

- `/dev/sda`

Volume group criado:

- `vgsys00`

Layout aplicado:

- EFI: particao GPT para boot UEFI
- `/boot`: `ext4`
- `swap`: volume LVM
- `/`: `xfs`
- `/var`: `btrfs`
- `/tmp`: `btrfs`
- `/spare`: `btrfs`

Observacao: o README antigo mencionava `/var/log` em volume proprio, mas o `preseed.cfg` atual nao cria mais esse mountpoint separado.

## Arquivos Blue3 aplicados no `late_command`

Ao final da instalacao, o `late_command` copia arquivos da ISO para o sistema instalado.


### Arquivos copiados para o sistema alvo

| Origem na ISO | Destino no sistema instalado | Finalidade |
| --- | --- | --- |
| `blue3/20-blue3` | `/etc/update-motd.d/20-blue3` | MOTD dinamico da Blue3 |
| `blue3/10-uname` | `/etc/update-motd.d/10-uname` | informacoes de sistema no login |
| `blue3/issue.net` | `/etc/issue.net` | banner remoto |
| `blue3/issue` | `/etc/issue` | banner local |
| `blue3/motd` | `/etc/motd` | MOTD base |
| `blue3/interfaces` | `/etc/network/interfaces` | modelo de rede |
| `blue3/bashrc` | `/root/.bashrc` | ambiente do root |
| `blue3/bashrc` | `/home/samir/.bashrc` | ambiente do usuario `samir` |
| `blue3/ssh/sshd_config` | `/etc/ssh/sshd_config` | configuracao principal do SSH |
| `blue3/ssh/*.conf` | `/etc/ssh/sshd_config.d/` | complementos de configuracao SSH |


### Acoes finais executadas

- Cria diretorios necessarios em `/target`
- Ajusta dono da home do usuario `samir`
- Habilita o servico `ssh`
- Tenta marcar os scripts de `update-motd.d` como executaveis

## Estrutura versionavel do repositorio

Arquivos que fazem sentido manter no Git:

- `README.md`
- `script-iso.sh`
- `blue3/preseed.cfg`
- `blue3/bashrc`
- `blue3/interfaces`
- `blue3/issue`
- `blue3/issue.net`
- `blue3/motd`
- `blue3/10-uname`
- `blue3/20-blue3`
- `blue3/ssh/`

Arquivos gerados ou pesados que devem continuar fora do Git:

- `*.iso`
- `isofiles/`
- `custom.log`
- imagens temporarias e diretorios de trabalho

## Como gerar a ISO


### Dependencias esperadas

- `xorriso`
- `cpio`
- `gzip`
- `md5sum`
- permissao `sudo` para limpeza e ajuste de ownership


### Execucao

```bash
cd /home/samir/Webs/b3files/www/files.b3.rs/blue3/debian_blue3_iso
bash script-iso.sh
```

### Saida esperada

- ISO gerada em `blue3-debian-YYYYMMDD.iso`
- Log salvo em `custom.log`

## Observacoes importantes

- O nome correto do script no diretorio atual e `script-iso.sh`.
- O arquivo `blue3/grub.cfg` existe no projeto, mas o fluxo atual do script nao o copia diretamente para dentro do GRUB da ISO; o ajuste de boot e feito por `sed` sobre a ISO extraida.
- O arquivo `blue3/preseed.cfg` e referenciado no boot como `/cdrom/blue3/preseed.cfg`.
- Se a intencao for publicar isso fora de ambiente controlado, vale revisar IPs, senhas e regras de SSH antes de subir para um repositorio remoto.