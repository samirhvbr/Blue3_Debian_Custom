# Blue3 Debian Custom ISO

Projeto de ISO customizada do Debian com preseed automático.

### Principais características:
- Instalação totalmente automatizada via preseed
- Particionamento LVM + GPT + EFI
- Root em **XFS**
- Volumes BTRFS para `/var`, `/var/log`, `/tmp` e `/spare`
- Configurações SSH, MOTD e .bashrc customizadas
- Totalmente offline (scripts embutidos na ISO)

### Como usar:

1. Coloque os arquivos na pasta `isofiles/blue3/`
2. Recrie a ISO com `xorriso`
3. Grave em pendrive ou teste em VM

### Arquivos importantes:
- `preseed.cfg` → Configuração principal
- `blue3/` → Scripts e arquivos de configuração