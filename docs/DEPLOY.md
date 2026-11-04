# Deploying The Last Drop

The game ships as a static web site: one HTML page, the engine (`index.js`,
`index.wasm`), the game data (`index.pck`) and a few small files. It is the
single-threaded Godot web build, so it needs **no special server headers**
(no cross-origin isolation, no SharedArrayBuffer). Any static host works.

## 1. Build

Needs Godot 4.7 on the PATH (or `GODOT=/path/to/godot`) and its web export
templates (Editor > Manage Export Templates > Download).

```bash
bash scripts/build_web.sh
```

| Output | Use |
|---|---|
| `build/web/` | the site: upload this folder |
| `build/the-last-drop-web.zip` | the same files zipped, for itch.io |

Check it locally (a phone on the same Wi-Fi can open `http://<your-ip>:8000`):

```bash
python3 -m http.server --directory build/web --bind 0.0.0.0 8000
```

The page registers a service worker only on `https://` or `localhost`, so the
"install app" and offline parts need one of those.

## 2. Publish

### GitHub Pages (automatic)

`.github/workflows/web.yml` runs the tests, builds, and publishes on every push
to `main`.

1. Push the repository to GitHub.
2. Settings > Pages > Build and deployment > Source: **GitHub Actions**.
3. Push to `main` (or run the workflow by hand from the Actions tab).

The address is `https://<user>.github.io/<repo>/`. Pull requests run the tests
and the build but do not publish. Private repositories need a paid plan for
Pages.

### itch.io

1. Create a project, Kind of project: **HTML**.
2. Upload `build/the-last-drop-web.zip` and tick "This file will be played in the browser".
3. Embed options: viewport **960 x 540**, tick **Mobile friendly** (orientation:
   landscape), **Fullscreen button**, and leave **SharedArrayBuffer support** off.

### Netlify

Drag `build/web/` onto https://app.netlify.com/drop, or:

```bash
npx netlify-cli deploy --dir build/web --prod
```

`_headers` in the folder sets the caching rules.

### Cloudflare Pages

```bash
npx wrangler pages deploy build/web --project-name the-last-drop
```

`_headers` is read here too.

### Vercel

```bash
cd build/web && npx vercel deploy --prod
```

`vercel.json` in the folder sets the caching rules.

### Android app (APK)

The same game as a native Android app, for sideloading or an app store. It
uses the same touch controls; the app runs fullscreen in landscape and steps
its buttons around notches.

Needs the Godot Android export templates (Editor > Manage Export Templates),
the Android SDK with build-tools (`ANDROID_HOME`, default `/opt/android-sdk`)
and a JDK 17.

```bash
bash scripts/build_android.sh                                  # debug APK, signed with the Android debug key
adb install -r build/android/the-last-drop-debug.apk           # onto a phone with USB debugging on
```

For a release APK, make your own keystore once and pass it through the
environment (never commit the keystore or its password):

```bash
keytool -genkeypair -v -keystore ~/keys/lastdrop.keystore -alias lastdrop -keyalg RSA -keysize 2048 -validity 10000
GODOT_ANDROID_KEYSTORE_RELEASE_PATH=~/keys/lastdrop.keystore \
GODOT_ANDROID_KEYSTORE_RELEASE_USER=lastdrop \
GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD='<your password>' \
bash scripts/build_android.sh                                  # -> build/android/the-last-drop.apk
```

Google Play wants an Android App Bundle (AAB) instead, which needs Godot's
Gradle build (Project > Install Android Build Template, then set
`gradle_build/use_gradle_build=true` and `gradle_build/export_format=1` in the
Android preset). Raise `version/code` in the preset for every upload.

## Caching and updates

Godot's file names are the same in every build, so nothing is cached as
"immutable". The headers make browsers revalidate each file (a cheap check that
downloads only what changed). The installed app keeps its own offline copy;
when a new build is published it notices, says "A new version of the game is
ready", and the title screen shows **UPDATE READY: LOAD IT**.

## On phones

- Landscape only: in portrait the page shows "Turn your phone sideways".
- Android (Chrome, Edge, Samsung Internet, Firefox): the first tap goes
  fullscreen and locks landscape. "Install app" / "Add to Home screen" gives a
  fullscreen icon that plays offline.
- iPhone and iPad (Safari): web pages cannot go fullscreen on an iPhone. Use
  Share > **Add to Home Screen**; the icon opens the game fullscreen.
- The game saves and pauses whenever the tab or app is put away.
- The download is about 10 MB compressed; the first load on mobile data takes a while.

## Checklist before sharing a link

- [ ] `bash scripts/test.sh` is green
- [ ] `bash scripts/playthrough.sh mobile.mjs` is green (phone, touch only)
- [ ] the page loads over `https://` and the console is clean
- [ ] on a real phone: sideways, fullscreen, the stick and buttons, sound after the first tap
