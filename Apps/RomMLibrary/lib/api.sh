#!/bin/sh
romm_config_value() {
  key="$1"
  config="$2"
  jq -r --arg key "$key" '.[$key] // ""' "$config"
}

romm_base_url() {
  url="$(romm_config_value url "$1")"
  echo "${url%/}"
}

romm_request() {
  config="$1"
  path="$2"
  base="$(romm_base_url "$config")"
  token="$(romm_config_value token "$config")"

  if [ -z "$base" ] || [ -z "$token" ]; then
    echo "RomM URL or API token is not configured." >&2
    return 1
  fi

  curl -fsSL \
    -H "Authorization: Bearer $token" \
    -H "Accept: application/json" \
    "$base$path"
}

romm_test() {
  config="$1"
  if romm_request "$config" "/api/platforms" >/dev/null 2>&1; then
    echo "RomM connection OK."
  else
    echo "Unable to connect to RomM. Check URL, Tailscale/network and API token."
    return 1
  fi
}

romm_platforms() {
  config="$1"
  romm_request "$config" "/api/platforms" | jq -r '.[] | "\(.id)\t\(.name // .slug)"'
}

romm_search() {
  config="$1"
  term="$2"
  encoded="$(printf '%s' "$term" | sed 's/ /%20/g')"
  romm_request "$config" "/api/roms?search=$encoded" | jq -r '.[] | "\(.id)\t\(.name // .file_name)\t\(.platform_id // "")"'
}
