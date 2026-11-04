# APK signing

Release APKs are signed with one key, so every update installs over the
previous version. Android identifies an app by its package name **and** the
certificate that signed it: whoever holds the key can publish an "update"
that any phone accepts. This page explains how the key is protected.

## What protects the key

| Threat | Protection |
|---|---|
| A pull request (fork, Dependabot) reads the secrets | The secrets are not repository secrets: they live in the `release` **environment**, which only the `sign` job of `release.yml` uses. Workflows of pull requests never get them. |
| A modified workflow on a branch uses the environment | The environment only accepts **tags `v*`**, and tags are protected by the `protect-release-tags` ruleset. |
| Someone with a stolen GitHub token pushes a tag | The environment needs an **approval** in the GitHub web interface before the job gets the secrets. |
| A compromised third-party action steals the key | The job that builds (Flutter, SBOM actions) has **no secret**. The signing job runs no third-party action: only GitHub's artifact download and `apksigner` from the runner's Android SDK. |
| The password appears in logs or in the process list | It reaches `apksigner` through an environment variable (`--ks-pass env:`), never as an argument; GitHub masks secrets in logs. |
| A wrong or extra signature slips through | After signing, each APK must have exactly one signer whose certificate matches `APK_CERT_SHA256`, otherwise the release fails. Missing secrets also fail the release (no silent debug-signed APK). |
| The key is lost | Nothing can update the installed app any more: users would have to uninstall. Keep the backups below. |

## Current key

| | |
|---|---|
| Certificate SHA-256 | `95:F1:43:9E:C1:AB:EF:39:03:52:CD:D7:49:40:A4:B2:A0:89:C8:DA:8A:F3:9C:14:F2:89:14:00:2D:7A:8A:13` |
| Subject | `CN=Beam-RemotePlus` |
| Key | RSA 4096, certificate signed with SHA384withRSA |
| Valid | 2026-11-04 to 2054-03-22 |
| Alias | `beam-remoteplus` (PKCS12 keystore) |

Created on 2026-11-04 with the steps below; the `release` environment holds
`APK_KEYSTORE_BASE64`, `APK_KEYSTORE_PASSWORD`, `APK_KEY_ALIAS` (secrets)
and `APK_CERT_SHA256` (variable). Before upload, a release APK was signed
with it locally the way the `sign` job does (`apksigner` 36.0.0): the debug
signature is replaced, one signer, schemes v2 + v3, fingerprint check OK.

## One-time setup (maintainer)

Already done for the current key; kept to rotate or recreate it.

1. **Generate the key**, in the Podman image, in a folder that is neither in
   the repository nor synced (Syncthing, cloud):

   ```sh
   mkdir -p ~/beam-remoteplus-key && chmod 700 ~/beam-remoteplus-key
   podman run --rm --entrypoint bash -v ~/beam-remoteplus-key:/key:Z -w /key beamng-remoteplus-flutter:latest -c '
     set -e; umask 077
     head -c 48 /dev/urandom | base64 | tr -d "/+=\n" | head -c 48 > password.txt
     keytool -genkeypair -keystore release.p12 -storetype PKCS12 -alias beam-remoteplus \
       -keyalg RSA -keysize 4096 -validity 10000 -dname "CN=Beam-RemotePlus" \
       -storepass:file password.txt -keypass:file password.txt'
   ```

   The password is random (48 characters) and goes straight to
   `password.txt`, so it never appears on screen or in a shell history.

2. **Back it up**: `release.p12` and its password, in at least two places
   that are not online together (password manager + offline USB stick).

3. **Read the certificate fingerprint**:

   ```sh
   podman run --rm --entrypoint keytool -v ~/beam-remoteplus-key:/key:Z -w /key beamng-remoteplus-flutter:latest \
     -list -v -keystore release.p12 -storetype PKCS12 -storepass:file password.txt | grep SHA256
   ```

4. **Create the `release` environment** (Settings → Environments):
   - *Required reviewers*: yourself.
   - *Deployment branches and tags*: selected only, tag rule `v*`.

5. **Store the key in the environment** (values come from stdin or files, so
   they stay out of the shell history):

   ```sh
   base64 -w0 ~/beam-remoteplus-key/release.p12 | gh secret set APK_KEYSTORE_BASE64 --env release
   gh secret set APK_KEYSTORE_PASSWORD --env release < ~/beam-remoteplus-key/password.txt
   gh secret set APK_KEY_ALIAS --env release --body beam-remoteplus
   gh variable set APK_CERT_SHA256 --env release --body "<fingerprint from step 3>"
   ```

6. Publish the fingerprint in the [README](../README.md#verifying-the-apk).

## Each release

Publishing a release starts `release.yml`: the `build` job runs, then the
`sign` job waits for your approval (Actions tab → *Review deployments*).

## Local builds

`scripts/build_apk.sh` signs with `app/android/key.properties` when it
exists (see `key.properties.example`), otherwise with the debug key. Test
builds do not need the release key; keep it out of the working tree.
