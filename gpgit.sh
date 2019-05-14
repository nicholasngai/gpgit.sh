#!/bin/sh

GPG_HOMEDIR=/Users/nngai/.gnupg/
USER="$1"

# Exit if called without email
if [[ -z "$1" ]]; then
    echo 'Usage: sh gpgit.sh [email]'
    exit 0
fi

# Read from STDIN, converting CRLF to LF
data_plain=$(cat | tr -d '\r')

# Echo data to STDOUT if already encrypted type
if echo "${data_plain}" | grep -q '^Content-Type: application/pgp-encrypted'; then
    echo "${data_plain}" | sed 's/$/
    exit 0
fi

# Generate random MIME boundary
mime_boundary="pgp-"
mime_boundary+=$(dd if=/dev/random bs=32 count=1 2> /dev/null | xxd -p | tr -d '\n')

# Rewrite headers to fit PGP/MIME, converting CRLF to LF for compatability with sed
data_with_headers=$(echo "${data_plain}" | sed '
:start
# Rewrite standard PGP/MIME headers and body
/^$/ {
    i\
        Content-Type: multipart/encrypted; boundary="MIME_PLACEHOLDER-4d494d455f504c414345484f4c444552"; protocol="application/pgp-encrypted";\
        \
        --MIME_PLACEHOLDER-4d494d455f504c414345484f4c444552\
        Content-Type: application/pgp-encrypted\
        Content-Transfer-Encoding: 7bit\
        \
        Version: 1\
        \
        --MIME_PLACEHOLDER-4d494d455f504c414345484f4c444552\
        Content-Type: application/octet-stream; name="encrypted.asc"\
        Content-Transfer-Encoding: 7bit\
        Content-Disposition: inline; filename="encrypted.asc"
    g
    # Dump remaining lines
    b dump
}

# Hold original Content-Type header and delete from pattern space
/^[Cc][Oo][Nn][Tt][Ee][Nn][Tt]-[Tt][Yy][Pp][Ee]:/ {
    H
    :loop1
    c\

    n
    # If pattern space begins with whitespace (tab or space), aka continued header from previous line
    /^[ 	]/ {
        H
        b loop1
    }
    # Break back to start to re-run checks on this line if not continued header
    b start
}

# Hold original Content-Transfer-Encoding header and delete from pattern space
/^[Cc][Oo][Nn][Tt][Ee][Nn][Tt]-[Tt][Rr][Aa][Nn][Ss][Ff][Ee][Rr]-[Ee][Nn][Cc][Oo][Dd][Ii][Nn][Gg]:/ {
    H
    :loop2
    c\

    n
    # If pattern space begins with whitespace (tab or space), aka continued header from previous line
    /^[ 	]/ {
        H
        b loop2
    }
    # Break back to start to re-run checks on this line if not continued header
    b start
}

# Manually begin next line to avoid dump loop
n
b start

# Dump the rest of the lines without any checks
:dump
n
b dump
' | sed "s/MIME_PLACEHOLDER-4d494d455f504c414345484f4c444552/${mime_boundary}/g")

data_encrypted=$(echo "${data_with_headers}" | sed '
/^Content-Type: application\/octet-stream/ {
    :header
    n
    /^$/ !b header
    /^$/ q
}
'
echo "${data_with_headers}" | sed '
/^Content-Type: application\/octet-stream/ !d
/^Content-Type: application\/octet-stream/ {
    :header
    c\

    n
    /^$/ !b header
    c\

    n
    :dump
    n
    b dump
}
' | gpg --homedir "${GPG_HOMEDIR}" --batch --armor --encrypt --recipient "${USER}" --sign --local-user "${USER}"
echo 
echo "--${mime_boundary}--")

echo "${data_encrypted}" | sed 's/$/