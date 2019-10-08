#!/bin/bash
set -eo pipefail

pushd "$(dirname "$0")" > /dev/null
readonly pathscript=$(pwd)
popd > /dev/null

# Determine if terminal is capable of showing colors
if [[ -t 1 ]] && [[ $(tput colors) -ge 8 ]]; then
    Red='\e[91m'
    Green='\e[32m'
    Blue='\e[94m'
    Yellow='\e[33m'
    NoColor='\e[0m'
else
    Red=''
    Green=''
    Blue=''
    Yello=''
    NoColor=''
fi

if ! [ -x "$(command -v docker-compose)" ]; then
  echo -e "${Red}[ERROR]${NoColor} docker-compose is not installed, run 'pip3 install -U docker-compose'."
  exit 1
fi

Docker="sudo docker-compose"

if ! [[ ${UID} -eq 0 ]]; then
    # Check if sudo is actually installed
    # If it isn't, exit because script can not function
    if [ -x "$(command -v sudo)" ]; then
        Sudo="sudo"
        if groups $USER | grep &>/dev/null '\bdocker\b'; then
            Docker="docker-compose"
        fi
    else
        echo -e "${Red}[ERROR]${NoColor} Script called with non-root privileges."
        exit 1
    fi
fi


# extraArgs
isSubdomain=0
readonly staging=0 # Set to 1 if you're testing your setup to avoid hitting request limits
readonly RSAKeySize=4096
# config dir
readonly dataPath="${pathscript}/config/certbot"

warn() {
    echo -e "${Yellow}[WARNING]${NoColor} $1"
}

err() {
    echo -e "${Red}[ERROR]${NoColor} $1"
}

info() {
    echo -e "${Blue}[INFO]${NoColor} $1"
}

ok() {
    echo -e "[${Green}✓${NoColor}] $1"
}


showUsage() {
    echo -e "Usage: \n \t <domain> <optional:email> \n \t eg: mywebsite.com hello@gmail.com"
}

prompt() {
    local msg=$1
    read -p "$msg" decision
    if [ "$decision" != "Y" ] && [ "$decision" != "y" ]; then
        exit 0
    fi
}

getTLSParams() {
    if [ ! -e "$dataPath/conf/options-ssl-nginx.conf" ] || [ ! -e "$dataPath/conf/ssl-dhparams.pem" ]; then
        info "Downloading recommended TLS parameters ..."
        mkdir -p "$dataPath/conf"
        curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot-nginx/certbot_nginx/tls_configs/options-ssl-nginx.conf \
            > "$dataPath/conf/options-ssl-nginx.conf" > /dev/null 2>&1
        curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot/ssl-dhparams.pem \
            > "$dataPath/conf/ssl-dhparams.pem" > /dev/null 2>&1
    fi
}

createDummyCert() {
    local domain=$1
    info "Creating dummy certificate for $domain ..."
    local path="/etc/letsencrypt/live/$domain"
    mkdir -p "$dataPath/conf/live/$domain"
    ${Docker} run --rm --entrypoint "\
    openssl req -x509 -nodes -newkey rsa:1024 -days 1\
        -keyout '$path/privkey.pem' \
        -out '$path/fullchain.pem' \
        -subj '/CN=localhost'" certbot > /dev/null 2>&1
}

startNginx() {
    info "Starting nginx ..."
    ${Docker} up --force-recreate -d nginx > /dev/null 2>&1
}

deleteDummyCert() {
    local domain=$1
    info "Deleting dummy certificate for $domain ..."
    ${Docker} run --rm --entrypoint "\
    rm -Rf /etc/letsencrypt/live/$domain && \
    rm -Rf /etc/letsencrypt/archive/$domain && \
    rm -Rf /etc/letsencrypt/renewal/$domain.conf" certbot > /dev/null 2>&1
}

requestCert() {
    local email=$2
    local emailArg=""
    local domainArgs=""
    local domains=($1 "www.$1")

    info "Requesting Let's Encrypt certificate for $1 ..."

    if [ $isSubdomain != "0" ]; then domains=($1); fi

    domainArgs=""
    for domain in "${domains[@]}"; do
        domainArgs="$domainArgs -d $domain"
    done

    case "$email" in
    "") emailArg="--register-unsafely-without-email" ;;
    *) emailArg="--email $email" ;;
    esac

    if [ $staging != "0" ]; then stagingArg="--staging"; fi

    ${Docker} run --rm --entrypoint "\
    certbot certonly --webroot -w /var/www/certbot \
        $stagingArg \
        $emailArg \
        $domainArgs \
        --rsa-key-size $RSAKeySize \
        --agree-tos \
        --force-renewal" certbot
    echo
}

generateConfigs() {
    local domain="$1"

    info "Generating config files ..."

    sed -e "s/example.org/$domain/" \
        "$pathscript"/templates/trojan.template > $pathscript/config/config.json
    
    sed -e "s/example.org/$domain/" \
        -e "s/www.example.org/www.$domain/" \
        "$pathscript"/templates/nginx.template > $pathscript/config/nginx/nginx.conf
}

pingDomains() {
    local domain=$1

    if ! sudo ping -c 3 "$domain" &> /dev/null; then
        err "Failed to lookup $1 please check your DNS configurations \n \t also make sure that $1 is pointing to your IP"
        exit 1
    elif ! sudo ping -c 3 "www.$domain" &> /dev/null; then
        isSubdomain=1
    fi
}

init() {
    local domain=$1
    local email=$2

    if [ -d "$dataPath" ]; then
        prompt "Existing data found for $domain. Continue and replace existing certificate? (y/N) "
    else
        if [[ -z "$email" ]]; then
            prompt "Domain: $domain. Continue? (y/N) "
        else
            prompt "Domain: $domain -- Email: $email. Continue? (y/N) "
        fi
    fi

    pingDomains $domain

    generateConfigs $domain

    getTLSParams

    createDummyCert $domain

    startNginx

    deleteDummyCert $domain

    requestCert $domain $email

    ${Docker} exec nginx nginx -s reload > /dev/null 2>&1

    ${Sudo} chown -R $USER:$USER $dataPath > /dev/null 2>&1
    
    ok "run the server with: '${Docker} up -d'"    
}

if [[ "$#" -eq 0 ]] || [[ "$1" == "help" ]]; then
    showUsage
    exit 1
elif [[ "$#" -gt 2 ]]; then
    showUsage
    exit 1
elif [[ -z "$1" ]]; then
    err "No domain provided."
    exit 1
else
    if [[ -z "$2" ]]; then
        init $1 ""
    else
        init $1 $2
    fi
fi