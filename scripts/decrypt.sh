#!/usr/bin/env bash
#---
# Excerpted from "Engineering Elixir Applications",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material,
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose.
# Visit https://pragprog.com/titles/beamops for more book information.
#---

# in scripts/decrypt.sh

# get path of secrets/ folder relative to current script
# so script can be run from anywhere
CURRENT_SCRIPT_DIRECTORY=$(dirname "$0")
SECRETS_DIRECTORY="$CURRENT_SCRIPT_DIRECTORY/../secrets"

# decrypt the file and store the output in a variable
decrypted_content=$(sops --decrypt $SECRETS_DIRECTORY/secrets.enc.yaml)

# read each line of decrypted content -
# the text before the ":" is the filename and the text after is the secret
echo "${decrypted_content}" | while IFS=: read -r filename value; do
    # trim any leading space from value
    content=$(echo "$value" | xargs)
    # write the content to the corresponding file in the secrets folder
    echo "${content}" > "$SECRETS_DIRECTORY/${filename}"
done
