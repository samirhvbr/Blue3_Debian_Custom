#!/bin/bash
#
# ===================================================================
# PRESEED PERSONALIZADO BLUE3
# Instalação automatizada Debian com LVM + XFS/BTRFS
# Debian Version: Trixie (12+1)
# Author: Samir Hanna Verza
# Date: 12/04/2026
# Version: 2.01
# ===================================================================
#

# SETDEF -e
set -e

# ==========================
# VARIÁVEIS
# ==========================
BASE_DIR="/home/samir/Webs/b3files/www/files.b3.rs/blue3/debian_blue3_iso"
ISO_ORIG="$BASE_DIR/debian-13.4.0-amd64-netinst.iso"
ISO_WORK="$BASE_DIR/isofiles"
BLUE3_DIR="$ISO_WORK/blue3"
CUSTOM_DIR="$BASE_DIR/blue3"
LOG="$BASE_DIR/custom.log"
GRUB_SRC="$BASE_DIR/blue3/grub.cfg"
DATA=$(date +%Y%m%d)
ISO_OUT="$BASE_DIR/blue3-debian-${DATA}.iso"

echo "[+] Iniciando build Blue3 em $(date)" | tee -a "$LOG"

# ==========================
# LIMPEZA
# ==========================
sudo rm -rf "$ISO_WORK" "$ISO_OUT"
mkdir -p "$ISO_WORK" "$BLUE3_DIR"

# ==========================
# EXTRAIR ISO
# ==========================
echo "[+] Extraindo ISO..." | tee -a "$LOG"
xorriso -osirrox on -indev "$ISO_ORIG" -extract / "$ISO_WORK/" >> "$LOG" 2>&1
sudo chown -R $USER:$USER "$ISO_WORK"
chmod -R u+w "$ISO_WORK"

# ==========================
# COPIAR BLUE3
# ==========================
echo "[+] Copiando arquivos Blue3..." | tee -a "$LOG"
cp -a "$CUSTOM_DIR/"* "$BLUE3_DIR/" 2>/dev/null || true
#cp -a "$CUSTOM_DIR/preseed.cfg" "$ISO_WORK/." 2>/dev/null || true

touch "$BLUE3_DIR/motd"

# CORRECAO
sudo chown -R $USER:$USER "$BLUE3_DIR"
sudo chmod -R u+rw "$BLUE3_DIR"
# Corrige permissões de TODOS arquivos (inclusive ssh)
find "$BLUE3_DIR" -type f -exec chmod 644 {} \;
find "$BLUE3_DIR" -type d -exec chmod 755 {} \;
# Garante que você é dono
sudo chown -R $USER:$USER "$BLUE3_DIR"

sudo chmod 644 "$BLUE3_DIR/"* 2>/dev/null || true
sudo chmod +x "$BLUE3_DIR/10-uname" "$BLUE3_DIR/20-blue3" 2>/dev/null || true













# VERIFICACAO DO PRESEED
echo "[+] Verificando preseed..." | tee -a "$LOG"
if [ -f "$BLUE3_DIR/preseed.cfg" ]; then
    echo "[+] preseed.cfg encontrado..." | tee -a "$LOG"
else
    echo "[ERRO] preseed.cfg NÃO encontrado!" | tee -a "$LOG"
    exit 1
fi









# ==========================
# REMOVER SPEECH SYNTHESIS DO INITRD (Solução definitiva Debian)
# ==========================
echo "[+] Removendo speakup do initrd (anti-speech definitivo)..." | tee -a "$LOG"

INITRD_GZ="$ISO_WORK/install.amd/initrd.gz"
INITRD_GTK="$ISO_WORK/install.amd/gtk/initrd.gz"

for initrd in "$INITRD_GZ" "$INITRD_GTK"; do
    if [ -f "$initrd" ]; then
        echo "[+] Processando $(basename $initrd)..." | tee -a "$LOG"
        
        # Descompacta
        mkdir -p /tmp/initrd_extract
        cd /tmp/initrd_extract
        zcat "$initrd" | cpio -idm 2>/dev/null || true
        
        # Remove speakup e componentes de accessibility
        rm -rf ./usr/lib/speakup* ./lib/speakup* ./usr/share/speakup* 2>/dev/null || true
        rm -f ./usr/bin/speakup* ./lib/udev/rules.d/*speakup* 2>/dev/null || true
        find . -name "*speakup*" -delete 2>/dev/null || true
        find . -name "*accessibility*" -delete 2>/dev/null || true
        
        # Recompacta o initrd
        find . | cpio --quiet -H newc -o | gzip -9 > "$initrd"
        
        cd "$ISO_WORK"
        rm -rf /tmp/initrd_extract
        echo "[+] initrd $(basename $initrd) limpo com sucesso" | tee -a "$LOG"
    fi
done


# ==========================
# AJUSTAR BOOT - ANTI-SPEECH FORTE (Debian Trixie)
# ==========================
echo "[+] Ajustando boot (GRUB + ISOLINUX) anti-speech forte..." | tee -a "$LOG"

KERNEL_PARAMS="auto=true priority=critical preseed/file=/cdrom/blue3/preseed.cfg vga=788 \
               debian-installer/speech=false speakup.synth=none speakup.synth=off \
               debian-installer/disable-speech=true noaccessibility \
               DEBCONF_DEBUG=5"

# BIOS - ISOLINUX (txt.cfg) - substituição limpa
TXT_CFG="$ISO_WORK/isolinux/txt.cfg"
if [ -f "$TXT_CFG" ]; then
    sed -i '/append / s|append .*|append initrd=/install.amd/initrd.gz '"${KERNEL_PARAMS}"' --- quiet|' "$TXT_CFG"
    sed -i '/menu default/d' "$TXT_CFG" 2>/dev/null || true
    sed -i '/^label install/a\        menu default' "$TXT_CFG"
    cat >> "$ISO_WORK/isolinux/txt.cfg" <<EOF
        label auto
        menu label ^Automated install
        kernel /install.amd/vmlinuz
        append initrd=/install.amd/initrd.gz auto=true priority=critical preseed/file=/cdrom/blue3/preseed.cfg
EOF
    sed -i 's/^default.*/default auto/' "$ISO_WORK/isolinux/isolinux.cfg"
    sed -i 's/^default.*/default install/' "$ISO_WORK/isolinux/isolinux.cfg"
fi

# UEFI - GRUB
GRUB_CFG="$ISO_WORK/boot/grub/grub.cfg"
if [ -f "$GRUB_CFG" ]; then
    sed -i '/set timeout=/d' "$GRUB_CFG" 2>/dev/null || true
    sed -i '/set default=/d' "$GRUB_CFG" 2>/dev/null || true
    echo 'set timeout=0' >> "$GRUB_CFG"
    echo 'set default="0"' >> "$GRUB_CFG"
    
    # Limpa qualquer resíduo antigo
    sed -i 's/ auto=true priority=critical file=.*vga=788 quiet//g' "$GRUB_CFG"
    sed -i "/linux.*vmlinuz/ s|\$| ${KERNEL_PARAMS}|" "$GRUB_CFG"
fi

# Timeout baixo em todos os arquivos isolinux
for cfg in "$ISO_WORK/isolinux/"*.cfg; do
    [ -f "$cfg" ] && sed -i 's/^timeout.*/timeout 20/' "$cfg" 2>/dev/null || true
done






















# ==========================
# MD5SUM
# ==========================
echo "[+] Atualizando md5sum..." | tee -a "$LOG"
cd "$ISO_WORK"

chmod +w md5sum.txt 2>/dev/null || true
find . -type f ! -path './md5sum.txt' -print0 | xargs -0 md5sum > md5sum.txt
chmod -w md5sum.txt 2>/dev/null || true

# ==========================
# GERAR ISO
# ==========================
echo "[+] Gerando ISO..." | tee -a "$LOG"

xorriso -as mkisofs \
    -r -J -joliet-long \
    -V "Blue3_Debian_${DATA}" \
    -isohybrid-mbr "$ISO_ORIG" \
    -b isolinux/isolinux.bin \
    -c isolinux/boot.cat \
    -boot-load-size 4 \
    -boot-info-table \
    -no-emul-boot \
    -eltorito-alt-boot \
    -e boot/grub/efi.img \
    -no-emul-boot \
    -isohybrid-gpt-basdat \
    -o "$ISO_OUT" \
    "$ISO_WORK" >> "$LOG" 2>&1

echo "[+] ISO gerada: $ISO_OUT" | tee -a "$LOG"
echo "[+] Finalizado em $(date)" | tee -a "$LOG"

# RESOLVENDO
sudo chown samir:samir "$ISO_OUT"
echo "[+] ISO permissao ok: $ISO_OUT" | tee -a "$LOG"