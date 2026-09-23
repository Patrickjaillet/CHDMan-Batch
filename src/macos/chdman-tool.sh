#!/usr/bin/env bash
# ============================================================
#  CHDMAN TOOL - Interface complete pour chdman
#  Compression / Extraction / Verification de fichiers CHD
#  Formats supportes en entree : CUE, GDI, ISO (CD et DVD)
#  Internationalisation : i18n/*.lang (EN/FR/DE/ES/JA/ZH)
#  Compatible Linux et macOS (bash >= 3.2, macOS par defaut inclus)
# ============================================================

# --- Portabilite bash 3.2 (macOS) : pas de "set -u" sur variables
#     associatives non supportees en 3.2 ; on reste en tableaux/vars
#     scalaires classiques et on evite toute syntaxe bash 4+.
set -o errexit -o pipefail
IFS=$'\n\t'

# ------------------------------------------------------------
# Resolution du dossier du script (portable, gere les liens
# symboliques et les espaces dans le chemin)
# ------------------------------------------------------------
resolve_script_dir() {
    local source="${BASH_SOURCE[0]}"
    while [ -h "$source" ]; do
        local dir
        dir="$(cd -P "$(dirname "$source")" >/dev/null 2>&1 && pwd)"
        source="$(readlink "$source")"
        case "$source" in
            /*) ;;
            *) source="$dir/$source" ;;
        esac
    done
    cd -P "$(dirname "$source")" >/dev/null 2>&1 && pwd
}

SCRIPT_DIR="$(resolve_script_dir)"
I18N_DIR="${SCRIPT_DIR}/i18n"
CONFIG_FILE="${SCRIPT_DIR}/chdman-tool.local.cfg"
DEFAULT_LANG="en"

# ------------------------------------------------------------
# Journal d'execution : un fichier par lancement du script,
# horodate dans son nom, cree a cote du script (portable). Le
# nom est fige une seule fois au demarrage ; le contenu est
# ecrit par log_command() a chaque commande chdman executee
# (ROADMAP.md, Phase 3). Couvert par le motif "*.log" existant
# dans .gitignore.
# ------------------------------------------------------------
LOG_FILE="${SCRIPT_DIR}/chdman-tool_$(date +%Y%m%d_%H%M%S).log"

# ------------------------------------------------------------
# Detection de l'OS et de l'architecture, puis du binaire
# chdman correspondant.
#
# Deux emplacements sont recherches, dans cet ordre :
#  1) A plat a cote du script (convention du paquet de
#     distribution portable, identique a la convention Windows
#     ou chdman.exe est place a cote de CHDMAN_Tool.bat) :
#     "${SCRIPT_DIR}/chdman"
#  2) Dans l'arborescence source du depot, ou le binaire vit
#     dans bin/<os>/ separement de src/<os>/ : "bin/<os>/chdman"
# Pour chaque emplacement, plusieurs noms de fichier sont
# essayes, du plus specifique (os+arch) au plus generique (cas
# d'un binaire universel/fat macOS ou d'un unique build fourni
# pour la plateforme).
#
# Cas particulier macOS : le binaire "chdman" issu du paquet
# tiers @emmercm/chdman-darwin-* (voir MEMOIRE.md Entree 18) est
# lie dynamiquement a "libSDL3.0.dylib" via @executable_path,
# c'est-a-dire que cette bibliotheque doit se trouver dans le
# MEME dossier que le binaire effectivement execute. Les deux
# variantes (x64/arm64) de cette bibliotheque ne sont pas
# interchangeables (contenu different par architecture) et
# portent donc le meme nom de fichier dans des sous-dossiers
# separes ("bin/macos/x64/", "bin/macos/arm64/") plutot qu'a
# plat dans "bin/macos/". Dans le paquet de distribution final,
# seul le sous-dossier correspondant a l'architecture cible est
# livre a plat a cote du script (voir COMPILATION.md section 8).
# ------------------------------------------------------------
detect_chdman_binary() {
    local os arch bin_dir candidate search_dir
    local -a candidates
    local -a search_dirs

    case "$(uname -s)" in
        Linux*)  os="linux" ;;
        Darwin*) os="macos" ;;
        *)
            echo "[ERROR] Unsupported operating system: $(uname -s)" >&2
            return 1
            ;;
    esac

    case "$(uname -m)" in
        x86_64|amd64)        arch="x64" ;;
        arm64|aarch64)       arch="arm64" ;;
        *)                   arch="$(uname -m)" ;;
    esac

    bin_dir="${SCRIPT_DIR}/../../bin/${os}"
    bin_dir="$(cd "${bin_dir}" >/dev/null 2>&1 && pwd || echo "${bin_dir}")"

    # Ordre : paquet de distribution (a plat, a cote du script)
    # d'abord, puis arborescence source du depot (bin/<os>/
    # separe de src/<os>/).
    search_dirs=("${SCRIPT_DIR}" "${bin_dir}")

    # Tableau plutot que decoupage sur IFS (IFS est redefini plus
    # bas dans le script et ne contient plus l'espace).
    candidates=("chdman-${os}-${arch}" "chdman-${arch}" "chdman")

    for search_dir in "${search_dirs[@]}"; do
        for candidate in "${candidates[@]}"; do
            if [ -f "${search_dir}/${candidate}" ]; then
                echo "${search_dir}/${candidate}"
                return 0
            fi
        done
    done

    # Cas particulier macOS, arborescence source du depot
    # uniquement : "bin/macos/<arch>/chdman", avec sa
    # "libSDL3.0.dylib" dans le meme sous-dossier (voir
    # commentaire ci-dessus). Non applicable a Linux (binaire
    # autonome, deja trouve par la boucle precedente si present).
    if [ "${os}" = "macos" ] && [ -f "${bin_dir}/${arch}/chdman" ]; then
        echo "${bin_dir}/${arch}/chdman"
        return 0
    fi

    return 1
}

CHDMAN="$(detect_chdman_binary || true)"

# ------------------------------------------------------------
# Verifie que le binaire chdman est present et executable
# (message affiche en anglais : aucun fichier de langue n'est
# encore garanti charge a ce stade - meme choix que la version
# Windows, voir MEMOIRE.md Entree 10)
# ------------------------------------------------------------
if [ -z "${CHDMAN}" ] || [ ! -f "${CHDMAN}" ]; then
    echo ""
    echo " [ERROR] chdman binary was not found for this platform in:"
    echo " ${SCRIPT_DIR}/../../bin/$(uname -s | tr '[:upper:]' '[:lower:]')/"
    echo ""
    echo " Reinstall the portable package, or place a compatible"
    echo " chdman binary in that folder."
    echo ""
    read -r -p "Press Enter to exit..." _
    exit 1
fi

if [ ! -x "${CHDMAN}" ]; then
    chmod +x "${CHDMAN}" 2>/dev/null || {
        echo ""
        echo " [ERROR] chdman binary is not executable and could not be"
        echo " made executable: ${CHDMAN}"
        echo ""
        read -r -p "Press Enter to exit..." _
        exit 1
    }
fi

# ------------------------------------------------------------
# LOAD_LANG - charge le fichier i18n/<code>.lang dans des
# variables shell (une variable par cle=valeur). Le BOM UTF-8
# eventuel en tete de fichier est retire ligne par ligne.
# ------------------------------------------------------------
load_lang() {
    local lang_code="$1"
    local lang_file="${I18N_DIR}/${lang_code}.lang"
    local first_line=1

    if [ ! -f "${lang_file}" ]; then
        lang_file="${I18N_DIR}/${DEFAULT_LANG}.lang"
    fi

    while IFS= read -r line || [ -n "${line}" ]; do
        # Retire le BOM UTF-8 (EF BB BF) uniquement sur la toute
        # premiere ligne du fichier, s'il est present.
        if [ "${first_line}" -eq 1 ]; then
            line="${line#$'\xEF\xBB\xBF'}"
            first_line=0
        fi

        # Ignore les lignes vides et les commentaires (prefixe ";")
        case "${line}" in
            ""|";"*) continue ;;
        esac

        local key="${line%%=*}"
        local value="${line#*=}"

        # Cle valide uniquement (evite d'ecraser des variables
        # internes du script via un fichier .lang corrompu)
        case "${key}" in
            [A-Za-z_][A-Za-z0-9_]*) ;;
            *) continue ;;
        esac

        printf -v "${key}" '%s' "${value}"
        export "${key?}"
    done < "${lang_file}"

    ACTIVE_LANG="${lang_code}"
}

# ------------------------------------------------------------
# DETECT_SYSTEM_LANG - detection de la langue systeme via les
# variables d'environnement standard POSIX (LANG, LC_ALL,
# LC_MESSAGES), dans cet ordre de priorite.
# ------------------------------------------------------------
detect_system_lang() {
    local sys_locale="" prefix=""

    for var in "${LC_ALL:-}" "${LC_MESSAGES:-}" "${LANG:-}"; do
        if [ -n "${var}" ]; then
            sys_locale="${var}"
            break
        fi
    done

    if [ -z "${sys_locale}" ]; then
        return 1
    fi

    prefix="$(echo "${sys_locale}" | cut -c1-2 | tr '[:upper:]' '[:lower:]')"

    case "${prefix}" in
        fr|de|es|ja|zh|en) echo "${prefix}" ; return 0 ;;
        *) return 1 ;;
    esac
}

# ------------------------------------------------------------
# SAVE_LANG - memorise la langue choisie dans le fichier de
# configuration local (portable, a cote du script)
# ------------------------------------------------------------
save_lang() {
    printf 'LANG=%s\n' "${ACTIVE_LANG}" > "${CONFIG_FILE}"
}

# ------------------------------------------------------------
# Determination de la langue active au demarrage
# Ordre de priorite :
#  1) Langue memorisee dans le fichier de configuration local
#  2) Langue detectee depuis les variables d'environnement systeme
#  3) Anglais par defaut
# ------------------------------------------------------------
FIRST_RUN=0
ACTIVE_LANG=""

if [ -f "${CONFIG_FILE}" ]; then
    while IFS= read -r cfg_line || [ -n "${cfg_line}" ]; do
        case "${cfg_line}" in
            LANG=*) ACTIVE_LANG="${cfg_line#LANG=}" ;;
        esac
    done < "${CONFIG_FILE}"
else
    FIRST_RUN=1
fi

if [ -z "${ACTIVE_LANG}" ]; then
    ACTIVE_LANG="$(detect_system_lang || echo "")"
fi

if [ -z "${ACTIVE_LANG}" ] || [ ! -f "${I18N_DIR}/${ACTIVE_LANG}.lang" ]; then
    ACTIVE_LANG="${DEFAULT_LANG}"
fi

load_lang "${ACTIVE_LANG}"

# ------------------------------------------------------------
# LANGUAGE_MENU - selecteur de langue interactif
# ------------------------------------------------------------
language_menu() {
    local choice
    while true; do
        clear
        echo "============================================================"
        echo "  ${LANGSEL_TITLE}"
        echo "============================================================"
        echo ""
        echo "${LANGSEL_PROMPT}"
        echo ""
        echo "  ${LANGSEL_1}"
        echo "  ${LANGSEL_2}"
        echo "  ${LANGSEL_3}"
        echo "  ${LANGSEL_4}"
        echo "  ${LANGSEL_5}"
        echo "  ${LANGSEL_6}"
        echo ""
        echo "============================================================"
        read -r -p "${LANGSEL_CHOICE} " choice

        case "${choice}" in
            1) load_lang "en"; break ;;
            2) load_lang "fr"; break ;;
            3) load_lang "de"; break ;;
            4) load_lang "es"; break ;;
            5) load_lang "ja"; break ;;
            6) load_lang "zh"; break ;;
            *)
                echo ""
                echo "${LANGSEL_INVALID}"
                read -r -p "" _
                ;;
        esac
    done
    save_lang
}

# Si aucun fichier de configuration n'existe encore (premier
# lancement), proposer explicitement le choix de langue avant
# d'entrer dans le menu.
if [ "${FIRST_RUN}" -eq 1 ]; then
    language_menu
fi

# ------------------------------------------------------------
# Gestion de l'interruption utilisateur (Ctrl+C) en cours de
# traitement : message propre, sortie sans code d'erreur brut,
# nettoyage du repertoire de travail (popd implicite via trap).
# ------------------------------------------------------------
on_interrupt() {
    echo ""
    echo "${INTERRUPTED:-[INTERRUPTED]}"
    exit 130
}
trap on_interrupt INT TERM

# ------------------------------------------------------------
# Nettoie une chaine de chemin saisie par l'utilisateur :
# retire les guillemets englobants (cas d'un glisser-deposer
# depuis certains gestionnaires de fichiers) et les
# antislashs d'echappement ajoutes par un glisser-deposer
# depuis un terminal (ex: "Mon\ Dossier").
# ------------------------------------------------------------
clean_path() {
    local p="$1"
    p="${p%\"}"
    p="${p#\"}"
    p="${p%\'}"
    p="${p#\'}"
    printf '%s' "${p}"
}

# ------------------------------------------------------------
# confirm_overwrite - si le fichier de sortie donne en argument
# existe deja, demande une confirmation interactive (o/N,
# reponse par defaut = non) avant de poursuivre. Retourne 0 si
# l'operation doit continuer (fichier absent, ou confirmation
# positive), 1 sinon (annulation demandee par l'utilisateur).
# Remplace l'usage systematique de "--force" sans confirmation
# (ROADMAP.md, Phase 3).
# ------------------------------------------------------------
confirm_overwrite() {
    local out="$1" answer
    if [ ! -e "${out}" ]; then
        return 0
    fi
    echo ""
    echo "${OVERWRITE_PROMPT}"
    echo "  ${out}"
    read -r -p "${OVERWRITE_CONFIRM} " answer
    # Accepte "oui" dans les 6 langues du projet : y/Y (en/de reponse
    # affichee comme "y/N" pour toutes les langues, voir i18n/*.lang),
    # o/O (fr "oui"), s/S (es "si"), j/J (de "ja").
    case "${answer}" in
        [yYoOsSjJ]) return 0 ;;
        *)
            echo ""
            echo "${OVERWRITE_CANCELLED}"
            read -r -p "" _
            return 1
            ;;
    esac
}

# ------------------------------------------------------------
# log_command - consigne une commande chdman executee et son
# resultat dans le journal d'execution (LOG_FILE). Le fichier
# n'est cree qu'au premier appel (aucun fichier residuel si le
# script est lance puis quitte sans effectuer d'operation).
# Arguments : $1 sous-commande chdman (createcd, verify, ...),
# $2 chemin d'entree, $3 chemin de sortie (peut etre vide pour
# verify/info), $4 resultat ("OK" ou "FAILED").
# ------------------------------------------------------------
log_command() {
    local subcmd="$1" in_path="$2" out_path="$3" result="$4"
    if [ ! -f "${LOG_FILE}" ]; then
        {
            echo "CHDman Batch - Execution log"
            echo "Started: $(date '+%Y-%m-%d %H:%M:%S')"
            echo "============================================================"
        } > "${LOG_FILE}"
    fi
    if [ -n "${out_path}" ]; then
        printf '[%s] %-6s %-12s input="%s" output="%s"\n' \
            "$(date '+%Y-%m-%d %H:%M:%S')" "${result}" "${subcmd}" "${in_path}" "${out_path}" \
            >> "${LOG_FILE}"
    else
        printf '[%s] %-6s %-12s input="%s"\n' \
            "$(date '+%Y-%m-%d %H:%M:%S')" "${result}" "${subcmd}" "${in_path}" \
            >> "${LOG_FILE}"
    fi
}

# ============================================================
# MENU PRINCIPAL
# ============================================================
main_menu() {
    local choice
    while true; do
        clear
        echo "============================================================"
        echo "                    ${MENU_TITLE}"
        echo "============================================================"
        echo ""
        echo "  ${MENU_LANG_LABEL} : ${LANG_NAME}"
        echo ""
        echo "  ${MENU_1}"
        echo "  ${MENU_2}"
        echo "  ${MENU_3}"
        echo "  ${MENU_4}"
        echo "  ${MENU_5}"
        echo "  ${MENU_6}"
        echo "  ${MENU_7}"
        echo "  ${MENU_8}"
        echo "  ${MENU_9}"
        echo ""
        echo "============================================================"
        read -r -p "${MENU_CHOICE} " choice

        case "${choice}" in
            1) create_single ;;
            2) create_batch ;;
            3) extract_single ;;
            4) extract_batch ;;
            5) verify_chd ;;
            6) info_chd ;;
            7) create_hd ;;
            8) language_menu ;;
            9) goodbye ;;
            *)
                echo "${MENU_INVALID}"
                read -r -p "" _
                ;;
        esac
    done
}

goodbye() {
    echo ""
    echo "${GOODBYE}"
    sleep 2
    exit 0
}

# ============================================================
# 1) CREATION - UN SEUL FICHIER
# ============================================================
create_single() {
    local src src_dir src_name dtype subcmd out

    clear
    echo "============================================================"
    echo "  ${CREATE_SINGLE_TITLE}"
    echo "============================================================"
    echo ""
    echo "${PROMPT_DROP_FILE_CUE}"
    echo "${PROMPT_THEN_ENTER}"
    echo ""
    read -r -p "${PROMPT_SOURCE_FILE} " src
    src="$(clean_path "${src}")"

    if [ ! -f "${src}" ]; then
        echo ""
        echo "${ERR_FILE_NOT_FOUND} ${src}"
        read -r -p "" _
        return
    fi

    src_dir="$(cd "$(dirname "${src}")" >/dev/null 2>&1 && pwd)/"
    src_name="$(basename "${src}")"
    src_name="${src_name%.*}"

    echo ""
    echo "${DISK_TYPE_PROMPT}"
    echo "  ${DISK_TYPE_CD}"
    echo "  ${DISK_TYPE_DVD}"
    read -r -p "${DISK_TYPE_CHOICE} " dtype

    if [ "${dtype}" = "2" ]; then
        subcmd="createdvd"
    else
        subcmd="createcd"
    fi

    out="${src_dir}${src_name}.chd"

    confirm_overwrite "${out}" || return

    echo ""
    echo "------------------------------------------------------------"
    echo " ${COMMAND_LABEL} \"${CHDMAN}\" ${subcmd} --force --input \"${src}\" --output \"${out}\""
    echo "------------------------------------------------------------"
    echo ""

    "${CHDMAN}" "${subcmd}" --force --input "${src}" --output "${out}" || true

    echo ""
    if [ -f "${out}" ]; then
        echo "${CREATE_OK} ${out}"
        log_command "${subcmd}" "${src}" "${out}" "OK"
    else
        echo "${CREATE_FAILED}"
        log_command "${subcmd}" "${src}" "${out}" "FAILED"
    fi
    echo ""
    read -r -p "" _
}

# ============================================================
# 2) CREATION - EN LOT (dossier + sous-dossiers)
# ============================================================
do_create_cd() {
    local f="$1" f_dir f_name out
    f_dir="$(cd "$(dirname "${f}")" >/dev/null 2>&1 && pwd)/"
    f_name="$(basename "${f}")"
    f_name="${f_name%.*}"
    out="${f_dir}${f_name}.chd"

    echo ""
    echo "${BATCH_CD_LABEL} ${f}"
    if "${CHDMAN}" createcd --force --input "${f}" --output "${out}"; then :; fi
    if [ -f "${out}" ]; then
        BATCH_COUNT=$((BATCH_COUNT + 1))
        log_command "createcd" "${f}" "${out}" "OK"
    else
        BATCH_FAIL=$((BATCH_FAIL + 1))
        log_command "createcd" "${f}" "${out}" "FAILED"
    fi
}

do_create_dvd() {
    local f="$1" f_dir f_name out
    f_dir="$(cd "$(dirname "${f}")" >/dev/null 2>&1 && pwd)/"
    f_name="$(basename "${f}")"
    f_name="${f_name%.*}"
    out="${f_dir}${f_name}.chd"

    echo ""
    echo "${BATCH_DVD_LABEL} ${f}"
    if "${CHDMAN}" createdvd --force --input "${f}" --output "${out}"; then :; fi
    if [ -f "${out}" ]; then
        BATCH_COUNT=$((BATCH_COUNT + 1))
        log_command "createdvd" "${f}" "${out}" "OK"
    else
        BATCH_FAIL=$((BATCH_FAIL + 1))
        log_command "createdvd" "${f}" "${out}" "FAILED"
    fi
}

create_batch() {
    local src_root btype f

    clear
    echo "============================================================"
    echo "  ${CREATE_BATCH_TITLE}"
    echo "============================================================"
    echo ""
    echo "${PROMPT_DROP_FOLDER}"
    echo "${PROMPT_THEN_ENTER}"
    echo ""
    read -r -p "${PROMPT_SOURCE_FOLDER} " src_root
    src_root="$(clean_path "${src_root}")"

    if [ ! -d "${src_root}" ]; then
        echo ""
        echo "${ERR_FOLDER_NOT_FOUND} ${src_root}"
        read -r -p "" _
        return
    fi

    echo ""
    echo "${BATCH_TYPE_PROMPT}"
    echo "  ${BATCH_TYPE_CD}"
    echo "  ${BATCH_TYPE_DVD}"
    echo "  ${BATCH_TYPE_BOTH}"
    read -r -p "${BATCH_TYPE_CHOICE} " btype

    # Compte, sans rien executer, le nombre de fichiers ".chd" de
    # sortie qui existent deja et seraient ecrases par ce lot, pour
    # demander une confirmation groupee unique plutot qu'une
    # confirmation par fichier (impraticable sur un lot).
    local existing_count=0 f_dir f_name
    case "${btype}" in
        1|3)
            while IFS= read -r -d '' f; do
                f_dir="$(cd "$(dirname "${f}")" >/dev/null 2>&1 && pwd)/"
                f_name="$(basename "${f}")"; f_name="${f_name%.*}"
                [ -e "${f_dir}${f_name}.chd" ] && existing_count=$((existing_count + 1))
            done < <(find "${src_root}" -type f \( -iname "*.cue" -o -iname "*.gdi" \) -print0)
            ;;
    esac
    case "${btype}" in
        2|3)
            while IFS= read -r -d '' f; do
                f_dir="$(cd "$(dirname "${f}")" >/dev/null 2>&1 && pwd)/"
                f_name="$(basename "${f}")"; f_name="${f_name%.*}"
                [ -e "${f_dir}${f_name}.chd" ] && existing_count=$((existing_count + 1))
            done < <(find "${src_root}" -type f -iname "*.iso" -print0)
            ;;
    esac

    if [ "${existing_count}" -gt 0 ]; then
        local batch_answer
        echo ""
        echo "${existing_count} ${BATCH_OVERWRITE_PROMPT}"
        read -r -p "${BATCH_OVERWRITE_CONFIRM} " batch_answer
        case "${batch_answer}" in
            [yYoOsSjJ]) : ;;
            *)
                echo ""
                echo "${OVERWRITE_CANCELLED}"
                read -r -p "" _
                return
                ;;
        esac
    fi

    BATCH_COUNT=0
    BATCH_FAIL=0

    # Substitution de processus (< <(...)) plutot qu'un pipe
    # (find ... | while ...) : un pipe placerait le "while" dans
    # un sous-shell et les compteurs BATCH_COUNT/BATCH_FAIL
    # modifies a l'interieur seraient alors perdus au retour.
    case "${btype}" in
        1)
            while IFS= read -r -d '' f; do do_create_cd "${f}"; done \
                < <(find "${src_root}" -type f \( -iname "*.cue" -o -iname "*.gdi" \) -print0)
            ;;
        2)
            while IFS= read -r -d '' f; do do_create_dvd "${f}"; done \
                < <(find "${src_root}" -type f -iname "*.iso" -print0)
            ;;
        3)
            while IFS= read -r -d '' f; do do_create_cd "${f}"; done \
                < <(find "${src_root}" -type f \( -iname "*.cue" -o -iname "*.gdi" \) -print0)
            while IFS= read -r -d '' f; do do_create_dvd "${f}"; done \
                < <(find "${src_root}" -type f -iname "*.iso" -print0)
            ;;
    esac

    echo ""
    echo "============================================================"
    echo " ${BATCH_DONE} ${BATCH_COUNT}   ${BATCH_FAILURES} ${BATCH_FAIL}"
    echo "============================================================"
    read -r -p "" _
}

# ============================================================
# 3) EXTRACTION - UN SEUL FICHIER
# ============================================================
extract_single() {
    local src src_dir src_name etype subcmd out hunksize unitsize
    local -a extra_args

    clear
    echo "============================================================"
    echo "  ${EXTRACT_SINGLE_TITLE}"
    echo "============================================================"
    echo ""
    echo "${PROMPT_DROP_FILE_CHD}"
    echo "${PROMPT_THEN_ENTER}"
    echo ""
    read -r -p "${PROMPT_CHD_FILE} " src
    src="$(clean_path "${src}")"

    if [ ! -f "${src}" ]; then
        echo ""
        echo "${ERR_FILE_NOT_FOUND} ${src}"
        read -r -p "" _
        return
    fi

    src_dir="$(cd "$(dirname "${src}")" >/dev/null 2>&1 && pwd)/"
    src_name="$(basename "${src}")"
    src_name="${src_name%.*}"

    echo ""
    echo "${OUTPUT_FORMAT_PROMPT}"
    echo "  ${OUTPUT_FORMAT_CUEBIN}"
    echo "  ${OUTPUT_FORMAT_GDI}"
    echo "  ${OUTPUT_FORMAT_ISO}"
    echo "  ${OUTPUT_FORMAT_RAW}"
    read -r -p "${OUTPUT_FORMAT_CHOICE} " etype

    extra_args=()
    case "${etype}" in
        1) subcmd="extractcd"; out="${src_dir}${src_name}.cue" ;;
        2) subcmd="extractcd"; out="${src_dir}${src_name}.gdi" ;;
        3) subcmd="extractdvd"; out="${src_dir}${src_name}.iso" ;;
        4)
            subcmd="extractraw"
            out="${src_dir}${src_name}.raw"
            read -r -p "${PROMPT_UNITSIZE_EXTRACT} " unitsize
            [ -z "${unitsize}" ] && unitsize="2048"
            extra_args=(--unitsize "${unitsize}")
            ;;
        *) subcmd="extractcd"; out="${src_dir}${src_name}.cue" ;;
    esac

    confirm_overwrite "${out}" || return

    echo ""
    echo "------------------------------------------------------------"
    echo " ${COMMAND_LABEL} \"${CHDMAN}\" ${subcmd} --force --input \"${src}\" --output \"${out}\" ${extra_args[*]}"
    echo "------------------------------------------------------------"
    echo ""

    "${CHDMAN}" "${subcmd}" --force --input "${src}" --output "${out}" "${extra_args[@]}" || true

    echo ""
    if [ -f "${out}" ]; then
        echo "${EXTRACT_OK} ${out}"
        log_command "${subcmd}" "${src}" "${out}" "OK"
    else
        echo "${EXTRACT_FAILED}"
        log_command "${subcmd}" "${src}" "${out}" "FAILED"
    fi
    echo ""
    read -r -p "" _
}

# ============================================================
# 4) EXTRACTION - EN LOT
# ============================================================
do_extract() {
    local f="$1" etype2="$2" batch_unitsize="$3" f_dir f_name subcmd out
    local -a extra_args

    f_dir="$(cd "$(dirname "${f}")" >/dev/null 2>&1 && pwd)/"
    f_name="$(basename "${f}")"
    f_name="${f_name%.*}"

    extra_args=()
    case "${etype2}" in
        1) subcmd="extractcd"; out="${f_dir}${f_name}.cue" ;;
        2) subcmd="extractcd"; out="${f_dir}${f_name}.gdi" ;;
        3) subcmd="extractdvd"; out="${f_dir}${f_name}.iso" ;;
        4)
            subcmd="extractraw"
            out="${f_dir}${f_name}.raw"
            extra_args=(--unitsize "${batch_unitsize}")
            ;;
        *) subcmd="extractcd"; out="${f_dir}${f_name}.cue" ;;
    esac

    echo ""
    echo "${BATCH_EXTRACT_LABEL} ${f}"
    if "${CHDMAN}" "${subcmd}" --force --input "${f}" --output "${out}" "${extra_args[@]}"; then :; fi
    if [ -f "${out}" ]; then
        BATCH_COUNT=$((BATCH_COUNT + 1))
        log_command "${subcmd}" "${f}" "${out}" "OK"
    else
        BATCH_FAIL=$((BATCH_FAIL + 1))
        log_command "${subcmd}" "${f}" "${out}" "FAILED"
    fi
}

extract_batch() {
    local src_root etype f batch_unitsize

    clear
    echo "============================================================"
    echo "  ${EXTRACT_BATCH_TITLE}"
    echo "============================================================"
    echo ""
    echo "${PROMPT_DROP_FOLDER}"
    echo "${PROMPT_THEN_ENTER}"
    echo ""
    read -r -p "${PROMPT_SOURCE_FOLDER} " src_root
    src_root="$(clean_path "${src_root}")"

    if [ ! -d "${src_root}" ]; then
        echo ""
        echo "${ERR_FOLDER_NOT_FOUND} ${src_root}"
        read -r -p "" _
        return
    fi

    echo ""
    echo "${BATCH_OUTPUT_FORMAT_PROMPT}"
    echo "  ${OUTPUT_FORMAT_CUEBIN}"
    echo "  ${OUTPUT_FORMAT_GDI}"
    echo "  ${OUTPUT_FORMAT_ISO}"
    echo "  ${OUTPUT_FORMAT_RAW}"
    read -r -p "${OUTPUT_FORMAT_CHOICE} " etype

    batch_unitsize=""
    if [ "${etype}" = "4" ]; then
        read -r -p "${PROMPT_UNITSIZE_EXTRACT} " batch_unitsize
        [ -z "${batch_unitsize}" ] && batch_unitsize="2048"
    fi

    # Compte, sans rien executer, le nombre de fichiers de sortie qui
    # existent deja et seraient ecrases (voir la note equivalente dans
    # create_batch() ci-dessus).
    local existing_count=0 f_dir f_name out_ext
    case "${etype}" in
        1) out_ext="cue" ;;
        2) out_ext="gdi" ;;
        3) out_ext="iso" ;;
        4) out_ext="raw" ;;
        *) out_ext="cue" ;;
    esac
    while IFS= read -r -d '' f; do
        f_dir="$(cd "$(dirname "${f}")" >/dev/null 2>&1 && pwd)/"
        f_name="$(basename "${f}")"; f_name="${f_name%.*}"
        [ -e "${f_dir}${f_name}.${out_ext}" ] && existing_count=$((existing_count + 1))
    done < <(find "${src_root}" -type f -iname "*.chd" -print0)

    if [ "${existing_count}" -gt 0 ]; then
        local batch_answer
        echo ""
        echo "${existing_count} ${BATCH_OVERWRITE_PROMPT}"
        read -r -p "${BATCH_OVERWRITE_CONFIRM} " batch_answer
        case "${batch_answer}" in
            [yYoOsSjJ]) : ;;
            *)
                echo ""
                echo "${OVERWRITE_CANCELLED}"
                read -r -p "" _
                return
                ;;
        esac
    fi

    BATCH_COUNT=0
    BATCH_FAIL=0

    # Substitution de processus : voir la note dans create_batch()
    # ci-dessus au sujet des compteurs perdus dans un sous-shell.
    while IFS= read -r -d '' f; do do_extract "${f}" "${etype}" "${batch_unitsize}"; done \
        < <(find "${src_root}" -type f -iname "*.chd" -print0)

    echo ""
    echo "============================================================"
    echo " ${BATCH_DONE_EXTRACT} ${BATCH_COUNT}   ${BATCH_FAILURES} ${BATCH_FAIL}"
    echo "============================================================"
    read -r -p "" _
}

# ============================================================
# 5) VERIFICATION
# ============================================================
verify_chd() {
    local src

    clear
    echo "============================================================"
    echo "  ${VERIFY_TITLE}"
    echo "============================================================"
    echo ""
    echo "${PROMPT_DROP_FILE_CHD}"
    echo "${PROMPT_THEN_ENTER}"
    echo ""
    read -r -p "${PROMPT_CHD_FILE} " src
    src="$(clean_path "${src}")"

    if [ ! -f "${src}" ]; then
        echo ""
        echo "${ERR_FILE_NOT_FOUND} ${src}"
        read -r -p "" _
        return
    fi

    echo ""
    local verify_status=0
    "${CHDMAN}" verify --input "${src}" || verify_status=$?
    echo ""
    if [ "${verify_status}" -eq 0 ]; then
        log_command "verify" "${src}" "" "OK"
    else
        log_command "verify" "${src}" "" "FAILED"
    fi
    read -r -p "" _
}

# ============================================================
# 6) INFOS
# ============================================================
info_chd() {
    local src

    clear
    echo "============================================================"
    echo "  ${INFO_TITLE}"
    echo "============================================================"
    echo ""
    echo "${PROMPT_DROP_FILE_CHD}"
    echo "${PROMPT_THEN_ENTER}"
    echo ""
    read -r -p "${PROMPT_CHD_FILE} " src
    src="$(clean_path "${src}")"

    if [ ! -f "${src}" ]; then
        echo ""
        echo "${ERR_FILE_NOT_FOUND} ${src}"
        read -r -p "" _
        return
    fi

    echo ""
    local info_status=0
    "${CHDMAN}" info --input "${src}" --verbose || info_status=$?
    echo ""
    if [ "${info_status}" -eq 0 ]; then
        log_command "info" "${src}" "" "OK"
    else
        log_command "info" "${src}" "" "FAILED"
    fi
    read -r -p "" _
}

# ============================================================
# 7) DISQUE DUR (createhd)
# ============================================================
create_hd() {
    local src src_dir src_name out hdtype subcmd hunksize unitsize
    local -a extra_args

    clear
    echo "============================================================"
    echo "  ${CREATE_HD_TITLE}"
    echo "============================================================"
    echo ""
    echo "${PROMPT_DROP_FILE_HD}"
    echo "${PROMPT_THEN_ENTER}"
    echo ""
    read -r -p "${PROMPT_SOURCE_FILE} " src
    src="$(clean_path "${src}")"

    if [ ! -f "${src}" ]; then
        echo ""
        echo "${ERR_FILE_NOT_FOUND} ${src}"
        read -r -p "" _
        return
    fi

    src_dir="$(cd "$(dirname "${src}")" >/dev/null 2>&1 && pwd)/"
    src_name="$(basename "${src}")"
    src_name="${src_name%.*}"
    out="${src_dir}${src_name}.chd"

    echo ""
    echo "${HD_TYPE_PROMPT}"
    echo "  ${HD_TYPE_HD}"
    echo "  ${HD_TYPE_RAW}"
    read -r -p "${HD_TYPE_CHOICE} " hdtype

    extra_args=()
    if [ "${hdtype}" = "2" ]; then
        subcmd="createraw"
        read -r -p "${PROMPT_HUNKSIZE} " hunksize
        read -r -p "${PROMPT_UNITSIZE} " unitsize
        [ -z "${hunksize}" ] && hunksize="2048"
        [ -z "${unitsize}" ] && unitsize="2048"
        extra_args=(--hunksize "${hunksize}" --unitsize "${unitsize}")
    else
        subcmd="createhd"
    fi

    confirm_overwrite "${out}" || return

    echo ""
    echo "------------------------------------------------------------"
    echo " ${COMMAND_LABEL} \"${CHDMAN}\" ${subcmd} --force --input \"${src}\" --output \"${out}\" ${extra_args[*]}"
    echo "------------------------------------------------------------"
    echo ""

    "${CHDMAN}" "${subcmd}" --force --input "${src}" --output "${out}" "${extra_args[@]}" || true

    echo ""
    if [ -f "${out}" ]; then
        echo "${CREATE_OK} ${out}"
        log_command "${subcmd}" "${src}" "${out}" "OK"
    else
        echo "${CREATE_FAILED}"
        log_command "${subcmd}" "${src}" "${out}" "FAILED"
    fi
    echo ""
    read -r -p "" _
}

# ============================================================
# Point d'entree
# ============================================================
main_menu
