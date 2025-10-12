#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$SCRIPT_DIR"
LOG_DIR="$ROOT_DIR/logs"
mkdir -p "$LOG_DIR"
TIMESTAMP="$(date +"%Y%m%d_%H%M%S")"
LOG_FILE="$LOG_DIR/geo_ops_${TIMESTAMP}.log"

touch "$LOG_FILE"
exec 3>&1

printf "Iniciando orquestrador Geo-Ops em %s\n" "$(date +"%Y-%m-%d %H:%M:%S")" >>"$LOG_FILE"

if [[ -t 1 ]]; then
	BOLD=$'\033[1m'
	DIM=$'\033[2m'
	GREEN=$'\033[32m'
	RED=$'\033[31m'
	YELLOW=$'\033[33m'
	BLUE=$'\033[34m'
	MAGENTA=$'\033[35m'
	CYAN=$'\033[36m'
	RESET=$'\033[0m'
else
	BOLD=""
	DIM=""
	GREEN=""
	RED=""
	YELLOW=""
	BLUE=""
	MAGENTA=""
	CYAN=""
	RESET=""
fi

SPINNER_FRAMES=("|" "/" "-" "\\")
TOTAL_STEPS=5
CURRENT_STEP=0
OS_TYPE="unknown"
PKG_MANAGER=""
IS_WSL=0
APT_UPDATED=0

BACKEND_PORT="8080"
FRONTEND_PORT="5173"
BACKEND_URL="http://localhost:${BACKEND_PORT}"
FRONTEND_URL="http://localhost:${FRONTEND_PORT}"
BACKEND_READY_WARNING=0
FRONTEND_READY_WARNING=0
backend_pid=""
frontend_pid=""
backend_run_log=""
frontend_run_log=""
CLEANING_UP=0

log_line() {
	printf "%s %s\n" "$(date +"%H:%M:%S")" "$*" >>"$LOG_FILE"
}

info() {
	printf "%s[INFO]%s %s\n" "$BLUE" "$RESET" "$*" >&3
	log_line "INFO: $*"
}

warn() {
	printf "%s[AVISO]%s %s\n" "$YELLOW" "$RESET" "$*" >&3
	log_line "WARN: $*"
}

error() {
	printf "%s[ERRO]%s %s\n" "$RED" "$RESET" "$*" >&3
	log_line "ERRO: $*"
}

generate_bar_segment() {
	local char="$1"
	local count="$2"
	local result=""
	for ((i = 0; i < count; i++)); do
		result+="$char"
	done
	printf "%s" "$result"
}

progress_update() {
	local message="$1"
	CURRENT_STEP=$((CURRENT_STEP + 1))
	local width=28
	local filled=$((CURRENT_STEP * width / TOTAL_STEPS))
	local empty=$((width - filled))
	local bar=""
	if ((filled > 0)); then
		bar+="$(generate_bar_segment "#" "$filled")"
	fi
	if ((empty > 0)); then
		bar+="$(generate_bar_segment "." "$empty")"
	fi
	printf "%s[%s]%s %d/%d %s\n" "$BOLD" "$bar" "$RESET" "$CURRENT_STEP" "$TOTAL_STEPS" "$message" >&3
	log_line "PROGRESSO: $CURRENT_STEP/$TOTAL_STEPS - $message"
}

print_banner() {
	cat >&3 <<'EOF'
=============================================================
   ____               ____        ____               
  / ___| ___  _ __   / ___| ___  / ___| _ __   ___   
 | |  _ / _ \| '_ \ | |  _ / _ \ \___ \| '_ \ / _ \  
 | |_| | (_) | | | || |_| | (_) | ___) | |_) | (_) | 
  \____|\___/|_| |_| \____|\___/ |____/| .__/ \___/  
                                      |_|            
=============================================================
EOF
	printf "Log detalhado: %s\n" "$LOG_FILE" >&3
	log_line "Banner exibido"
}

detect_environment() {
	local uname_s
	uname_s=$(uname -s 2>/dev/null || echo unknown)
	case "$uname_s" in
		Linux*) OS_TYPE="linux" ;;
		Darwin*) OS_TYPE="macos" ;;
		CYGWIN*|MINGW*|MSYS*) OS_TYPE="windows" ;;
		*) OS_TYPE="unknown" ;;
	esac
	if [[ $OS_TYPE == "linux" ]] && grep -qi microsoft /proc/version 2>/dev/null; then
		IS_WSL=1
	fi

	if command -v apt-get >/dev/null 2>&1; then
		PKG_MANAGER="apt"
	elif command -v dnf >/dev/null 2>&1; then
		PKG_MANAGER="dnf"
	elif command -v yum >/dev/null 2>&1; then
		PKG_MANAGER="yum"
	elif command -v pacman >/dev/null 2>&1; then
		PKG_MANAGER="pacman"
	else
		PKG_MANAGER=""
	fi

	log_line "Sistema detectado: OS_TYPE=${OS_TYPE}, PKG_MANAGER=${PKG_MANAGER}, IS_WSL=${IS_WSL}"
}

prompt_yes_no() {
	local prompt="$1"
	local default="${2:-n}"
	local default_lower="${default,,}"
	local question
	if [[ $default_lower == "s" || $default_lower == "y" ]]; then
		question="$prompt [S/n] "
		default_lower="s"
	else
		question="$prompt [s/N] "
		default_lower="n"
	fi
	printf "%s" "$question" >&3
	local response=""
	if [[ -t 0 ]]; then
		if ! read -r response; then
			warn "Nao foi possivel ler entrada interativa."
			return 1
		fi
	elif [[ -r /dev/tty ]]; then
		if ! read -r response </dev/tty; then
			warn "Nao foi possivel ler entrada interativa."
			return 1
		fi
	else
		warn "Nao foi possivel ler entrada interativa."
		return 1
	fi
	if [[ -z ${response// } ]]; then
		response="$default_lower"
	fi
	case "${response,,}" in
		s|y) return 0 ;;
		n) return 1 ;;
		*)
			warn "Resposta invalida. Considerando 'nao'."
			return 1
			;;
	esac
}

run_install_command() {
	local description="$1"
	shift
	info "$description"
	log_line "Executando: $description -> $*"
	if "$@" 2>&1 | tee >(sed 's/^/      | /' >&3) >>"$LOG_FILE"; then
		log_line "Comando concluido: $description"
		return 0
	else
		log_line "Comando falhou: $description"
		return 1
	fi
}

run_as_root() {
	if [[ $EUID -eq 0 ]]; then
		"$@"
	else
		if command -v sudo >/dev/null 2>&1; then
			sudo "$@"
		else
			error "Este passo requer privilegios de administrador (sudo)."
			return 1
		fi
	fi
}

ensure_apt_update() {
	if [[ $APT_UPDATED -eq 0 ]]; then
		if run_install_command "Atualizando lista de pacotes (apt-get update)" run_as_root apt-get update; then
			APT_UPDATED=1
		else
			return 1
		fi
	fi
	return 0
}

install_component_linux() {
	local component="$1"
	case "$PKG_MANAGER" in
		apt)
			case "$component" in
				java)
					if ! ensure_apt_update; then
						return 1
					fi
					run_install_command "Instalando OpenJDK 21 (apt)" run_as_root apt-get install -y openjdk-21-jdk || return 1
					;;
				node)
					if ! ensure_apt_update; then
						return 1
					fi
					if ! command -v curl >/dev/null 2>&1; then
						run_install_command "Instalando curl (necessario para NodeSource)" run_as_root apt-get install -y curl ca-certificates gnupg || return 1
					fi
					local setup_cmd
					if [[ $EUID -eq 0 ]]; then
						setup_cmd="curl -fsSL https://deb.nodesource.com/setup_20.x | bash -"
					else
						if ! command -v sudo >/dev/null 2>&1; then
							error "O script de configuracao do NodeSource requer sudo."
							return 1
						fi
						setup_cmd="curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -"
					fi
					run_install_command "Configurando repositorio NodeSource (Node 20)" bash -lc "$setup_cmd" || return 1
					run_install_command "Instalando Node.js 20 (apt)" run_as_root apt-get install -y nodejs || return 1
					;;
				npm)
					if ! ensure_apt_update; then
						return 1
					fi
					run_install_command "Instalando npm (apt)" run_as_root apt-get install -y npm || return 1
					;;
				*)
					warn "Nao ha rotina automatica para instalar ${component} neste gerenciador."
					return 1
					;;
			esac
			;;
		dnf)
			case "$component" in
				java)
					run_install_command "Instalando OpenJDK 21 (dnf)" run_as_root dnf install -y java-21-openjdk-devel || return 1
					;;
				node)
					run_install_command "Instalando Node.js 20 (dnf)" run_as_root dnf install -y nodejs || return 1
					;;
				npm)
					run_install_command "Instalando npm (dnf)" run_as_root dnf install -y npm || return 1
					;;
				*)
					warn "Nao ha rotina automatica para instalar ${component} neste gerenciador."
					return 1
					;;
			esac
			;;
		yum)
			case "$component" in
				java)
					run_install_command "Instalando OpenJDK 21 (yum)" run_as_root yum install -y java-21-openjdk-devel || return 1
					;;
				node)
					run_install_command "Instalando Node.js (yum)" run_as_root yum install -y nodejs || return 1
					;;
				npm)
					run_install_command "Instalando npm (yum)" run_as_root yum install -y npm || return 1
					;;
				*)
					warn "Nao ha rotina automatica para instalar ${component} neste gerenciador."
					return 1
					;;
			esac
			;;
		pacman)
			case "$component" in
				java)
					run_install_command "Instalando OpenJDK 21 (pacman)" run_as_root pacman -S --noconfirm jdk-openjdk || return 1
					;;
				node)
					run_install_command "Instalando Node.js (pacman)" run_as_root pacman -S --noconfirm nodejs npm || return 1
					;;
				npm)
					run_install_command "Instalando npm (pacman)" run_as_root pacman -S --noconfirm npm || return 1
					;;
				*)
					warn "Nao ha rotina automatica para instalar ${component} neste gerenciador."
					return 1
					;;
			esac
			;;
		*)
			warn "Gerenciador de pacotes nao suportado para instalacao automatica."
			return 1
			;;
	esac
	return 0
}

print_manual_installation_hint() {
	local component="$1"
	case "$component" in
		java)
			warn "Instale o Java 21 manualmente. Sugestao: Adoptium (https://adoptium.net/) ou SDKMAN."
			;;
		node|npm)
			warn "Instale Node.js 20+ e npm manualmente. Sugestao: https://nodejs.org/ ou nvm (https://github.com/nvm-sh/nvm)."
			;;
		*)
			warn "Instale manualmente o componente '${component}'."
			;;
	esac
}

try_install_component() {
	local component="$1"
	local label="$2"
	local cmd="$3"

	if [[ $OS_TYPE != "linux" ]]; then
		warn "Instalacao automatica de $label nao suportada neste sistema (${OS_TYPE})."
		print_manual_installation_hint "$component"
		return 1
	fi

	if [[ -z $PKG_MANAGER ]]; then
		warn "Nao foi possivel detectar um gerenciador de pacotes para instalar $label automaticamente."
		print_manual_installation_hint "$component"
		return 1
	fi

	if ! prompt_yes_no "Deseja tentar instalar ${label} automaticamente?" "n"; then
		warn "$label nao sera instalado automaticamente."
		print_manual_installation_hint "$component"
		return 1
	fi

	if install_component_linux "$component"; then
		if command -v "$cmd" >/dev/null 2>&1; then
			info "$label instalado com sucesso."
			return 0
		fi
		warn "$label foi instalado, mas o comando '${cmd}' ainda nao foi encontrado."
		return 1
	else
		error "Falha ao instalar ${label} automaticamente."
		return 1
	fi
}

version_ge() {
	local IFS=.
	local -a ver1=($1) ver2=($2)
	local i
	for ((i = ${#ver1[@]}; i < ${#ver2[@]}; i++)); do
		ver1[i]=0
	done
	for ((i = ${#ver2[@]}; i < ${#ver1[@]}; i++)); do
		ver2[i]=0
	done
	for ((i = 0; i < ${#ver1[@]}; i++)); do
		local v1=${ver1[i]}
		local v2=${ver2[i]}
		if ((10#$v1 > 10#$v2)); then
			return 0
		fi
		if ((10#$v1 < 10#$v2)); then
			return 1
		fi
	done
	return 0
}

ensure_command() {
	local cmd="$1"
	local label="$2"
	local component="$3"
	if command -v "$cmd" >/dev/null 2>&1; then
		local path
		path=$(command -v "$cmd")
		printf "  [%sOK%s] %s (%s)\n" "$GREEN" "$RESET" "$label" "$path" >&3
		log_line "Checagem: $label -> $path"
		return 0
	fi

	warn "$label nao encontrado (comando '$cmd')."
	if try_install_component "$component" "$label" "$cmd"; then
		local path
		path=$(command -v "$cmd")
		printf "  [%sOK%s] %s (%s)\n" "$GREEN" "$RESET" "$label" "$path" >&3
		log_line "Checagem: $label -> $path (instalado automaticamente)"
		return 0
	fi
	error "$label nao encontrado e instalacao automatica nao foi concluida."
	exit 1
}

get_java_version() {
	local first_line
	first_line=$(java --version 2>&1 | head -n 1 || true)
	if [[ $first_line =~ ([0-9]+(\.[0-9]+){0,2}) ]]; then
		printf "%s" "${BASH_REMATCH[1]}"
	fi
}

ensure_java_version() {
	local version
	version=$(get_java_version || true)
	if [[ -z ${version:-} ]]; then
		warn "Nao foi possivel detectar a versao do Java. Assumindo compatibilidade."
		return
	fi
	if version_ge "$version" "21"; then
		printf "      Versao do Java: %s (OK)\n" "$version" >&3
		log_line "Java versao: $version"
	else
		printf "      Versao do Java: %s (insuficiente)\n" "$version" >&3
		error "Java 21 ou superior e necessario. Versao atual: $version"
		exit 1
	fi
}

get_node_version() {
	local raw
	raw=$(node --version 2>&1 | head -n 1 || true)
	if [[ $raw =~ v?([0-9]+(\.[0-9]+){0,2}) ]]; then
		printf "%s" "${BASH_REMATCH[1]}"
	fi
}

ensure_node_version() {
	local version
	version=$(get_node_version || true)
	if [[ -z ${version:-} ]]; then
		warn "Nao foi possivel detectar a versao do Node.js. Assumindo compatibilidade."
		return
	fi
	if version_ge "$version" "20.19.0"; then
		printf "      Versao do Node.js: %s (OK)\n" "$version" >&3
		log_line "Node versao: $version"
	else
		printf "      Versao do Node.js: %s (insuficiente)\n" "$version" >&3
		error "Node.js 20.19.0 ou superior e necessario. Versao atual: $version"
		exit 1
	fi
}

detect_backend_port() {
	local file="$ROOT_DIR/backend/src/main/resources/application.properties"
	if [[ -f "$file" ]]; then
		local line
		line=$(grep -E '^server\.port=' "$file" | tail -n 1 || true)
		if [[ -n "$line" ]]; then
			local value="${line#*=}"
			value="${value//[[:space:]]/}"
			if [[ "$value" =~ ^[0-9]+$ ]]; then
				BACKEND_PORT="$value"
			fi
		fi
	fi
	BACKEND_URL="http://localhost:${BACKEND_PORT}"
	log_line "Porta do backend definida como $BACKEND_PORT"
}

detect_frontend_port() {
	local file="$ROOT_DIR/frontend/vite.config.ts"
	if [[ -f "$file" ]]; then
		local line
		line=$(grep -E 'port:' "$file" | head -n 1 || true)
		if [[ $line =~ ([0-9]+) ]]; then
			FRONTEND_PORT="${BASH_REMATCH[1]}"
		fi
	fi
	FRONTEND_URL="http://localhost:${FRONTEND_PORT}"
	log_line "Porta do frontend definida como $FRONTEND_PORT"
}

preflight_checks() {
	info "Verificando dependencias do ambiente..."
	ensure_command java "Java" "java"
	ensure_java_version
	ensure_command node "Node.js" "node"
	ensure_node_version
	ensure_command npm "npm" "npm"
	chmod +x "$ROOT_DIR/backend/mvnw" "$ROOT_DIR/backend/mvnw.cmd" 2>/dev/null || true
	if [[ ! -x "$ROOT_DIR/backend/mvnw" ]]; then
		error "Wrapper Maven (backend/mvnw) nao esta executavel."
		exit 1
	fi
	info "Dependencias basicas verificadas."
	log_line "Pre-checagens concluidas"
}

run_with_spinner() {
	local message="$1"
	shift
	log_line "Iniciando etapa: $message"
	local temp_log
	temp_log=$(mktemp "${LOG_DIR}/cmd_${TIMESTAMP}_XXXX.log")
	(
		"$@"
	) > >(tee -a "$LOG_FILE" "$temp_log" >/dev/null) 2>&1 &
	local pid=$!
	local frame=0
	while kill -0 "$pid" >/dev/null 2>&1; do
		printf "\r  [%s] %s" "${SPINNER_FRAMES[frame]}" "$message" >&3
		frame=$(((frame + 1) % ${#SPINNER_FRAMES[@]}))
		sleep 0.1
	done
	wait "$pid"
	local status=$?
	if [[ $status -eq 0 ]]; then
		printf "\r\033[K  [%sOK%s] %s\n" "$GREEN" "$RESET" "$message" >&3
		log_line "Etapa finalizada com sucesso: $message"
		if [[ -s $temp_log ]]; then
			printf "    --- Saida (%s) ---\n" "$message" >&3
			sed 's/^/    | /' "$temp_log" >&3
			printf "    -------------------\n" >&3
		fi
	else
		printf "\r\033[K  [%sERRO%s] %s\n" "$RED" "$RESET" "$message" >&3
		error "Falha ao executar: $message. Consulte o log em $LOG_FILE"
		if [[ -s $temp_log ]]; then
			printf "    --- Saida de erro (%s) ---\n" "$message" >&3
			sed 's/^/    | /' "$temp_log" >&3
			printf "    --------------------------\n" >&3
		fi
		rm -f "$temp_log"
		exit "$status"
	fi
	rm -f "$temp_log"
}

install_backend_deps() {
	(
		cd "$ROOT_DIR/backend"
		./mvnw -ntp clean package -DskipTests
	)
}

install_frontend_deps() {
	(
		cd "$ROOT_DIR/frontend"
		npm install --no-audit --no-fund
	)
}

start_backend_process() {
	backend_run_log="$LOG_DIR/backend_${TIMESTAMP}.log"
	: >"$backend_run_log"
	info "Iniciando backend Spring Boot (log: $backend_run_log)"
	(
		cd "$ROOT_DIR/backend"
		./mvnw spring-boot:run
	) >>"$backend_run_log" 2>&1 &
	backend_pid=$!
	log_line "Backend iniciado em segundo plano (PID=$backend_pid)"
}

wait_for_backend_ready() {
	local max_wait=120
	local waited=0
	BACKEND_READY_WARNING=0
	while kill -0 "$backend_pid" >/dev/null 2>&1; do
		if grep -q "Started" "$backend_run_log" 2>/dev/null; then
			BACKEND_URL="http://localhost:${BACKEND_PORT}"
			log_line "Backend sinalizou inicializacao completa."
			return 0
		fi
		if command -v curl >/dev/null 2>&1; then
			if curl -sf "http://localhost:${BACKEND_PORT}/actuator/health" >/dev/null 2>&1; then
				log_line "Endpoint /actuator/health respondeu."
				return 0
			fi
		fi
		if ((waited >= max_wait)); then
			BACKEND_READY_WARNING=1
			log_line "Timeout aguardando backend; pode ser necessario verificar manualmente."
			BACKEND_URL="http://localhost:${BACKEND_PORT}"
			return 0
		fi
		sleep 1
		waited=$((waited + 1))
	done
	return 1
}

start_frontend_process() {
	frontend_run_log="$LOG_DIR/frontend_${TIMESTAMP}.log"
	: >"$frontend_run_log"
	info "Iniciando frontend Vite (log: $frontend_run_log)"
	(
		cd "$ROOT_DIR/frontend"
		npm run dev -- --host
	) >>"$frontend_run_log" 2>&1 &
	frontend_pid=$!
	log_line "Frontend iniciado em segundo plano (PID=$frontend_pid)"
}

wait_for_frontend_ready() {
	local max_wait=90
	local waited=0
	FRONTEND_READY_WARNING=0
	FRONTEND_URL="http://localhost:${FRONTEND_PORT}"
	while kill -0 "$frontend_pid" >/dev/null 2>&1; do
		if grep -qE "Local:" "$frontend_run_log" 2>/dev/null; then
			local url_line
			url_line=$(grep -E "Local:" "$frontend_run_log" | tail -n 1)
			url_line="${url_line#*Local:}"
			url_line="${url_line#"${url_line%%[![:space:]]*}"}"
			local candidate="${url_line%% *}"
			if [[ -n "$candidate" ]]; then
				FRONTEND_URL="$candidate"
				log_line "Frontend disponibilizado em $FRONTEND_URL"
			fi
			return 0
		fi
		if ((waited >= max_wait)); then
			FRONTEND_READY_WARNING=1
			log_line "Timeout aguardando frontend; usando URL padrao."
			FRONTEND_URL="http://localhost:${FRONTEND_PORT}"
			return 0
		fi
		sleep 1
		waited=$((waited + 1))
	done
	return 1
}

print_summary() {
	printf "\n%sStack Geo-Ops pronta!%s\n" "$GREEN" "$RESET" >&3
	cat >&3 <<EOF
-------------------------------------------------------------
 Backend : ${BACKEND_URL}
           Log: ${backend_run_log}
 Frontend: ${FRONTEND_URL}
           Log: ${frontend_run_log}
 Log geral: ${LOG_FILE}
-------------------------------------------------------------
Pressione Ctrl+C para encerrar os servicos com seguranca.
EOF
	log_line "Resumo apresentado ao usuario."
}

cleanup() {
	if [[ $CLEANING_UP -eq 1 ]]; then
		return
	fi
	CLEANING_UP=1
	printf "\n%sEncerrando servicos Geo-Ops...%s\n" "$YELLOW" "$RESET" >&3
	if [[ -n ${frontend_pid:-} ]] && kill -0 "$frontend_pid" >/dev/null 2>&1; then
		kill "$frontend_pid" >/dev/null 2>&1 || true
		wait "$frontend_pid" >/dev/null 2>&1 || true
		log_line "Frontend encerrado."
	fi
	if [[ -n ${backend_pid:-} ]] && kill -0 "$backend_pid" >/dev/null 2>&1; then
		kill "$backend_pid" >/dev/null 2>&1 || true
		wait "$backend_pid" >/dev/null 2>&1 || true
		log_line "Backend encerrado."
	fi
	printf "%sServicos finalizados. Ate logo!%s\n" "$GREEN" "$RESET" >&3
	log_line "Rotina de limpeza concluida."
}

on_interrupt() {
	printf "\n%sInterrupcao solicitada. Finalizando...%s\n" "$MAGENTA" "$RESET" >&3
	exit 0
}

main() {
	print_banner
	detect_environment
	detect_backend_port
	detect_frontend_port
	preflight_checks
	progress_update "Ambiente validado"

	run_with_spinner "Instalando dependencias do backend" install_backend_deps
	progress_update "Backend compilado"

	run_with_spinner "Instalando dependencias do frontend" install_frontend_deps
	progress_update "Frontend preparado"

	start_backend_process
	run_with_spinner "Aguardando backend iniciar" wait_for_backend_ready
	if [[ ${BACKEND_READY_WARNING:-0} -eq 1 ]]; then
		warn "Backend pode ainda estar inicializando; verifique o log ${backend_run_log}."
	fi
	progress_update "Backend no ar (porta ${BACKEND_PORT})"

	start_frontend_process
	run_with_spinner "Aguardando frontend iniciar" wait_for_frontend_ready
	if [[ ${FRONTEND_READY_WARNING:-0} -eq 1 ]]; then
		warn "Frontend pode ainda estar subindo; acompanhe o log ${frontend_run_log}."
	fi
	progress_update "Frontend disponivel (porta ${FRONTEND_PORT})"

	print_summary
	info "Stack em execucao. Use Ctrl+C para encerrar."
	set +e
	wait "$backend_pid" "$frontend_pid"
}

trap cleanup EXIT
trap on_interrupt INT TERM

main "$@"
