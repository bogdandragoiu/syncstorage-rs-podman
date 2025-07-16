# Firefox Sync Podman
*alternativly: syncstorage-rs-podman*
<br><br>
Heavily inspired from https://github.com/dan-r/syncstorage-rs-docker, but uses `podman` instead of `docker` and `podman kube play` instead of of `docker compose`.

This was created on rootless podman, but I personally use it rootful under Alpine.

## Deployment
1. Clone this repository
1. Copy the example files to the files that you will use
   ```
   cp secret.yaml.example secret.yaml
   cp firefox-sync.yaml.example firefox-sync.yaml
   ```
1. In `firefox-sync.yaml` fill out
   * SYNC_URL
   * (Optional) Specify a different **hostPath.path** in volume named `mariadb-config`
   <br>⚠️ podman should create the folder, but in case it doesn't make sure it exists and set the correct permissions
1. In `secret.yaml` fill out
   * MYSQL_ROOT_PASSWORD
   * MYSQL_PASSWORD
   * SYNC_MASTER_SECRET
   * METRICS_HASH_SECRET<br><br>⚠️ Be sure to read the hints in the file regarding length and base64 encoding<br>
1. Create the secret
   ```
   podman kube play secret.yaml
   ```
1. Deploy the pod
   ```
   podman kube play firefox-sync.yaml
   ```
   ℹ️ This will build the image if it doesn't exist, if you want to force rebuild

   ```
   podman kube play firefox-sync.yaml --build=true
   ```

  ## Auto-start
  This will depend on your `init`
  * systemd - https://docs.podman.io/en/v4.2/markdown/podman-play-kube.1.html#systemd-integration
  * OpenRC under Alpine
    1. Edit or create /etc/local.d/podman.start
    1. Add `/usr/bin/podman pod start firefox-sync`<br>
       or individual containers
       ```
       /usr/bin/podman pod start firefox-sync-mariadb
       /usr/bin/podman pod start firefox-sync-server
       ```

   ## Configure firefox
   1. Create a Mozilla account (verification email will be sent)
   <br>⚠️ You only need to do this **once**.
   1. On each browser you want to sync go to `about:config`
   1. Edit `identity.sync.tokenserver.uri` and set it to **SYNC_URL**
   1. (Optional) Set also `services.sync.log.appender.file.logOnSuccess` to **true** in case you want to debug issues or see  if the sync is working under **about:sync-log**
   <br>
   ℹ️ Failures result in error-sync-\*.log files while success-sync-\* indicate working sync.
   1. Sign into firefox and sync, look for latest docs from Mozilla: https://support.mozilla.org/en-US/kb/how-do-i-set-sync-my-computer

