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

## One-time setup (maintainer)

1. **Generate the key**, in the Podman image, in a folder that is neither in
   the repository nor synced (Syncthing, cloud):

   ```sh
   mkdir -p ~/beam-remoteplus-key
   podman run --rm -it -v ~/beam-remoteplus-key:/key:Z -w /key beamng-remoteplus-flutter:latest \
     keytool -genkeypair -keystore release.p12 -storetype PKCS12 -alias beam-remoteplus \
       -keyalg RSA -keysize 4096 -validity 10000 -dname "CN=Beam-RemotePlus"
   ```

   Use a long random password (password manager).

2. **Back it up**: `release.p12` and its password, in at least two places
   that are not online together (password manager + offline USB stick).

3. **Read the certificate fingerprint**:

   ```sh
   podman run --rm -it -v ~/beam-remoteplus-key:/key:Z -w /key beamng-remoteplus-flutter:latest \
     keytool -list -v -keystore release.p12 -storetype PKCS12 | grep SHA256
   ```

4. **Create the `release` environment** (Settings → Environments):
   - *Required reviewers*: yourself.
   - *Deployment branches and tags*: selected only, tag rule `v*`.

5. **Store the key in the environment** (`gh` asks for the values, so they
   stay out of the shell history):

   ```sh
   base64 -w0 ~/beam-remoteplus-key/release.p12 | gh secret set APK_KEYSTORE_BASE64 --env release
   gh secret set APK_KEYSTORE_PASSWORD --env release
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
