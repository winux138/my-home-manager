{ pkgs, wrap }:
let
  primaryFile = ".config/hypr/lock-password.hash";
  legacyFile = ".config/wayland-nested/lock-password.hash";
  findHashSnippet = ''
    hash_file="$home/${primaryFile}"
    if [[ ! -e $hash_file && -e "$home/${legacyFile}" ]]; then
      hash_file="$home/${legacyFile}"
    fi
  '';
  passwordCheck = pkgs.writeShellApplication {
    name = "hypr-lock-password-check";
    runtimeInputs = with pkgs; [
      coreutils
      getent
      mkpasswd
    ];
    runtimeEnv.LD_LIBRARY_PATH = "${pkgs.sssd}/lib";
    text = ''
      [[ ''${PAM_TYPE:-} == auth ]] || exit 1
      [[ -n ''${PAM_USER:-} ]] || exit 1

      passwd_entry=$(getent passwd "$PAM_USER") || exit 1
      IFS=: read -r user _ uid _ _ home _ <<<"$passwd_entry"
      [[ $user == "$PAM_USER" && $uid == "$(id -u)" ]] || exit 1

      ${findHashSnippet}
      [[ -f $hash_file && ! -L $hash_file && -r $hash_file ]] || exit 1
      [[ $(stat -c '%u:%a' -- "$hash_file") == "$uid:600" ]] || exit 1

      IFS= read -r expected <"$hash_file"
      [[ $expected =~ ^(\$y\$[^$]+\$[^$]+)\$[^$]+$ ]] || exit 1
      actual=$(mkpasswd -m yescrypt -s -S "''${BASH_REMATCH[1]}")
      [[ $actual == "$expected" ]]
    '';
  };
  pam = pkgs.linux-pam.overrideAttrs (old: {
    postInstall = (old.postInstall or "") + ''
      install -d $out/etc/pam.d
      printf '%s\n' \
        'auth required pam_exec.so quiet expose_authtok ${passwordCheck}/bin/hypr-lock-password-check' \
        >$out/etc/pam.d/hyprlock-local
    '';
    outputChecks = (old.outputChecks or { }) // {
      out = (old.outputChecks.out or { }) // {
        disallowedRequisites = [ ];
      };
    };
  });
  hyprlock = wrap (
    (pkgs.hyprlock.override { inherit pam; }).overrideAttrs (old: {
      postPatch = (old.postPatch or "") + ''
        substituteInPlace src/auth/Pam.cpp \
          --replace-fail \
            'if (!std::filesystem::exists(std::filesystem::path("/etc/pam.d/") / m_sPamModule)) {' \
            'if (m_sPamModule != "hyprlock-local" && !std::filesystem::exists(std::filesystem::path("/etc/pam.d/") / m_sPamModule)) {'
      '';
    })
  );
  pamtester = pkgs.pamtester.override { inherit pam; };
  hyprlockConfig = pkgs.writeText "hyprlock.conf" ''
    auth {
        pam {
            module = hyprlock-local
        }
    }

    general {
        hide_cursor = false
    }

    background {
        monitor =
        color = rgba(1e1e2eff)
    }

    input-field {
        monitor =
        size = 300, 60
        outline_thickness = 3
        inner_color = rgba(313244ff)
        outer_color = rgba(89b4faff)
        check_color = rgba(a6e3a1ff)
        fail_color = rgba(f38ba8ff)
        font_color = rgba(cdd6f4ff)
        fade_on_empty = false
        placeholder_text = Local lock password...
        fail_text = $PAMFAIL
        position = 0, 0
        halign = center
        valign = center
    }
  '';
  setPassword = pkgs.writeShellApplication {
    name = "hypr-set-lock-password";
    runtimeInputs = with pkgs; [
      coreutils
      getent
      mkpasswd
    ];
    runtimeEnv.LD_LIBRARY_PATH = "${pkgs.sssd}/lib";
    text = ''
      [[ -t 0 && -t 1 ]] || { echo "an interactive terminal is required" >&2; exit 1; }
      passwd_entry=$(getent passwd "$(id -u)") || { echo "current user lookup failed" >&2; exit 1; }
      IFS=: read -r _ _ _ _ _ home _ <<<"$passwd_entry"

      hash_file="$home/${primaryFile}"
      hash_dir=''${hash_file%/*}
      install -d -m 700 -- "$hash_dir"

      password=
      confirmation=
      read -r -s -p "New local lock password: " password
      printf '\n'
      read -r -s -p "Repeat local lock password: " confirmation
      printf '\n'
      [[ -n $password ]] || { echo "password cannot be empty" >&2; exit 1; }
      if [[ $password != "$confirmation" ]]; then
        unset password confirmation
        echo "passwords do not match" >&2
        exit 1
      fi

      tmp=$(mktemp "$hash_dir/.lock-password.XXXXXX")
      trap 'rm -f -- "$tmp"' EXIT
      printf '%s' "$password" | mkpasswd -m yescrypt -s >"$tmp"
      unset password confirmation
      chmod 600 -- "$tmp"
      mv -f -- "$tmp" "$hash_file"
      trap - EXIT
      printf 'Local lock password hash installed at %s\n' "$hash_file"
    '';
  };
  checkAuth = pkgs.writeShellApplication {
    name = "hypr-check-auth";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.getent
      pamtester
    ];
    runtimeEnv.LD_LIBRARY_PATH = "${pkgs.sssd}/lib";
    text = ''
      [[ -t 0 && -t 1 ]] || { echo "an interactive terminal is required" >&2; exit 1; }
      passwd_entry=$(getent passwd "$(id -u)") || { echo "current user lookup failed" >&2; exit 1; }
      IFS=: read -r user _ _ _ _ home _ <<<"$passwd_entry"
      ${findHashSnippet}
      [[ -r $hash_file ]] || { echo "run 'hypr-set-lock-password' first" >&2; exit 1; }
      printf 'Testing local screen-lock password for %s without locking.\n' "$user"
      exec pamtester hyprlock-local "$user" authenticate
    '';
  };
  lock = pkgs.writeShellApplication {
    name = "hypr-lock";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.getent
      hyprlock
    ];
    runtimeEnv.LD_LIBRARY_PATH = "${pkgs.sssd}/lib";
    text = ''
      : "''${WAYLAND_DISPLAY:?WAYLAND_DISPLAY is not set}"
      : "''${HYPRLAND_INSTANCE_SIGNATURE:?HYPRLAND_INSTANCE_SIGNATURE is not set}"
      passwd_entry=$(getent passwd "$(id -u)") || { echo "current user lookup failed" >&2; exit 1; }
      IFS=: read -r _ _ _ _ _ home _ <<<"$passwd_entry"
      ${findHashSnippet}
      [[ -r $hash_file ]] || { echo "run 'hypr-set-lock-password' first" >&2; exit 1; }
      exec hyprlock --config ${hyprlockConfig} "$@"
    '';
  };
in
{
  inherit
    checkAuth
    lock
    setPassword
    ;
}
