#!/bin/bash

# Script per creare una ISO Live CD con Buildroot

# --- Variabili Configurabili ---
BUILDROOT_PATH=""
CONFIG_FILE="" # Percorso del tuo file di configurazione Buildroot (es. my_x86_live_defconfig)
TARGET_ARCH=""  # Opzioni: "x86", "x86_64", "arm"
OUTPUT_DIR="$(pwd)/buildroot_output_iso" # Directory di output per l'immagine ISO

# --- Funzioni di Utility ---
print_usage() {
  echo "Utilizzo: $0 -b <buildroot_path> -c <config_file> -a <architettura>"
  echo ""
  echo "Opzioni:"
  echo "  -b <buildroot_path>  Percorso della directory principale di Buildroot."
  echo "  -c <config_file>     Percorso del file di configurazione Buildroot (defconfig o .config)."
  echo "  -a <architettura>    Architettura di destinazione: 'x86', 'x86_64', o 'arm'."
  echo "  -h                   Mostra questo messaggio di aiuto."
  echo ""
  echo "Esempio: $0 -b ~/buildroot -c configs/my_live_x86_64_defconfig -a x86_64"
}

print_error() {
  echo "[ERRORE] $1" >&2
  exit 1
}

print_info() {
  echo "[INFO] $1"
}

# --- Parsing degli Argomenti ---
while getopts "b:c:a:h" opt; do
  case ${opt} in
    b )
      BUILDROOT_PATH=$(realpath "${OPTARG}")
      ;;
    c )
      CONFIG_FILE=$(realpath "${OPTARG}")
      ;;
    a )
      TARGET_ARCH="${OPTARG}"
      ;;
    h )
      print_usage
      exit 0
      ;;
    \? )
      print_usage
      exit 1
      ;;
  esac
done

# --- Validazione degli Input ---
if [ -z "${BUILDROOT_PATH}" ]; then
  print_error "Il percorso di Buildroot (-b) è obbligatorio."
fi

if [ ! -d "${BUILDROOT_PATH}" ]; then
  print_error "La directory di Buildroot '${BUILDROOT_PATH}' non esiste."
fi

if [ -z "${CONFIG_FILE}" ]; then
  print_error "Il file di configurazione (-c) è obbligatorio."
fi

if [ ! -f "${CONFIG_FILE}" ]; then
  print_error "Il file di configurazione '${CONFIG_FILE}' non è stato trovato."
fi

if [ -z "${TARGET_ARCH}" ]; then
  print_error "L'architettura di destinazione (-a) è obbligatoria."
fi

if [[ "${TARGET_ARCH}" != "x86" && "${TARGET_ARCH}" != "x86_64" && "${TARGET_ARCH}" != "arm" ]]; then
  print_error "Architettura non valida: '${TARGET_ARCH}'. Scegliere tra 'x86', 'x86_64', 'arm'."
fi

# --- Preparazione dell'Ambiente Buildroot ---
cd "${BUILDROOT_PATH}" || exit 1
mkdir -p "${OUTPUT_DIR}"

print_info "Pulizia della configurazione precedente (se presente)..."
make O="${OUTPUT_DIR}" distclean

# --- Selezione dell'Architettura e Caricamento Configurazione ---
print_info "Configurazione di Buildroot per l'architettura: ${TARGET_ARCH}"

# Copia il file di configurazione fornito nella directory di output di Buildroot
# Buildroot si aspetta di trovare il .config lì.
cp "${CONFIG_FILE}" "${OUTPUT_DIR}/.config"

# In alternativa, se il tuo CONFIG_FILE è una defconfig registrata in Buildroot:
# make O="${OUTPUT_DIR}" BR2_EXTERNAL=path/to/your/external/tree your_defconfig_name
# Per ora, assumiamo che CONFIG_FILE sia un .config completo o una defconfig da copiare.

# A seconda dell'architettura, potresti voler impostare variabili specifiche
# o assicurarti che la tua defconfig sia corretta.
# Questo è un punto cruciale: la tua CONFIG_FILE DEVE essere già impostata
# per l'architettura corretta e per generare un'immagine ISO avviabile.

# Esempio di come potresti voler forzare alcune opzioni (NON RACCOMANDATO senza una comprensione profonda)
# if [ "${TARGET_ARCH}" == "x86_64" ]; then
#   # Assicurati che il .config contenga le opzioni corrette per x86_64 e per una ISO
#   # Esempio: BR2_x86_64=y, BR2_LINUX_KERNEL=y, BR2_TARGET_ROOTFS_SQUASHFS=y, BR2_TARGET_GRUB2=y, ecc.
#   print_info "Assicurati che la configurazione '${CONFIG_FILE}' sia adatta per x86_64 e per una ISO Live."
# elif [ "${TARGET_ARCH}" == "x86" ]; then
#   print_info "Assicurati che la configurazione '${CONFIG_FILE}' sia adatta per x86 e per una ISO Live."
# elif [ "${TARGET_ARCH}" == "arm" ]; then
#   print_info "Assicurati che la configurazione '${CONFIG_FILE}' sia adatta per ARM."
#   print_info "Nota: la creazione di ISO Live per ARM è complessa e dipende dalla piattaforma specifica."
#   print_info "Probabilmente vorrai un'immagine per SD card (es. .img) piuttosto che una .iso generica."
# fi

# Sincronizza la configurazione .config
make O="${OUTPUT_DIR}" olddefconfig

# --- Avvio della Build ---
print_info "Avvio del processo di build di Buildroot... Questo potrebbe richiedere molto tempo."
if ! make O="${OUTPUT_DIR}"; then
  print_error "La build di Buildroot è fallita. Controlla i log in '${OUTPUT_DIR}/build/'."
fi

# --- Verifica dell'Output ---
# Il nome esatto e la posizione dell'immagine ISO dipendono fortemente dalla tua
# configurazione di Buildroot (es. BR2_TARGET_IMAGES, tipo di bootloader, ecc.)
# Solitamente si trova in "${OUTPUT_DIR}/images/"
ISO_PATH=""
if [ -f "${OUTPUT_DIR}/images/rootfs.iso9660" ]; then # Nome comune se usi syslinux/isolinux
    ISO_PATH="${OUTPUT_DIR}/images/rootfs.iso9660"
elif [ -f "${OUTPUT_DIR}/images/boot.iso" ]; then # Altro nome possibile
    ISO_PATH="${OUTPUT_DIR}/images/boot.iso"
elif ls "${OUTPUT_DIR}/images/"*.iso 1> /dev/null 2>&1; then # Cerca qualsiasi file .iso
    ISO_PATH=$(ls "${OUTPUT_DIR}/images/"*.iso | head -n 1)
fi

if [ -n "${ISO_PATH}" ] && [ -f "${ISO_PATH}" ]; then
  print_info "Build completata con successo!"
  print_info "L'immagine ISO è disponibile in: ${ISO_PATH}"
  print_info "Puoi scriverla su un drive USB o usarla in una macchina virtuale."
else
  print_error "Build completata, ma l'immagine ISO non è stata trovata nella directory attesa ('${OUTPUT_DIR}/images/')."
  print_error "Controlla la configurazione di Buildroot (Filesystem images -> iso image)."
  print_info "I file generati si trovano in: ${OUTPUT_DIR}/images/"
  ls -l "${OUTPUT_DIR}/images/"
fi

# Per ARM, potresti cercare un file .img o un altro formato specifico per la board
if [ "${TARGET_ARCH}" == "arm" ]; then
    print_info "Per ARM, controlla '${OUTPUT_DIR}/images/' per il tipo di immagine appropriato (es. sdcard.img)."
fi

exit 0