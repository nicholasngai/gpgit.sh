# gpgit.sh

`gpgit.sh` is a shell wrapper for the [GnuPG](https://gnupg.org/) software, to convert plaintext emails of any `Content-Type` into PGP-encrypted emails using the PGP/MIME format, defined in [RFC 3156](https://tools.ietf.org/html/rfc3156). It reads in a raw email file including headers from STDIN and outputs the email with rewritten headers in the `application/encrypted` MIME type and an encrypted body.

Emails are read in terminated with either LFs or CRLFs and are outputted terminated with CRLFs. Emails already in the `application/encrypted` MIME type will not be changed.

# Usage

`./gpgit.sh [GPG homedir location] [key name]`
