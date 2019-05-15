# gpgit.sh

`gpgit.sh` is a shell wrapper for the [GnuPG](https://gnupg.org/) software, to convert plaintext emails of any `Content-Type` into PGP-encrypted emails using the PGP/MIME format, defined in [RFC 3156](https://tools.ietf.org/html/rfc3156). It reads in a raw email file including headers from STDIN and outputs the email with rewritten headers in the `multipart/encrypted` MIME type and an encrypted body. A public key file is passed in from the command line containing a public key in binary or ASCII-armored form used to encrypt the email.

Emails are read in terminated with either LFs or CRLFs and are outputted terminated with CRLFs. Emails already in the `multipart/encrypted` MIME type will not be changed.

This script is compatible with both GNU and BSD versions of `sed`, which is utilized heavily.

# Usage

`./gpgit.sh [public key file]`
