#!/bin/sh
romm_download() {
  config="$1"
  rom_id="$2"

  base="$(romm_base_url "$config")"
  token="$(romm_config_value token "$config")"
  download_dir="$(romm_config_value download_dir "$config")"
  cache_dir="$(romm_config_value cache_dir "$config")"

  if [ -z "$base" ] || [ -z "$token" ] || [ -z "$rom_id" ]; then
    echo "Missing RomM URL, token or ROM ID."
    return 1
  fi

  mkdir -p "$download_dir" "$cache_dir/covers" "$cache_dir/metadata"

  detail="$(romm_request "$config" "/api/roms/$rom_id")" || return 1

  file_name="$(printf '%s' "$detail" | jq -r '.file_name // .fs_filename // empty')"
  platform_id="$(printf '%s' "$detail" | jq -r '.platform_id // empty')"
  name="$(printf '%s' "$detail" | jq -r '.name // .file_name // "rom"')"

  if [ -z "$file_name" ]; then
    echo "Unable to determine ROM filename from RomM API response."
    return 1
  fi

  platform_dir="$download_dir/$platform_id"
  mkdir -p "$platform_dir"

  echo "Downloading: $name"
  curl -fL \
    -H "Authorization: Bearer $token" \
    -o "$platform_dir/$file_name" \
    "$base/api/roms/$rom_id/content/$file_name" || {
      echo "ROM download failed. Check the RomM download endpoint for your RomM version."
      return 1
    }

  cover_url="$(printf '%s' "$detail" | jq -r '.url_cover // .path_cover_large // .path_cover_small // empty')"
  if [ -n "$cover_url" ]; then
    safe_name="$(printf '%s' "$name" | tr -c '[:alnum:]._-' '_')"
    curl -fsSL -H "Authorization: Bearer $token" \
      -o "$cache_dir/covers/$safe_name.png" "$cover_url" || true
  fi

  printf '%s\n' "$detail" > "$cache_dir/metadata/$rom_id.json"
  sync
  echo "ROM downloaded to: $platform_dir/$file_name"
}
