{ ... }:

{
  programs.firefox = {
    enable = true;

    policies = {
      # 1Password handles passwords; don't let Firefox compete with it.
      OfferToSaveLogins = false;

      ExtensionSettings."{d634138d-c276-4fc8-924b-40a0ea21d284}" = {
        install_url = "https://addons.mozilla.org/firefox/downloads/latest/1password-x-password-manager/latest.xpi";
        installation_mode = "force_installed";
      };
    };
  };
}
