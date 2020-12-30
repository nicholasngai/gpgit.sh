#!/bin/bash

ENCRYPTED_MIME_TYPES=(
    'multipart/encrypted'
    'application/pkcs7-mime'
)

USER_KEY_FILE="$1"

CR=$(printf '\r')

# Exit if called without user key file
if [ -z "${USER_KEY_FILE}" ]; then
    echo 'Usage: ./gpgit.sh [public key file]' >&2
    exit 0
fi

# Read from STDIN, converting CRLF to LF
data_plain=$(cat | tr -d '\r')

# Echo data to STDOUT if already encrypted type
for encrypted_mime_type in "${ENCRYPTED_MIME_TYPES[@]}"; do
    if echo "${data_plain}" | grep --quiet --ignore-case "^Content-Type: ${encrypted_mime_type}"; then
        echo "${data_plain}" | sed "s/$/${CR}/"
        exit 0
    fi
done

# Generate random MIME boundary
mime_boundary=$(dd if=/dev/urandom bs=16 count=1 2> /dev/null | xxd -plain | tr -d '\n')

# Rewrite headers to fit PGP/MIME, converting CRLF to LF for compatability with sed
data_with_headers=$(echo "${data_plain}" | sed "
:start
# Rewrite standard PGP/MIME headers and body
/^$/ {
    # Insert boilerplate PGP/MIME data
    i\\
Content-Type: multipart/encrypted; boundary=\"${mime_boundary}\";\\
 protocol=\"application/pgp-encrypted\";\\
\\
--${mime_boundary}\\
Content-Type: application/pgp-encrypted\\
\\
Version: 1\\
\\
--${mime_boundary}\\
Content-Type: application/octet-stream; name=\"encrypted.asc\"\\
Content-Disposition: inline; filename=\"encrypted.asc\"
    # Replace original headers within the multipart/encrypted type
    x
    # Append extra newline between original headers and original body
    G
    # Dump remaining lines
    b dump
}

# Hold original Content-Type header and delete from pattern space
/^[Cc][Oo][Nn][Tt][Ee][Nn][Tt]-[Tt][Yy][Pp][Ee]:/ {
    # Add header to hold space
    H
    :loop1
    # Delete line and read next
    N
    s/^.*\\n//
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
    # Delete line and read next
    N
    s/^.*\\n//
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
")

data_encrypted=$(echo "${data_with_headers}" | sed "
# Dump just the headers
/^Content-Type: application\/octet-stream/ {
    :header
    n
    /^$/ !b header
    /^$/ q
}
"
echo "${data_with_headers}" | sed "
# Dump just the body
/^Content-Type: application\/octet-stream/ !d
/^Content-Type: application\/octet-stream/ {
    :header
    N
    s/^.*\\n//
    /^$/ !b header
    N
    s/^.*\\n//
    :dump
    n
    b dump
}
" | gpg --batch --no-options --armor --encrypt --recipient-file "${USER_KEY_FILE}" 2> /dev/null
echo 
echo "--${mime_boundary}--")

echo "${data_encrypted}" | sed "s/$/${CR}/"
