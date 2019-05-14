#!/bin/bash

GPG_HOMEDIR="$1"
KEY_NAME="$2"

CR=$(printf '\r')

# Exit if called without proper arguments
if [[ -z "${GPG_HOMEDIR}" ]] || [[ -z "${KEY_NAME}" ]]; then
    echo 'Usage: ./gpgit.sh [GPG homedir location] [key name]' >&2
    exit 0
fi

# Exit if homedir location does not exit
if ! [[ -d "${GPG_HOMEDIR}" ]]; then
    echo "Error: GPG homedir does not exist: ${GPG_HOMEDIR}" >&2
    exit 1
fi

# Exit if secret key does not exist
if ! gpg --list-secret-keys 2> /dev/null | grep --quiet "${KEY_NAME}"; then
    echo "Error: GPG secret key does not exist" >&2
    exit 2
fi

# Read from STDIN, converting CRLF to LF
data_plain=$(cat | tr -d '\r')

# Echo data to STDOUT if already encrypted type
if echo "${data_plain}" | grep -q '^Content-Type: application/pgp-encrypted'; then
    echo "${data_plain}" | sed "s/$/${CR}/g"
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
    # Insert boilerplate PGP/MIME data
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
    # Replace original headers within the multipart/encrypted type
    g
    # Append extra newline between original headers and original body
    a\
\

    # Dump remaining lines
    b dump
}

# Hold original Content-Type header and delete from pattern space
/^[Cc][Oo][Nn][Tt][Ee][Nn][Tt]-[Tt][Yy][Pp][Ee]:/ {
    # Add header to hold space
    H
    :loop1
    # Delete line
    c\

    n
    # If pattern space begins with whitespace (tab or space), aka continued header from previous line
    /^[ 	]/ {
        # Add continued header to hold space
        H
        b loop1
    }
    # Break back to start to re-run checks on this line if not continued header
    b start
}

# Hold original Content-Transfer-Encoding header and delete from pattern space
/^[Cc][Oo][Nn][Tt][Ee][Nn][Tt]-[Tt][Rr][Aa][Nn][Ss][Ff][Ee][Rr]-[Ee][Nn][Cc][Oo][Dd][Ii][Nn][Gg]:/ {
    # Add header to hold space
    H
    :loop2
    # Delete line
    c\

    n
    # If pattern space begins with whitespace (tab or space), aka continued header from previous line
    /^[ 	]/ {
        # Add continued header to hold space
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
# Dump just the headers
/^Content-Type: application\/octet-stream/ {
    :header
    n
    /^$/ !b header
    /^$/ q
}
'
echo "${data_with_headers}" | sed '
# Dump just the body
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
' | gpg --homedir "${GPG_HOMEDIR}" --batch --armor --encrypt --recipient "${KEY_NAME}" --sign --local-user "${KEY_NAME}"
echo 
echo "--${mime_boundary}--")

echo "${data_encrypted}" | sed "s/$/${CR}/g"
