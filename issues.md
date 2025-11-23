2025-11-23T15:31:31.4018871Z Current runner version: '2.329.0'
2025-11-23T15:31:31.4043514Z ##[group]Runner Image Provisioner
2025-11-23T15:31:31.4044618Z Hosted Compute Agent
2025-11-23T15:31:31.4045429Z Version: 20251016.436
2025-11-23T15:31:31.4046678Z Commit: 8ab8ac8bfd662a3739dab9fe09456aba92132568
2025-11-23T15:31:31.4047651Z Build Date: 2025-10-15T20:44:12Z
2025-11-23T15:31:31.4048541Z ##[endgroup]
2025-11-23T15:31:31.4049297Z ##[group]Operating System
2025-11-23T15:31:31.4050169Z Ubuntu
2025-11-23T15:31:31.4050900Z 24.04.3
2025-11-23T15:31:31.4051619Z LTS
2025-11-23T15:31:31.4052401Z ##[endgroup]
2025-11-23T15:31:31.4053190Z ##[group]Runner Image
2025-11-23T15:31:31.4054057Z Image: ubuntu-24.04
2025-11-23T15:31:31.4054862Z Version: 20251112.124.1
2025-11-23T15:31:31.4056413Z Included Software: https://github.com/actions/runner-images/blob/ubuntu24/20251112.124/images/ubuntu/Ubuntu2404-Readme.md
2025-11-23T15:31:31.4058275Z Image Release: https://github.com/actions/runner-images/releases/tag/ubuntu24%2F20251112.124
2025-11-23T15:31:31.4059627Z ##[endgroup]
2025-11-23T15:31:31.4061139Z ##[group]GITHUB_TOKEN Permissions
2025-11-23T15:31:31.4063266Z Contents: read
2025-11-23T15:31:31.4064142Z Metadata: read
2025-11-23T15:31:31.4064896Z ##[endgroup]
2025-11-23T15:31:31.4067508Z Secret source: Actions
2025-11-23T15:31:31.4069338Z Prepare workflow directory
2025-11-23T15:31:31.4392718Z Prepare all required actions
2025-11-23T15:31:31.4432722Z Getting action download info
2025-11-23T15:31:31.8259806Z Download action repository 'actions/checkout@v4' (SHA:34e114876b0b11c390a56381ad16ebd13914f8d5)
2025-11-23T15:31:32.3816529Z Download action repository 'subosito/flutter-action@v2' (SHA:fd55f4c5af5b953cc57a2be44cb082c8f6635e8e)
2025-11-23T15:31:32.6929366Z Download action repository 'FirebaseExtended/action-hosting-deploy@v0' (SHA:e2eda2e106cfa35cdbcf4ac9ddaf6c4756df2c8c)
2025-11-23T15:31:33.1774424Z Getting action download info
2025-11-23T15:31:33.3447712Z Download action repository 'actions/cache@v4' (SHA:0057852bfaa89a56745cba8c7296529d2fc39830)
2025-11-23T15:31:33.5989154Z Complete job name: deploy
2025-11-23T15:31:33.6866510Z ##[group]Run actions/checkout@v4
2025-11-23T15:31:33.6868191Z with:
2025-11-23T15:31:33.6869333Z   repository: BishalBudhathoki/alterred
2025-11-23T15:31:33.6870949Z   token: ***
2025-11-23T15:31:33.6872040Z   ssh-strict: true
2025-11-23T15:31:33.6873146Z   ssh-user: git
2025-11-23T15:31:33.6874316Z   persist-credentials: true
2025-11-23T15:31:33.6875529Z   clean: true
2025-11-23T15:31:33.6876921Z   sparse-checkout-cone-mode: true
2025-11-23T15:31:33.6878223Z   fetch-depth: 1
2025-11-23T15:31:33.6879340Z   fetch-tags: false
2025-11-23T15:31:33.6880476Z   show-progress: true
2025-11-23T15:31:33.6881608Z   lfs: false
2025-11-23T15:31:33.6882714Z   submodules: false
2025-11-23T15:31:33.6883861Z   set-safe-directory: true
2025-11-23T15:31:33.6885341Z ##[endgroup]
2025-11-23T15:31:33.7974194Z Syncing repository: BishalBudhathoki/alterred
2025-11-23T15:31:33.7977564Z ##[group]Getting Git version info
2025-11-23T15:31:33.7979307Z Working directory is '/home/runner/work/alterred/alterred'
2025-11-23T15:31:33.7981650Z [command]/usr/bin/git version
2025-11-23T15:31:33.8051460Z git version 2.51.2
2025-11-23T15:31:33.8077780Z ##[endgroup]
2025-11-23T15:31:33.8091857Z Temporarily overriding HOME='/home/runner/work/_temp/52060a93-eb2c-44c0-bd8c-23f5bfd38335' before making global git config changes
2025-11-23T15:31:33.8094963Z Adding repository directory to the temporary git global config as a safe directory
2025-11-23T15:31:33.8104354Z [command]/usr/bin/git config --global --add safe.directory /home/runner/work/alterred/alterred
2025-11-23T15:31:33.8140196Z Deleting the contents of '/home/runner/work/alterred/alterred'
2025-11-23T15:31:33.8143407Z ##[group]Initializing the repository
2025-11-23T15:31:33.8147687Z [command]/usr/bin/git init /home/runner/work/alterred/alterred
2025-11-23T15:31:33.8255763Z hint: Using 'master' as the name for the initial branch. This default branch name
2025-11-23T15:31:33.8258487Z hint: is subject to change. To configure the initial branch name to use in all
2025-11-23T15:31:33.8261772Z hint: of your new repositories, which will suppress this warning, call:
2025-11-23T15:31:33.8263746Z hint:
2025-11-23T15:31:33.8265188Z hint: 	git config --global init.defaultBranch <name>
2025-11-23T15:31:33.8267493Z hint:
2025-11-23T15:31:33.8269158Z hint: Names commonly chosen instead of 'master' are 'main', 'trunk' and
2025-11-23T15:31:33.8271877Z hint: 'development'. The just-created branch can be renamed via this command:
2025-11-23T15:31:33.8273772Z hint:
2025-11-23T15:31:33.8274846Z hint: 	git branch -m <name>
2025-11-23T15:31:33.8276067Z hint:
2025-11-23T15:31:33.8277840Z hint: Disable this message with "git config set advice.defaultBranchName false"
2025-11-23T15:31:33.8280049Z Initialized empty Git repository in /home/runner/work/alterred/alterred/.git/
2025-11-23T15:31:33.8283776Z [command]/usr/bin/git remote add origin https://github.com/BishalBudhathoki/alterred
2025-11-23T15:31:33.8307961Z ##[endgroup]
2025-11-23T15:31:33.8309874Z ##[group]Disabling automatic garbage collection
2025-11-23T15:31:33.8311806Z [command]/usr/bin/git config --local gc.auto 0
2025-11-23T15:31:33.8339384Z ##[endgroup]
2025-11-23T15:31:33.8341159Z ##[group]Setting up auth
2025-11-23T15:31:33.8345497Z [command]/usr/bin/git config --local --name-only --get-regexp core\.sshCommand
2025-11-23T15:31:33.8374629Z [command]/usr/bin/git submodule foreach --recursive sh -c "git config --local --name-only --get-regexp 'core\.sshCommand' && git config --local --unset-all 'core.sshCommand' || :"
2025-11-23T15:31:33.8714616Z [command]/usr/bin/git config --local --name-only --get-regexp http\.https\:\/\/github\.com\/\.extraheader
2025-11-23T15:31:33.8743113Z [command]/usr/bin/git submodule foreach --recursive sh -c "git config --local --name-only --get-regexp 'http\.https\:\/\/github\.com\/\.extraheader' && git config --local --unset-all 'http.https://github.com/.extraheader' || :"
2025-11-23T15:31:33.8959042Z [command]/usr/bin/git config --local --name-only --get-regexp ^includeIf\.gitdir:
2025-11-23T15:31:33.8995766Z [command]/usr/bin/git submodule foreach --recursive git config --local --show-origin --name-only --get-regexp remote.origin.url
2025-11-23T15:31:33.9215173Z [command]/usr/bin/git config --local http.https://github.com/.extraheader AUTHORIZATION: basic ***
2025-11-23T15:31:33.9248663Z ##[endgroup]
2025-11-23T15:31:33.9250556Z ##[group]Fetching the repository
2025-11-23T15:31:33.9258564Z [command]/usr/bin/git -c protocol.version=2 fetch --no-tags --prune --no-recurse-submodules --depth=1 origin +a1b12d0c26e3a503af46e4650e48b460116e31c9:refs/remotes/origin/main
2025-11-23T15:31:34.2532029Z From https://github.com/BishalBudhathoki/alterred
2025-11-23T15:31:34.2533992Z  * [new ref]         a1b12d0c26e3a503af46e4650e48b460116e31c9 -> origin/main
2025-11-23T15:31:34.2564493Z ##[endgroup]
2025-11-23T15:31:34.2565658Z ##[group]Determining the checkout info
2025-11-23T15:31:34.2567278Z ##[endgroup]
2025-11-23T15:31:34.2572744Z [command]/usr/bin/git sparse-checkout disable
2025-11-23T15:31:34.2613656Z [command]/usr/bin/git config --local --unset-all extensions.worktreeConfig
2025-11-23T15:31:34.2640211Z ##[group]Checking out the ref
2025-11-23T15:31:34.2644704Z [command]/usr/bin/git checkout --progress --force -B main refs/remotes/origin/main
2025-11-23T15:31:34.2801211Z Switched to a new branch 'main'
2025-11-23T15:31:34.2804632Z branch 'main' set up to track 'origin/main'.
2025-11-23T15:31:34.2811837Z ##[endgroup]
2025-11-23T15:31:34.2845773Z [command]/usr/bin/git log -1 --format=%H
2025-11-23T15:31:34.2866914Z a1b12d0c26e3a503af46e4650e48b460116e31c9
2025-11-23T15:31:34.3160630Z ##[group]Run subosito/flutter-action@v2
2025-11-23T15:31:34.3161138Z with:
2025-11-23T15:31:34.3161500Z   channel: stable
2025-11-23T15:31:34.3161880Z   architecture: X64
2025-11-23T15:31:34.3162251Z   cache: false
2025-11-23T15:31:34.3162636Z   pub-cache-path: default
2025-11-23T15:31:34.3163038Z   dry-run: false
2025-11-23T15:31:34.3163488Z   git-source: https://github.com/flutter/flutter.git
2025-11-23T15:31:34.3164166Z ##[endgroup]
2025-11-23T15:31:34.3268491Z ##[group]Run chmod +x "$GITHUB_ACTION_PATH/setup.sh"
2025-11-23T15:31:34.3269122Z [36;1mchmod +x "$GITHUB_ACTION_PATH/setup.sh"[0m
2025-11-23T15:31:34.3307665Z shell: /usr/bin/bash --noprofile --norc -e -o pipefail ***0***
2025-11-23T15:31:34.3308238Z ##[endgroup]
2025-11-23T15:31:34.3445032Z ##[group]Run $GITHUB_ACTION_PATH/setup.sh -p \
2025-11-23T15:31:34.3445626Z [36;1m$GITHUB_ACTION_PATH/setup.sh -p \[0m
2025-11-23T15:31:34.3446092Z [36;1m  -n '' \[0m
2025-11-23T15:31:34.3446755Z [36;1m  -f '' \[0m
2025-11-23T15:31:34.3447175Z [36;1m  -a 'X64' \[0m
2025-11-23T15:31:34.3447556Z [36;1m  -k '' \[0m
2025-11-23T15:31:34.3447926Z [36;1m  -c '' \[0m
2025-11-23T15:31:34.3448290Z [36;1m  -l '' \[0m
2025-11-23T15:31:34.3448670Z [36;1m  -d 'default' \[0m
2025-11-23T15:31:34.3449164Z [36;1m  -g 'https://github.com/flutter/flutter.git' \[0m
2025-11-23T15:31:34.3449657Z [36;1m  stable[0m
2025-11-23T15:31:34.3481039Z shell: /usr/bin/bash --noprofile --norc -e -o pipefail ***0***
2025-11-23T15:31:34.3481600Z ##[endgroup]
2025-11-23T15:31:34.6496853Z ##[group]Run $GITHUB_ACTION_PATH/setup.sh \
2025-11-23T15:31:34.6497400Z [36;1m$GITHUB_ACTION_PATH/setup.sh \[0m
2025-11-23T15:31:34.6497861Z [36;1m  -n '3.38.3' \[0m
2025-11-23T15:31:34.6498255Z [36;1m  -a 'x64' \[0m
2025-11-23T15:31:34.6523089Z [36;1m  -c '/opt/hostedtoolcache/flutter/stable-3.38.3-x64' \[0m
2025-11-23T15:31:34.6524081Z [36;1m  -d '/home/runner/.pub-cache' \[0m
2025-11-23T15:31:34.6524889Z [36;1m  stable[0m
2025-11-23T15:31:34.6564139Z shell: /usr/bin/bash --noprofile --norc -e -o pipefail ***0***
2025-11-23T15:31:34.6564709Z ##[endgroup]
2025-11-23T15:31:34.9286747Z   % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
2025-11-23T15:31:34.9289586Z                                  Dload  Upload   Total   Spent    Left  Speed
2025-11-23T15:31:34.9290246Z 
2025-11-23T15:31:35.7211403Z   0     0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0
2025-11-23T15:31:36.7211536Z   6 1396M    6 86.1M    0     0   108M      0  0:00:12 --:--:--  0:00:12  108M
2025-11-23T15:31:37.7211246Z  18 1396M   18  253M    0     0   141M      0  0:00:09  0:00:01  0:00:08  141M
2025-11-23T15:31:38.7212968Z  30 1396M   30  420M    0     0   150M      0  0:00:09  0:00:02  0:00:07  150M
2025-11-23T15:31:39.7210708Z  42 1396M   42  587M    0     0   154M      0  0:00:09  0:00:03  0:00:06  154M
2025-11-23T15:31:40.7210362Z  54 1396M   54  755M    0     0   157M      0  0:00:08  0:00:04  0:00:04  157M
2025-11-23T15:31:41.7210464Z  66 1396M   66  921M    0     0   159M      0  0:00:08  0:00:05  0:00:03  167M
2025-11-23T15:31:42.7212633Z  78 1396M   78 1089M    0     0   160M      0  0:00:08  0:00:06  0:00:02  167M
2025-11-23T15:31:43.5558541Z  89 1396M   89 1256M    0     0   161M      0  0:00:08  0:00:07  0:00:01  167M
2025-11-23T15:32:32.8118896Z 100 1396M  100 1396M    0     0   161M      0  0:00:08  0:00:08 --:--:--  167M
2025-11-23T15:32:32.8194002Z ##[group]Run flutter pub get
2025-11-23T15:32:32.8194377Z [36;1mflutter pub get[0m
2025-11-23T15:32:32.8230474Z shell: /usr/bin/bash -e ***0***
2025-11-23T15:32:32.8230817Z env:
2025-11-23T15:32:32.8231168Z   FLUTTER_ROOT: /opt/hostedtoolcache/flutter/stable-3.38.3-x64
2025-11-23T15:32:32.8231622Z   PUB_CACHE: /home/runner/.pub-cache
2025-11-23T15:32:32.8231955Z ##[endgroup]
2025-11-23T15:32:36.5658734Z Resolving dependencies...
2025-11-23T15:32:37.0869102Z Downloading packages...
2025-11-23T15:32:38.5946821Z   _flutterfire_internals 1.3.59 (1.3.64 available)
2025-11-23T15:32:38.5947555Z   characters 1.4.0 (1.4.1 available)
2025-11-23T15:32:38.5948163Z   firebase_auth 5.7.0 (6.1.2 available)
2025-11-23T15:32:38.5949030Z   firebase_auth_platform_interface 7.7.3 (8.1.4 available)
2025-11-23T15:32:38.5949726Z   firebase_auth_web 5.15.3 (6.1.0 available)
2025-11-23T15:32:38.5950335Z   firebase_core 3.15.2 (4.2.1 available)
2025-11-23T15:32:38.5951007Z   firebase_core_web 2.24.1 (3.3.0 available)
2025-11-23T15:32:38.5951928Z   flutter_lints 3.0.2 (6.0.0 available)
2025-11-23T15:32:38.5952500Z   flutter_riverpod 2.6.1 (3.0.3 available)
2025-11-23T15:32:38.5953086Z   google_sign_in 6.3.0 (7.2.0 available)
2025-11-23T15:32:38.5953702Z   google_sign_in_android 6.2.1 (7.2.6 available)
2025-11-23T15:32:38.5954362Z   google_sign_in_ios 5.9.0 (6.2.4 available)
2025-11-23T15:32:38.5955099Z   google_sign_in_platform_interface 2.5.0 (3.1.0 available)
2025-11-23T15:32:38.5955810Z   google_sign_in_web 0.12.4+4 (1.1.0 available)
2025-11-23T15:32:38.5956633Z   lints 3.0.0 (6.0.0 available)
2025-11-23T15:32:38.5957159Z   matcher 0.12.17 (0.12.18 available)
2025-11-23T15:32:38.5957844Z   material_color_utilities 0.11.1 (0.13.0 available)
2025-11-23T15:32:38.5958473Z > meta 1.17.0 (was 1.16.0)
2025-11-23T15:32:38.5958997Z   riverpod 2.6.1 (3.0.3 available)
2025-11-23T15:32:38.5959618Z   shared_preferences_android 2.4.16 (2.4.17 available)
2025-11-23T15:32:38.5960305Z > test_api 0.7.7 (was 0.7.6) (0.7.8 available)
2025-11-23T15:32:38.5960905Z Changed 2 dependencies!
2025-11-23T15:32:38.5961643Z 20 packages have newer versions incompatible with dependency constraints.
2025-11-23T15:32:38.5962484Z Try `flutter pub outdated` for more information.
2025-11-23T15:32:39.1201382Z ##[group]Run flutter build web --release -t lib/main.dart \
2025-11-23T15:32:39.1201925Z [36;1mflutter build web --release -t lib/main.dart \[0m
2025-11-23T15:32:39.1202558Z [36;1m  --dart-define=API_BASE_URL=$***API_BASE_URL*** \[0m
2025-11-23T15:32:39.1203368Z [36;1m  --dart-define=FIREBASE_API_KEY=$***FIREBASE_API_KEY*** \[0m
2025-11-23T15:32:39.1204172Z [36;1m  --dart-define=FIREBASE_APP_ID=$***FIREBASE_APP_ID*** \[0m
2025-11-23T15:32:39.1205043Z [36;1m  --dart-define=FIREBASE_MESSAGING_SENDER_ID=$***FIREBASE_MESSAGING_SENDER_ID*** \[0m
2025-11-23T15:32:39.1205940Z [36;1m  --dart-define=FIREBASE_PROJECT_ID=$***FIREBASE_PROJECT_ID***[0m
2025-11-23T15:32:39.1240828Z shell: /usr/bin/bash -e ***0***
2025-11-23T15:32:39.1241162Z env:
2025-11-23T15:32:39.1241521Z   FLUTTER_ROOT: /opt/hostedtoolcache/flutter/stable-3.38.3-x64
2025-11-23T15:32:39.1241961Z   PUB_CACHE: /home/runner/.pub-cache
2025-11-23T15:32:39.1242284Z   API_BASE_URL: /api
2025-11-23T15:32:39.1249888Z   FIREBASE_API_KEY: ***
2025-11-23T15:32:39.1250210Z   FIREBASE_APP_ID: ***
2025-11-23T15:32:39.1250528Z   FIREBASE_MESSAGING_SENDER_ID: ***
2025-11-23T15:32:39.1250869Z   FIREBASE_PROJECT_ID: ***
2025-11-23T15:32:39.1251147Z ##[endgroup]
2025-11-23T15:33:18.8991525Z Compiling lib/main.dart for the Web...                          
2025-11-23T15:33:18.9000841Z Wasm dry run findings:
2025-11-23T15:33:18.9001422Z Found incompatibilities with WebAssembly.
2025-11-23T15:33:18.9001848Z 
2025-11-23T15:33:18.9003380Z file:///home/runner/.pub-cache/hosted/pub.dev/flutter_tts-4.2.3/lib/flutter_tts_web.dart 104:23 - invalid_runtime_check_with_js_interop_types lint violation: Cast from 'JSAny?' to 'int' casts a JS interop value to a Dart type, which might not be platform-consistent. (8)
2025-11-23T15:33:18.9006812Z file:///home/runner/.pub-cache/hosted/pub.dev/flutter_tts-4.2.3/lib/flutter_tts_web.dart 105:21 - invalid_runtime_check_with_js_interop_types lint violation: Cast from 'JSAny?' to 'String' casts a JS interop value to a Dart type, which might not be platform-consistent. (8)
2025-11-23T15:33:18.9009845Z file:///home/runner/.pub-cache/hosted/pub.dev/flutter_tts-4.2.3/lib/flutter_tts_web.dart 107:21 - invalid_runtime_check_with_js_interop_types lint violation: Cast from 'JSAny?' to 'String' casts a JS interop value to a Dart type, which might not be platform-consistent. (8)
2025-11-23T15:33:18.9011325Z 
2025-11-23T15:33:18.9012086Z Consider addressing these issues to enable wasm builds. See docs for more info: https://docs.flutter.dev/platform-integration/web/wasm
2025-11-23T15:33:18.9012963Z 
2025-11-23T15:33:18.9014518Z Use --no-wasm-dry-run to disable these warnings.
2025-11-23T15:33:20.6464617Z Font asset "CupertinoIcons.ttf" was tree-shaken, reducing it from 257628 to 1472 bytes (99.4% reduction). Tree-shaking can be disabled by providing the --no-tree-shake-icons flag when building your app.
2025-11-23T15:33:20.6478519Z Font asset "MaterialIcons-Regular.otf" was tree-shaken, reducing it from 1645184 to 11976 bytes (99.3% reduction). Tree-shaking can be disabled by providing the --no-tree-shake-icons flag when building your app.
2025-11-23T15:33:21.1740908Z Compiling lib/main.dart for the Web...                             41.6s
2025-11-23T15:33:21.1748713Z ✓ Built build/web
2025-11-23T15:33:21.1963306Z ##[group]Run FirebaseExtended/action-hosting-deploy@v0
2025-11-23T15:33:21.1963748Z with:
2025-11-23T15:33:21.1964124Z   repoToken: ***
2025-11-23T15:33:21.1973562Z   firebaseServiceAccount: ***

2025-11-23T15:33:21.1973916Z   projectId: ***
2025-11-23T15:33:21.1974178Z   channelId: live
2025-11-23T15:33:21.1974432Z   entryPoint: .
2025-11-23T15:33:21.1974680Z   expires: 7d
2025-11-23T15:33:21.1974943Z   firebaseToolsVersion: latest
2025-11-23T15:33:21.1975243Z   disableComment: false
2025-11-23T15:33:21.1975537Z   force: false
2025-11-23T15:33:21.1975778Z env:
2025-11-23T15:33:21.1976093Z   FLUTTER_ROOT: /opt/hostedtoolcache/flutter/stable-3.38.3-x64
2025-11-23T15:33:21.1976831Z   PUB_CACHE: /home/runner/.pub-cache
2025-11-23T15:33:21.1977141Z ##[endgroup]
2025-11-23T15:33:21.2618204Z ##[group]Verifying firebase.json exists
2025-11-23T15:33:21.2623778Z firebase.json file found. Continuing deploy.
2025-11-23T15:33:21.2627735Z ##[endgroup]
2025-11-23T15:33:21.2628667Z ##[group]Setting up CLI credentials
2025-11-23T15:33:21.2641877Z Created a temporary file with Application Default Credentials.
2025-11-23T15:33:21.2643213Z ##[endgroup]
2025-11-23T15:33:21.2644061Z ##[group]Deploying to production site
2025-11-23T15:33:21.2681168Z [command]/usr/local/bin/npx firebase-tools@latest deploy --only hosting --project *** --json
2025-11-23T15:33:29.8660673Z npm warn exec The following package was not found and will be installed: firebase-tools@14.26.0
2025-11-23T15:33:44.0809768Z npm warn deprecated node-domexception@1.0.0: Use your platform's native DOMException instead
2025-11-23T15:33:55.0579506Z ***
2025-11-23T15:33:55.0582848Z   "status": "error",
2025-11-23T15:33:55.0585150Z   "error": "Request to https://firebasehosting.googleapis.com/v1beta1/projects/-/sites/***/versions/6992edfa26fe1823?updateMask=status%2Cconfig had HTTP Error: 400, Cloud Run service `neuropilot-api` does not exist in region `australia-southeast1` in this project."
2025-11-23T15:33:55.3683689Z ***
2025-11-23T15:33:55.3684148Z   "status": "error",
2025-11-23T15:33:55.3686042Z   "error": "Request to https://firebasehosting.googleapis.com/v1beta1/projects/-/sites/***/versions/6992edfa26fe1823?updateMask=status%2Cconfig had HTTP Error: 400, Cloud Run service `neuropilot-api` does not exist in region `australia-southeast1` in this project."
2025-11-23T15:33:55.3688167Z ***
2025-11-23T15:33:55.3688678Z The process '/usr/local/bin/npx' failed with exit code 1
2025-11-23T15:33:55.3689455Z Retrying deploy with the --debug flag for better error output
2025-11-23T15:33:55.3712577Z [command]/usr/local/bin/npx firebase-tools@latest deploy --only hosting --project *** --debug
2025-11-23T15:33:57.9395300Z [2025-11-23T15:33:57.938Z] > command requires scopes: ["email","openid","https://www.googleapis.com/auth/cloudplatformprojects.readonly","https://www.googleapis.com/auth/firebase","https://www.googleapis.com/auth/cloud-platform"]
2025-11-23T15:33:58.0573550Z [2025-11-23T15:33:58.056Z] Running auto auth
2025-11-23T15:33:58.0578854Z [2025-11-23T15:33:58.057Z] [iam] checking project *** for permissions ["firebase.projects.get","firebasehosting.sites.update"]
2025-11-23T15:33:58.0586122Z [2025-11-23T15:33:58.058Z] No OAuth tokens found
2025-11-23T15:33:58.0596875Z [2025-11-23T15:33:58.059Z] >>> [apiv2][query] POST https://cloudresourcemanager.googleapis.com/v1/projects/***:testIamPermissions [none]
2025-11-23T15:33:58.0598981Z [2025-11-23T15:33:58.059Z] >>> [apiv2][(partial)header] POST https://cloudresourcemanager.googleapis.com/v1/projects/***:testIamPermissions x-goog-quota-user=projects/***
2025-11-23T15:33:58.0608067Z [2025-11-23T15:33:58.059Z] >>> [apiv2][body] POST https://cloudresourcemanager.googleapis.com/v1/projects/***:testIamPermissions ***"permissions":["firebase.projects.get","firebasehosting.sites.update"]***
2025-11-23T15:33:58.1658991Z [2025-11-23T15:33:58.165Z] <<< [apiv2][status] POST https://cloudresourcemanager.googleapis.com/v1/projects/***:testIamPermissions 200
2025-11-23T15:33:58.1662146Z [2025-11-23T15:33:58.165Z] <<< [apiv2][body] POST https://cloudresourcemanager.googleapis.com/v1/projects/***:testIamPermissions ***"permissions":["firebase.projects.get","firebasehosting.sites.update"]***
2025-11-23T15:33:58.1667315Z [2025-11-23T15:33:58.166Z] No OAuth tokens found
2025-11-23T15:33:58.1672343Z [2025-11-23T15:33:58.166Z] >>> [apiv2][query] GET https://firebase.googleapis.com/v1beta1/projects/*** [none]
2025-11-23T15:33:58.3503859Z [2025-11-23T15:33:58.349Z] <<< [apiv2][status] GET https://firebase.googleapis.com/v1beta1/projects/*** 200
2025-11-23T15:33:58.3506884Z [2025-11-23T15:33:58.350Z] <<< [apiv2][body] GET https://firebase.googleapis.com/v1beta1/projects/*** ***"projectId":"***","projectNumber":"***","displayName":"NeuroPilot","name":"projects/***","resources":***"hostingSite":"***"***,"state":"ACTIVE","etag":"1_577118ab-92fe-4772-99e2-7deda2bead55"***
2025-11-23T15:33:58.3519454Z 
2025-11-23T15:33:58.3520019Z === Deploying to '***'...
2025-11-23T15:33:58.3522044Z 
2025-11-23T15:33:58.3524190Z i  deploying hosting 
2025-11-23T15:33:58.3534560Z [2025-11-23T15:33:58.353Z] No OAuth tokens found
2025-11-23T15:33:58.3536621Z [2025-11-23T15:33:58.353Z] >>> [apiv2][query] POST https://firebasehosting.googleapis.com/v1beta1/projects/-/sites/***/versions [none]
2025-11-23T15:33:58.3538917Z [2025-11-23T15:33:58.353Z] >>> [apiv2][body] POST https://firebasehosting.googleapis.com/v1beta1/projects/-/sites/***/versions ***"status":"CREATED","labels":***"deployment-tool":"cli-firebase--action-hosting-deploy"***
2025-11-23T15:33:58.6829968Z [2025-11-23T15:33:58.682Z] <<< [apiv2][status] POST https://firebasehosting.googleapis.com/v1beta1/projects/-/sites/***/versions 200
2025-11-23T15:33:58.6832868Z [2025-11-23T15:33:58.682Z] <<< [apiv2][body] POST https://firebasehosting.googleapis.com/v1beta1/projects/-/sites/***/versions ***"name":"projects/***/sites/***/versions/21549fbcc7099369","status":"CREATED","config":***,"labels":***"deployment-tool":"cli-firebase--action-hosting-deploy"***
2025-11-23T15:33:58.6849891Z i  hosting[***]: beginning deploy... 
2025-11-23T15:33:58.6967862Z i  hosting[***]: found 27 files in frontend/flutter_neuropilot/build/web 
2025-11-23T15:33:58.6969788Z [2025-11-23T15:33:58.696Z] [hosting] uploading with 200 concurrency
2025-11-23T15:33:58.6994088Z [2025-11-23T15:33:58.699Z] No OAuth tokens found
2025-11-23T15:33:58.7001666Z [2025-11-23T15:33:58.699Z] [hosting] hash cache [ZnJvbnRlbmQvZmx1dHRlcl9uZXVyb3BpbG90L2J1aWxkL3dlYg] stored for 27 files
2025-11-23T15:33:58.7005001Z [2025-11-23T15:33:58.700Z] [hosting][hash queue][FINAL] ***"max":1,"min":0,"avg":0,"active":0,"complete":27,"success":27,"errored":0,"retried":0,"total":27,"elapsed":3***
2025-11-23T15:33:58.7010116Z [2025-11-23T15:33:58.700Z] >>> [apiv2][query] POST https://firebasehosting.googleapis.com/v1beta1/projects/***/sites/***/versions/21549fbcc7099369:populateFiles [none]
2025-11-23T15:33:58.7028694Z [2025-11-23T15:33:58.700Z] >>> [apiv2][body] POST https://firebasehosting.googleapis.com/v1beta1/projects/***/sites/***/versions/21549fbcc7099369:populateFiles ***"files":***"/version.json":"a1181f229d638284e52376f77841f22bc6fa0b9b110618195e4c4b3c81cb5cdb","/manifest.json":"4b18456e00038e4d5701c66a5cf4e1ea107f45301830a0779ef66c8ebd542227","/main.dart.js":"e23c252e517d79954ea7c332330c08f388d744ab0eebe853d4816054075b9cf5","/index.html":"830ce5c206e84c3888567f920fe3f3f1220b858d3d56cee87b798d711349867d","/flutter_service_worker.js":"3e7912d0cdfb0098937ca85cca55ea61e9cb44f13d4d6196c1702ff2f14944ad","/flutter_bootstrap.js":"b19a4e5a095e0fbed05e5f9b7365454348442f5a4297ed16237cad397e733cd7","/flutter.js":"33ed4a6b52f177dd6f64da22164d520bd71ca9a117748eb55871b2983aac65a6","/canvaskit/skwasm_heavy.wasm":"a4c00272c65e86d451620535ab7a801b49481f434ad2cce64f12d832e8584b99","/canvaskit/skwasm_heavy.js.symbols":"24c98cf5795a945e15902bf0095f6b89fcc63a76f7da30161bd3a12b05a5ddd4","/canvaskit/skwasm_heavy.js":"99d383b913e2e0a13bd47c7ae5f1dec4d7a741cfdfe99ee2e7f61eaabf1e070b","/canvaskit/skwasm.wasm":"f10a1e7bed7af3c3af7c662c1deea502f60e8521d6a21e1b8197ddb3f7d2c8cb","/canvaskit/skwasm.js.symbols":"926e67e708bc6869376d49be81fd3dd79a7f02398cdfe207ac0d44b68d788fc2","/canvaskit/skwasm.js":"fe13c246393fdec5eac93016a11b0c4b3c36d4de5cf2243d8558bf99eead8a20","/canvaskit/canvaskit.wasm":"34568088f42473989933c4fb2a20ec8ab2098b1b9df0e9462aeba6c7d7050a92","/canvaskit/canvaskit.js.symbols":"9195ca07a8076e3e639d9799af76976464fe1e98333892331f874fb95843efde","/canvaskit/canvaskit.js":"ffda577809d361e736dfd7f13a5a6c72bfd7e9edd047bafab416d65a6fdf0ce4","/canvaskit/chromium/canvaskit.wasm":"139a7f77dbc2b4d034c7e5265b393b55fbaaa1c79ac27b24aeec5fa085be6a90","/canvaskit/chromium/canvaskit.js.symbols":"42c612f77ec02674f6a113f07037422b8f7aaacf8597cc8f6bb39a4333011011","/canvaskit/chromium/canvaskit.js":"f5f9ef1dc6bd45c61bca23bfbaf8d2c7d3c989f4a8c431da5f1bd50ac14b4adf","/assets/NOTICES":"14d8edfb8f500f22598fc7d55d1c466c883569d6a3673c580a6b6a52b6560604","/assets/FontManifest.json":"00798c3c5766cdc753371ca1934749c9fe9b8969de56bc54e9ed1c90b3d669fa","/assets/AssetManifest.bin.json":"6dab3bc22d8651a5fa292a09e03cfd63b9c06be7d92099be1e7c492a94623f6b","/assets/AssetManifest.bin":"8b6072cd7e29821eb7524c128faf9c41e69579e2a2fc8dd76b5140802f2e0de6","/assets/shaders/stretch_effect.frag":"cb21d9b587c211f7214f7c3cfc8e90289591405f8c33ecc5d78de1252965e51c","/assets/shaders/ink_sparkle.frag":"2388003b1d3a03fd5c7281c82ef20645cd6e3c6bb00d493e2351b93ba2ec94c6","/assets/packages/cupertino_icons/assets/CupertinoIcons.ttf":"10aa1f084fa7612decf021fb5a8aefa4a7d2f427d7a02fa778962dd20b814c29","/assets/fonts/MaterialIcons-Regular.otf":"1b1616ba23e636434aae27e3dacddfc92a3690bee29a781b471b81eae9f0719c"***
2025-11-23T15:33:58.8260202Z [2025-11-23T15:33:58.825Z] <<< [apiv2][status] POST https://firebasehosting.googleapis.com/v1beta1/projects/***/sites/***/versions/21549fbcc7099369:populateFiles 200
2025-11-23T15:33:58.8261963Z [2025-11-23T15:33:58.825Z] <<< [apiv2][body] POST https://firebasehosting.googleapis.com/v1beta1/projects/***/sites/***/versions/21549fbcc7099369:populateFiles ***"uploadUrl":"https://upload-firebasehosting.googleapis.com/upload/sites/***/versions/21549fbcc7099369/files"***
2025-11-23T15:33:58.8265087Z [2025-11-23T15:33:58.826Z] [hosting][populate queue][FINAL] ***"max":126,"min":126,"avg":126,"active":0,"complete":1,"success":1,"errored":0,"retried":0,"total":1,"elapsed":127***
2025-11-23T15:33:58.8265792Z [2025-11-23T15:33:58.826Z] [hosting] uploads queued: 0
2025-11-23T15:33:58.8268413Z [2025-11-23T15:33:58.826Z] [hosting][upload queue][FINAL] ***"max":0,"min":9999999999,"avg":0,"active":0,"complete":0,"success":0,"errored":0,"retried":0,"total":0,"elapsed":1763912038826***
2025-11-23T15:33:58.8269496Z i  hosting: upload complete 
2025-11-23T15:33:58.8272609Z ✔  hosting[***]: file upload complete 
2025-11-23T15:33:58.8273302Z [2025-11-23T15:33:58.827Z] [hosting] deploy completed after 143ms
2025-11-23T15:33:58.8275909Z [2025-11-23T15:33:58.827Z] [
2025-11-23T15:33:58.8276557Z   ***
2025-11-23T15:33:58.8276964Z     "config": ***
2025-11-23T15:33:58.8277475Z       "public": "frontend/flutter_neuropilot/build/web",
2025-11-23T15:33:58.8278079Z       "ignore": [
2025-11-23T15:33:58.8278494Z         "firebase.json",
2025-11-23T15:33:58.8278931Z         "**/.*",
2025-11-23T15:33:58.8279347Z         "**/node_modules/**"
2025-11-23T15:33:58.8279798Z       ],
2025-11-23T15:33:58.8280227Z       "headers": [
2025-11-23T15:33:58.8280637Z         ***
2025-11-23T15:33:58.8281040Z           "source": "/index.html",
2025-11-23T15:33:58.8281483Z           "headers": [
2025-11-23T15:33:58.8281745Z             ***
2025-11-23T15:33:58.8282001Z               "key": "Cache-Control",
2025-11-23T15:33:58.8282566Z               "value": "no-cache"
2025-11-23T15:33:58.8293005Z             ***
2025-11-23T15:33:58.8293423Z           ]
2025-11-23T15:33:58.8293814Z         ***,
2025-11-23T15:33:58.8294214Z         ***
2025-11-23T15:33:58.8294621Z           "source": "**/*.js",
2025-11-23T15:33:58.8295095Z           "headers": [
2025-11-23T15:33:58.8295528Z             ***
2025-11-23T15:33:58.8295963Z               "key": "Cache-Control",
2025-11-23T15:33:58.8296848Z               "value": "public, max-age=31536000, immutable"
2025-11-23T15:33:58.8297433Z             ***
2025-11-23T15:33:58.8297836Z           ]
2025-11-23T15:33:58.8298237Z         ***,
2025-11-23T15:33:58.8298561Z         ***
2025-11-23T15:33:58.8298805Z           "source": "**/*.css",
2025-11-23T15:33:58.8299095Z           "headers": [
2025-11-23T15:33:58.8299352Z             ***
2025-11-23T15:33:58.8299668Z               "key": "Cache-Control",
2025-11-23T15:33:58.8300158Z               "value": "public, max-age=31536000, immutable"
2025-11-23T15:33:58.8300517Z             ***
2025-11-23T15:33:58.8300751Z           ]
2025-11-23T15:33:58.8300980Z         ***,
2025-11-23T15:33:58.8301210Z         ***
2025-11-23T15:33:58.8301571Z           "source": "**/*.png",
2025-11-23T15:33:58.8301859Z           "headers": [
2025-11-23T15:33:58.8302116Z             ***
2025-11-23T15:33:58.8302440Z               "key": "Cache-Control",
2025-11-23T15:33:58.8303034Z               "value": "public, max-age=31536000, immutable"
2025-11-23T15:33:58.8303595Z             ***
2025-11-23T15:33:58.8303945Z           ]
2025-11-23T15:33:58.8304176Z         ***,
2025-11-23T15:33:58.8304409Z         ***
2025-11-23T15:33:58.8304712Z           "source": "**/*.jpg",
2025-11-23T15:33:58.8305029Z           "headers": [
2025-11-23T15:33:58.8305296Z             ***
2025-11-23T15:33:58.8305553Z               "key": "Cache-Control",
2025-11-23T15:33:58.8305892Z               "value": "public, max-age=31536000, immutable"
2025-11-23T15:33:58.8306451Z             ***
2025-11-23T15:33:58.8306712Z           ]
2025-11-23T15:33:58.8306942Z         ***,
2025-11-23T15:33:58.8307194Z         ***
2025-11-23T15:33:58.8307446Z           "source": "**/*.svg",
2025-11-23T15:33:58.8307726Z           "headers": [
2025-11-23T15:33:58.8307977Z             ***
2025-11-23T15:33:58.8308231Z               "key": "Cache-Control",
2025-11-23T15:33:58.8308598Z               "value": "public, max-age=31536000, immutable"
2025-11-23T15:33:58.8308930Z             ***
2025-11-23T15:33:58.8309171Z           ]
2025-11-23T15:33:58.8309397Z         ***,
2025-11-23T15:33:58.8309629Z         ***
2025-11-23T15:33:58.8309872Z           "source": "**/*.webp",
2025-11-23T15:33:58.8310152Z           "headers": [
2025-11-23T15:33:58.8310400Z             ***
2025-11-23T15:33:58.8310655Z               "key": "Cache-Control",
2025-11-23T15:33:58.8310981Z               "value": "public, max-age=31536000, immutable"
2025-11-23T15:33:58.8311302Z             ***
2025-11-23T15:33:58.8311535Z           ]
2025-11-23T15:33:58.8311772Z         ***,
2025-11-23T15:33:58.8312004Z         ***
2025-11-23T15:33:58.8312237Z           "source": "**/*.woff2",
2025-11-23T15:33:58.8312518Z           "headers": [
2025-11-23T15:33:58.8312772Z             ***
2025-11-23T15:33:58.8313018Z               "key": "Cache-Control",
2025-11-23T15:33:58.8313342Z               "value": "public, max-age=31536000, immutable"
2025-11-23T15:33:58.8313662Z             ***
2025-11-23T15:33:58.8313897Z           ]
2025-11-23T15:33:58.8314123Z         ***
2025-11-23T15:33:58.8314343Z       ],
2025-11-23T15:33:58.8314571Z       "rewrites": [
2025-11-23T15:33:58.8314823Z         ***
2025-11-23T15:33:58.8315063Z           "source": "/api/**",
2025-11-23T15:33:58.8315343Z           "run": ***
2025-11-23T15:33:58.8315625Z             "serviceId": "neuropilot-api",
2025-11-23T15:33:58.8315985Z             "region": "australia-southeast1"
2025-11-23T15:33:58.8316459Z           ***
2025-11-23T15:33:58.8316717Z         ***,
2025-11-23T15:33:58.8317143Z         ***
2025-11-23T15:33:58.8317380Z           "source": "**",
2025-11-23T15:33:58.8317666Z           "destination": "/index.html"
2025-11-23T15:33:58.8317963Z         ***
2025-11-23T15:33:58.8318183Z       ],
2025-11-23T15:33:58.8318442Z       "site": "***"
2025-11-23T15:33:58.8318689Z     ***,
2025-11-23T15:33:58.8319084Z     "version": "projects/***/sites/***/versions/21549fbcc7099369"
2025-11-23T15:33:58.8319453Z   ***
2025-11-23T15:33:58.8319676Z ]
2025-11-23T15:33:58.8320076Z i  hosting[***]: finalizing version... 
2025-11-23T15:33:58.8320431Z [2025-11-23T15:33:58.828Z] No OAuth tokens found
2025-11-23T15:33:58.8321114Z [2025-11-23T15:33:58.828Z] >>> [apiv2][query] GET https://cloudfunctions.googleapis.com/v1/projects/***/locations/-/functions [none]
2025-11-23T15:33:58.9605317Z [2025-11-23T15:33:58.960Z] <<< [apiv2][status] GET https://cloudfunctions.googleapis.com/v1/projects/***/locations/-/functions 403
2025-11-23T15:33:58.9616520Z [2025-11-23T15:33:58.960Z] <<< [apiv2][body] GET https://cloudfunctions.googleapis.com/v1/projects/***/locations/-/functions ***"error":***"code":403,"message":"Cloud Functions API has not been used in project *** before or it is disabled. Enable it by visiting https://console.developers.google.com/apis/api/cloudfunctions.googleapis.com/overview?project=*** then retry. If you enabled this API recently, wait a few minutes for the action to propagate to our systems and retry.","status":"PERMISSION_DENIED","details":[***"@type":"type.googleapis.com/google.rpc.ErrorInfo","reason":"SERVICE_DISABLED","domain":"googleapis.com","metadata":***"consumer":"projects/***","service":"cloudfunctions.googleapis.com","containerInfo":"***","activationUrl":"https://console.developers.google.com/apis/api/cloudfunctions.googleapis.com/overview?project=***","serviceTitle":"Cloud Functions API"***,***"@type":"type.googleapis.com/google.rpc.LocalizedMessage","locale":"en-US","message":"Cloud Functions API has not been used in project *** before or it is disabled. Enable it by visiting https://console.developers.google.com/apis/api/cloudfunctions.googleapis.com/overview?project=*** then retry. If you enabled this API recently, wait a few minutes for the action to propagate to our systems and retry."***,***"@type":"type.googleapis.com/google.rpc.Help","links":[***"description":"Google developers console API activation","url":"https://console.developers.google.com/apis/api/cloudfunctions.googleapis.com/overview?project=***"***]***]***
2025-11-23T15:33:58.9623436Z [2025-11-23T15:33:58.960Z] [functions] failed to list functions for ***
2025-11-23T15:33:58.9625887Z [2025-11-23T15:33:58.960Z] [functions] Request to https://cloudfunctions.googleapis.com/v1/projects/***/locations/-/functions had HTTP Error: 403, Cloud Functions API has not been used in project *** before or it is disabled. Enable it by visiting https://console.developers.google.com/apis/api/cloudfunctions.googleapis.com/overview?project=*** then retry. If you enabled this API recently, wait a few minutes for the action to propagate to our systems and retry.
2025-11-23T15:33:58.9636685Z [2025-11-23T15:33:58.960Z] Deploying hosting site ***, did not have permissions to check for backends:  Failed to list functions for *** ***"name":"FirebaseError","children":[],"exit":1,"message":"Failed to list functions for ***","original":***"name":"FirebaseError","children":[],"context":***"body":***"error":***"code":403,"message":"Cloud Functions API has not been used in project *** before or it is disabled. Enable it by visiting https://console.developers.google.com/apis/api/cloudfunctions.googleapis.com/overview?project=*** then retry. If you enabled this API recently, wait a few minutes for the action to propagate to our systems and retry.","status":"PERMISSION_DENIED","details":[***"@type":"type.googleapis.com/google.rpc.ErrorInfo","reason":"SERVICE_DISABLED","domain":"googleapis.com","metadata":***"consumer":"projects/***","service":"cloudfunctions.googleapis.com","containerInfo":"***","activationUrl":"https://console.developers.google.com/apis/api/cloudfunctions.googleapis.com/overview?project=***","serviceTitle":"Cloud Functions API"***,***"@type":"type.googleapis.com/google.rpc.LocalizedMessage","locale":"en-US","message":"Cloud Functions API has not been used in project *** before or it is disabled. Enable it by visiting https://console.developers.google.com/apis/api/cloudfunctions.googleapis.com/overview?project=*** then retry. If you enabled this API recently, wait a few minutes for the action to propagate to our systems and retry."***,***"@type":"type.googleapis.com/google.rpc.Help","links":[***"description":"Google developers console API activation","url":"https://console.developers.google.com/apis/api/cloudfunctions.googleapis.com/overview?project=***"***]***]***,"response":***"statusCode":403***,"exit":1,"message":"Request to https://cloudfunctions.googleapis.com/v1/projects/***/locations/-/functions had HTTP Error: 403, Cloud Functions API has not been used in project *** before or it is disabled. Enable it by visiting https://console.developers.google.com/apis/api/cloudfunctions.googleapis.com/overview?project=*** then retry. If you enabled this API recently, wait a few minutes for the action to propagate to our systems and retry.","status":403***,"status":403***
2025-11-23T15:33:58.9643788Z [2025-11-23T15:33:58.962Z] No OAuth tokens found
2025-11-23T15:33:58.9644611Z [2025-11-23T15:33:58.962Z] >>> [apiv2][query] PATCH https://firebasehosting.googleapis.com/v1beta1/projects/-/sites/***/versions/21549fbcc7099369 updateMask=status%2Cconfig
2025-11-23T15:33:58.9648076Z [2025-11-23T15:33:58.962Z] >>> [apiv2][body] PATCH https://firebasehosting.googleapis.com/v1beta1/projects/-/sites/***/versions/21549fbcc7099369 ***"status":"FINALIZED","config":***"rewrites":[***"glob":"/api/**","run":***"serviceId":"neuropilot-api","region":"australia-southeast1"***,***"glob":"**","path":"/index.html"***],"headers":[***"glob":"/index.html","headers":***"Cache-Control":"no-cache"***,***"glob":"**/*.js","headers":***"Cache-Control":"public, max-age=31536000, immutable"***,***"glob":"**/*.css","headers":***"Cache-Control":"public, max-age=31536000, immutable"***,***"glob":"**/*.png","headers":***"Cache-Control":"public, max-age=31536000, immutable"***,***"glob":"**/*.jpg","headers":***"Cache-Control":"public, max-age=31536000, immutable"***,***"glob":"**/*.svg","headers":***"Cache-Control":"public, max-age=31536000, immutable"***,***"glob":"**/*.webp","headers":***"Cache-Control":"public, max-age=31536000, immutable"***,***"glob":"**/*.woff2","headers":***"Cache-Control":"public, max-age=31536000, immutable"***]***
2025-11-23T15:33:59.4596609Z [2025-11-23T15:33:59.459Z] <<< [apiv2][status] PATCH https://firebasehosting.googleapis.com/v1beta1/projects/-/sites/***/versions/21549fbcc7099369 400
2025-11-23T15:33:59.4599047Z [2025-11-23T15:33:59.459Z] <<< [apiv2][body] PATCH https://firebasehosting.googleapis.com/v1beta1/projects/-/sites/***/versions/21549fbcc7099369 ***"error":***"code":400,"message":"Cloud Run service `neuropilot-api` does not exist in region `australia-southeast1` in this project.","status":"INVALID_ARGUMENT"***
2025-11-23T15:33:59.4602625Z 
2025-11-23T15:33:59.4605824Z Error: Request to https://firebasehosting.googleapis.com/v1beta1/projects/-/sites/***/versions/21549fbcc7099369?updateMask=status%2Cconfig had HTTP Error: 400, Cloud Run service `neuropilot-api` does not exist in region `australia-southeast1` in this project.
2025-11-23T15:33:59.4607778Z [2025-11-23T15:33:59.460Z] Error Context: ***
2025-11-23T15:33:59.4608213Z   "body": ***
2025-11-23T15:33:59.4608544Z     "error": ***
2025-11-23T15:33:59.4608871Z       "code": 400,
2025-11-23T15:33:59.4609529Z       "message": "Cloud Run service `neuropilot-api` does not exist in region `australia-southeast1` in this project.",
2025-11-23T15:33:59.4610256Z       "status": "INVALID_ARGUMENT"
2025-11-23T15:33:59.4610637Z     ***
2025-11-23T15:33:59.4610936Z   ***,
2025-11-23T15:33:59.4611235Z   "response": ***
2025-11-23T15:33:59.4611572Z     "statusCode": 400
2025-11-23T15:33:59.4611919Z   ***
2025-11-23T15:33:59.4612403Z ***
2025-11-23T15:33:59.7525730Z [2025-11-23T15:33:57.938Z] > command requires scopes: ["email","openid","https://www.googleapis.com/auth/cloudplatformprojects.readonly","https://www.googleapis.com/auth/firebase","https://www.googleapis.com/auth/cloud-platform"]
2025-11-23T15:33:59.7527652Z [2025-11-23T15:33:58.056Z] Running auto auth
2025-11-23T15:33:59.7529195Z [2025-11-23T15:33:58.057Z] [iam] checking project *** for permissions ["firebase.projects.get","firebasehosting.sites.update"]
2025-11-23T15:33:59.7530242Z [2025-11-23T15:33:58.058Z] No OAuth tokens found
2025-11-23T15:33:59.7531445Z [2025-11-23T15:33:58.059Z] >>> [apiv2][query] POST https://cloudresourcemanager.googleapis.com/v1/projects/***:testIamPermissions [none]
2025-11-23T15:33:59.7533071Z [2025-11-23T15:33:58.059Z] >>> [apiv2][(partial)header] POST https://cloudresourcemanager.googleapis.com/v1/projects/***:testIamPermissions x-goog-quota-user=projects/***
2025-11-23T15:33:59.7534412Z [2025-11-23T15:33:58.059Z] >>> [apiv2][body] POST https://cloudresourcemanager.googleapis.com/v1/projects/***:testIamPermissions ***"permissions":["firebase.projects.get","firebasehosting.sites.update"]***
2025-11-23T15:33:59.7535580Z [2025-11-23T15:33:58.165Z] <<< [apiv2][status] POST https://cloudresourcemanager.googleapis.com/v1/projects/***:testIamPermissions 200
2025-11-23T15:33:59.7537052Z [2025-11-23T15:33:58.165Z] <<< [apiv2][body] POST https://cloudresourcemanager.googleapis.com/v1/projects/***:testIamPermissions ***"permissions":["firebase.projects.get","firebasehosting.sites.update"]***
2025-11-23T15:33:59.7537902Z [2025-11-23T15:33:58.166Z] No OAuth tokens found
2025-11-23T15:33:59.7538473Z [2025-11-23T15:33:58.166Z] >>> [apiv2][query] GET https://firebase.googleapis.com/v1beta1/projects/*** [none]
2025-11-23T15:33:59.7539172Z [2025-11-23T15:33:58.349Z] <<< [apiv2][status] GET https://firebase.googleapis.com/v1beta1/projects/*** 200
2025-11-23T15:33:59.7540601Z [2025-11-23T15:33:58.350Z] <<< [apiv2][body] GET https://firebase.googleapis.com/v1beta1/projects/*** ***"projectId":"***","projectNumber":"***","displayName":"NeuroPilot","name":"projects/***","resources":***"hostingSite":"***"***,"state":"ACTIVE","etag":"1_577118ab-92fe-4772-99e2-7deda2bead55"***
2025-11-23T15:33:59.7541469Z 
2025-11-23T15:33:59.7541616Z === Deploying to '***'...
2025-11-23T15:33:59.7541794Z 
2025-11-23T15:33:59.7541906Z i  deploying hosting 
2025-11-23T15:33:59.7542203Z [2025-11-23T15:33:58.353Z] No OAuth tokens found
2025-11-23T15:33:59.7542874Z [2025-11-23T15:33:58.353Z] >>> [apiv2][query] POST https://firebasehosting.googleapis.com/v1beta1/projects/-/sites/***/versions [none]
2025-11-23T15:33:59.7544044Z [2025-11-23T15:33:58.353Z] >>> [apiv2][body] POST https://firebasehosting.googleapis.com/v1beta1/projects/-/sites/***/versions ***"status":"CREATED","labels":***"deployment-tool":"cli-firebase--action-hosting-deploy"***
2025-11-23T15:33:59.7545448Z [2025-11-23T15:33:58.682Z] <<< [apiv2][status] POST https://firebasehosting.googleapis.com/v1beta1/projects/-/sites/***/versions 200
2025-11-23T15:33:59.7547204Z [2025-11-23T15:33:58.682Z] <<< [apiv2][body] POST https://firebasehosting.googleapis.com/v1beta1/projects/-/sites/***/versions ***"name":"projects/***/sites/***/versions/21549fbcc7099369","status":"CREATED","config":***,"labels":***"deployment-tool":"cli-firebase--action-hosting-deploy"***
2025-11-23T15:33:59.7548313Z i  hosting[***]: beginning deploy... 
2025-11-23T15:33:59.7548784Z i  hosting[***]: found 27 files in frontend/flutter_neuropilot/build/web 
2025-11-23T15:33:59.7549261Z [2025-11-23T15:33:58.696Z] [hosting] uploading with 200 concurrency
2025-11-23T15:33:59.7549660Z [2025-11-23T15:33:58.699Z] No OAuth tokens found
2025-11-23T15:33:59.7550240Z [2025-11-23T15:33:58.699Z] [hosting] hash cache [ZnJvbnRlbmQvZmx1dHRlcl9uZXVyb3BpbG90L2J1aWxkL3dlYg] stored for 27 files
2025-11-23T15:33:59.7551128Z [2025-11-23T15:33:58.700Z] [hosting][hash queue][FINAL] ***"max":1,"min":0,"avg":0,"active":0,"complete":27,"success":27,"errored":0,"retried":0,"total":27,"elapsed":3***
2025-11-23T15:33:59.7552437Z [2025-11-23T15:33:58.700Z] >>> [apiv2][query] POST https://firebasehosting.googleapis.com/v1beta1/projects/***/sites/***/versions/21549fbcc7099369:populateFiles [none]
2025-11-23T15:33:59.7563546Z [2025-11-23T15:33:58.700Z] >>> [apiv2][body] POST https://firebasehosting.googleapis.com/v1beta1/projects/***/sites/***/versions/21549fbcc7099369:populateFiles ***"files":***"/version.json":"a1181f229d638284e52376f77841f22bc6fa0b9b110618195e4c4b3c81cb5cdb","/manifest.json":"4b18456e00038e4d5701c66a5cf4e1ea107f45301830a0779ef66c8ebd542227","/main.dart.js":"e23c252e517d79954ea7c332330c08f388d744ab0eebe853d4816054075b9cf5","/index.html":"830ce5c206e84c3888567f920fe3f3f1220b858d3d56cee87b798d711349867d","/flutter_service_worker.js":"3e7912d0cdfb0098937ca85cca55ea61e9cb44f13d4d6196c1702ff2f14944ad","/flutter_bootstrap.js":"b19a4e5a095e0fbed05e5f9b7365454348442f5a4297ed16237cad397e733cd7","/flutter.js":"33ed4a6b52f177dd6f64da22164d520bd71ca9a117748eb55871b2983aac65a6","/canvaskit/skwasm_heavy.wasm":"a4c00272c65e86d451620535ab7a801b49481f434ad2cce64f12d832e8584b99","/canvaskit/skwasm_heavy.js.symbols":"24c98cf5795a945e15902bf0095f6b89fcc63a76f7da30161bd3a12b05a5ddd4","/canvaskit/skwasm_heavy.js":"99d383b913e2e0a13bd47c7ae5f1dec4d7a741cfdfe99ee2e7f61eaabf1e070b","/canvaskit/skwasm.wasm":"f10a1e7bed7af3c3af7c662c1deea502f60e8521d6a21e1b8197ddb3f7d2c8cb","/canvaskit/skwasm.js.symbols":"926e67e708bc6869376d49be81fd3dd79a7f02398cdfe207ac0d44b68d788fc2","/canvaskit/skwasm.js":"fe13c246393fdec5eac93016a11b0c4b3c36d4de5cf2243d8558bf99eead8a20","/canvaskit/canvaskit.wasm":"34568088f42473989933c4fb2a20ec8ab2098b1b9df0e9462aeba6c7d7050a92","/canvaskit/canvaskit.js.symbols":"9195ca07a8076e3e639d9799af76976464fe1e98333892331f874fb95843efde","/canvaskit/canvaskit.js":"ffda577809d361e736dfd7f13a5a6c72bfd7e9edd047bafab416d65a6fdf0ce4","/canvaskit/chromium/canvaskit.wasm":"139a7f77dbc2b4d034c7e5265b393b55fbaaa1c79ac27b24aeec5fa085be6a90","/canvaskit/chromium/canvaskit.js.symbols":"42c612f77ec02674f6a113f07037422b8f7aaacf8597cc8f6bb39a4333011011","/canvaskit/chromium/canvaskit.js":"f5f9ef1dc6bd45c61bca23bfbaf8d2c7d3c989f4a8c431da5f1bd50ac14b4adf","/assets/NOTICES":"14d8edfb8f500f22598fc7d55d1c466c883569d6a3673c580a6b6a52b6560604","/assets/FontManifest.json":"00798c3c5766cdc753371ca1934749c9fe9b8969de56bc54e9ed1c90b3d669fa","/assets/AssetManifest.bin.json":"6dab3bc22d8651a5fa292a09e03cfd63b9c06be7d92099be1e7c492a94623f6b","/assets/AssetManifest.bin":"8b6072cd7e29821eb7524c128faf9c41e69579e2a2fc8dd76b5140802f2e0de6","/assets/shaders/stretch_effect.frag":"cb21d9b587c211f7214f7c3cfc8e90289591405f8c33ecc5d78de1252965e51c","/assets/shaders/ink_sparkle.frag":"2388003b1d3a03fd5c7281c82ef20645cd6e3c6bb00d493e2351b93ba2ec94c6","/assets/packages/cupertino_icons/assets/CupertinoIcons.ttf":"10aa1f084fa7612decf021fb5a8aefa4a7d2f427d7a02fa778962dd20b814c29","/assets/fonts/MaterialIcons-Regular.otf":"1b1616ba23e636434aae27e3dacddfc92a3690bee29a781b471b81eae9f0719c"***
2025-11-23T15:33:59.7575501Z [2025-11-23T15:33:58.825Z] <<< [apiv2][status] POST https://firebasehosting.googleapis.com/v1beta1/projects/***/sites/***/versions/21549fbcc7099369:populateFiles 200
2025-11-23T15:33:59.7579550Z [2025-11-23T15:33:58.825Z] <<< [apiv2][body] POST https://firebasehosting.googleapis.com/v1beta1/projects/***/sites/***/versions/21549fbcc7099369:populateFiles ***"uploadUrl":"https://upload-firebasehosting.googleapis.com/upload/sites/***/versions/21549fbcc7099369/files"***
2025-11-23T15:33:59.7580989Z [2025-11-23T15:33:58.826Z] [hosting][populate queue][FINAL] ***"max":126,"min":126,"avg":126,"active":0,"complete":1,"success":1,"errored":0,"retried":0,"total":1,"elapsed":127***
2025-11-23T15:33:59.7581675Z [2025-11-23T15:33:58.826Z] [hosting] uploads queued: 0
2025-11-23T15:33:59.7582376Z [2025-11-23T15:33:58.826Z] [hosting][upload queue][FINAL] ***"max":0,"min":9999999999,"avg":0,"active":0,"complete":0,"success":0,"errored":0,"retried":0,"total":0,"elapsed":1763912038826***
2025-11-23T15:33:59.7583050Z i  hosting: upload complete 
2025-11-23T15:33:59.7583837Z ✔  hosting[***]: file upload complete 
2025-11-23T15:33:59.7584232Z [2025-11-23T15:33:58.827Z] [hosting] deploy completed after 143ms
2025-11-23T15:33:59.7584613Z [2025-11-23T15:33:58.827Z] [
2025-11-23T15:33:59.7584892Z   ***
2025-11-23T15:33:59.7585125Z     "config": ***
2025-11-23T15:33:59.7585430Z       "public": "frontend/flutter_neuropilot/build/web",
2025-11-23T15:33:59.7585775Z       "ignore": [
2025-11-23T15:33:59.7586028Z         "firebase.json",
2025-11-23T15:33:59.7586697Z         "**/.*",
2025-11-23T15:33:59.7586973Z         "**/node_modules/**"
2025-11-23T15:33:59.7587244Z       ],
2025-11-23T15:33:59.7587477Z       "headers": [
2025-11-23T15:33:59.7587730Z         ***
2025-11-23T15:33:59.7587977Z           "source": "/index.html",
2025-11-23T15:33:59.7588269Z           "headers": [
2025-11-23T15:33:59.7588532Z             ***
2025-11-23T15:33:59.7588794Z               "key": "Cache-Control",
2025-11-23T15:33:59.7589260Z               "value": "no-cache"
2025-11-23T15:33:59.7589756Z             ***
2025-11-23T15:33:59.7590162Z           ]
2025-11-23T15:33:59.7590537Z         ***,
2025-11-23T15:33:59.7590915Z         ***
2025-11-23T15:33:59.7591241Z           "source": "**/*.js",
2025-11-23T15:33:59.7591527Z           "headers": [
2025-11-23T15:33:59.7591781Z             ***
2025-11-23T15:33:59.7592036Z               "key": "Cache-Control",
2025-11-23T15:33:59.7592380Z               "value": "public, max-age=31536000, immutable"
2025-11-23T15:33:59.7592717Z             ***
2025-11-23T15:33:59.7593098Z           ]
2025-11-23T15:33:59.7593437Z         ***,
2025-11-23T15:33:59.7593669Z         ***
2025-11-23T15:33:59.7593990Z           "source": "**/*.css",
2025-11-23T15:33:59.7594271Z           "headers": [
2025-11-23T15:33:59.7594523Z             ***
2025-11-23T15:33:59.7594776Z               "key": "Cache-Control",
2025-11-23T15:33:59.7595152Z               "value": "public, max-age=31536000, immutable"
2025-11-23T15:33:59.7595483Z             ***
2025-11-23T15:33:59.7595722Z           ]
2025-11-23T15:33:59.7595958Z         ***,
2025-11-23T15:33:59.7596366Z         ***
2025-11-23T15:33:59.7596629Z           "source": "**/*.png",
2025-11-23T15:33:59.7596914Z           "headers": [
2025-11-23T15:33:59.7597170Z             ***
2025-11-23T15:33:59.7597431Z               "key": "Cache-Control",
2025-11-23T15:33:59.7597776Z               "value": "public, max-age=31536000, immutable"
2025-11-23T15:33:59.7598101Z             ***
2025-11-23T15:33:59.7598330Z           ]
2025-11-23T15:33:59.7598564Z         ***,
2025-11-23T15:33:59.7598794Z         ***
2025-11-23T15:33:59.7599028Z           "source": "**/*.jpg",
2025-11-23T15:33:59.7599303Z           "headers": [
2025-11-23T15:33:59.7599560Z             ***
2025-11-23T15:33:59.7599810Z               "key": "Cache-Control",
2025-11-23T15:33:59.7600138Z               "value": "public, max-age=31536000, immutable"
2025-11-23T15:33:59.7600460Z             ***
2025-11-23T15:33:59.7600694Z           ]
2025-11-23T15:33:59.7600918Z         ***,
2025-11-23T15:33:59.7601156Z         ***
2025-11-23T15:33:59.7601402Z           "source": "**/*.svg",
2025-11-23T15:33:59.7601692Z           "headers": [
2025-11-23T15:33:59.7601952Z             ***
2025-11-23T15:33:59.7602214Z               "key": "Cache-Control",
2025-11-23T15:33:59.7602558Z               "value": "public, max-age=31536000, immutable"
2025-11-23T15:33:59.7602895Z             ***
2025-11-23T15:33:59.7603129Z           ]
2025-11-23T15:33:59.7603359Z         ***,
2025-11-23T15:33:59.7603596Z         ***
2025-11-23T15:33:59.7603842Z           "source": "**/*.webp",
2025-11-23T15:33:59.7604126Z           "headers": [
2025-11-23T15:33:59.7604400Z             ***
2025-11-23T15:33:59.7604665Z               "key": "Cache-Control",
2025-11-23T15:33:59.7605010Z               "value": "public, max-age=31536000, immutable"
2025-11-23T15:33:59.7605345Z             ***
2025-11-23T15:33:59.7605581Z           ]
2025-11-23T15:33:59.7605813Z         ***,
2025-11-23T15:33:59.7606044Z         ***
2025-11-23T15:33:59.7606457Z           "source": "**/*.woff2",
2025-11-23T15:33:59.7606915Z           "headers": [
2025-11-23T15:33:59.7607178Z             ***
2025-11-23T15:33:59.7607429Z               "key": "Cache-Control",
2025-11-23T15:33:59.7607761Z               "value": "public, max-age=31536000, immutable"
2025-11-23T15:33:59.7608085Z             ***
2025-11-23T15:33:59.7608317Z           ]
2025-11-23T15:33:59.7608539Z         ***
2025-11-23T15:33:59.7608757Z       ],
2025-11-23T15:33:59.7609095Z       "rewrites": [
2025-11-23T15:33:59.7609353Z         ***
2025-11-23T15:33:59.7609592Z           "source": "/api/**",
2025-11-23T15:33:59.7609874Z           "run": ***
2025-11-23T15:33:59.7610151Z             "serviceId": "neuropilot-api",
2025-11-23T15:33:59.7610494Z             "region": "australia-southeast1"
2025-11-23T15:33:59.7610805Z           ***
2025-11-23T15:33:59.7611038Z         ***,
2025-11-23T15:33:59.7611266Z         ***
2025-11-23T15:33:59.7611501Z           "source": "**",
2025-11-23T15:33:59.7611806Z           "destination": "/index.html"
2025-11-23T15:33:59.7612122Z         ***
2025-11-23T15:33:59.7612343Z       ],
2025-11-23T15:33:59.7612595Z       "site": "***"
2025-11-23T15:33:59.7612847Z     ***,
2025-11-23T15:33:59.7613247Z     "version": "projects/***/sites/***/versions/21549fbcc7099369"
2025-11-23T15:33:59.7613611Z   ***
2025-11-23T15:33:59.7613835Z ]
2025-11-23T15:33:59.7614125Z i  hosting[***]: finalizing version... 
2025-11-23T15:33:59.7614468Z [2025-11-23T15:33:58.828Z] No OAuth tokens found
2025-11-23T15:33:59.7615137Z [2025-11-23T15:33:58.828Z] >>> [apiv2][query] GET https://cloudfunctions.googleapis.com/v1/projects/***/locations/-/functions [none]
2025-11-23T15:33:59.7616023Z [2025-11-23T15:33:58.960Z] <<< [apiv2][status] GET https://cloudfunctions.googleapis.com/v1/projects/***/locations/-/functions 403
2025-11-23T15:33:59.7622186Z [2025-11-23T15:33:58.960Z] <<< [apiv2][body] GET https://cloudfunctions.googleapis.com/v1/projects/***/locations/-/functions ***"error":***"code":403,"message":"Cloud Functions API has not been used in project *** before or it is disabled. Enable it by visiting https://console.developers.google.com/apis/api/cloudfunctions.googleapis.com/overview?project=*** then retry. If you enabled this API recently, wait a few minutes for the action to propagate to our systems and retry.","status":"PERMISSION_DENIED","details":[***"@type":"type.googleapis.com/google.rpc.ErrorInfo","reason":"SERVICE_DISABLED","domain":"googleapis.com","metadata":***"consumer":"projects/***","service":"cloudfunctions.googleapis.com","containerInfo":"***","activationUrl":"https://console.developers.google.com/apis/api/cloudfunctions.googleapis.com/overview?project=***","serviceTitle":"Cloud Functions API"***,***"@type":"type.googleapis.com/google.rpc.LocalizedMessage","locale":"en-US","message":"Cloud Functions API has not been used in project *** before or it is disabled. Enable it by visiting https://console.developers.google.com/apis/api/cloudfunctions.googleapis.com/overview?project=*** then retry. If you enabled this API recently, wait a few minutes for the action to propagate to our systems and retry."***,***"@type":"type.googleapis.com/google.rpc.Help","links":[***"description":"Google developers console API activation","url":"https://console.developers.google.com/apis/api/cloudfunctions.googleapis.com/overview?project=***"***]***]***
2025-11-23T15:33:59.7627654Z [2025-11-23T15:33:58.960Z] [functions] failed to list functions for ***
2025-11-23T15:33:59.7629545Z [2025-11-23T15:33:58.960Z] [functions] Request to https://cloudfunctions.googleapis.com/v1/projects/***/locations/-/functions had HTTP Error: 403, Cloud Functions API has not been used in project *** before or it is disabled. Enable it by visiting https://console.developers.google.com/apis/api/cloudfunctions.googleapis.com/overview?project=*** then retry. If you enabled this API recently, wait a few minutes for the action to propagate to our systems and retry.
2025-11-23T15:33:59.7638701Z [2025-11-23T15:33:58.960Z] Deploying hosting site ***, did not have permissions to check for backends:  Failed to list functions for *** ***"name":"FirebaseError","children":[],"exit":1,"message":"Failed to list functions for ***","original":***"name":"FirebaseError","children":[],"context":***"body":***"error":***"code":403,"message":"Cloud Functions API has not been used in project *** before or it is disabled. Enable it by visiting https://console.developers.google.com/apis/api/cloudfunctions.googleapis.com/overview?project=*** then retry. If you enabled this API recently, wait a few minutes for the action to propagate to our systems and retry.","status":"PERMISSION_DENIED","details":[***"@type":"type.googleapis.com/google.rpc.ErrorInfo","reason":"SERVICE_DISABLED","domain":"googleapis.com","metadata":***"consumer":"projects/***","service":"cloudfunctions.googleapis.com","containerInfo":"***","activationUrl":"https://console.developers.google.com/apis/api/cloudfunctions.googleapis.com/overview?project=***","serviceTitle":"Cloud Functions API"***,***"@type":"type.googleapis.com/google.rpc.LocalizedMessage","locale":"en-US","message":"Cloud Functions API has not been used in project *** before or it is disabled. Enable it by visiting https://console.developers.google.com/apis/api/cloudfunctions.googleapis.com/overview?project=*** then retry. If you enabled this API recently, wait a few minutes for the action to propagate to our systems and retry."***,***"@type":"type.googleapis.com/google.rpc.Help","links":[***"description":"Google developers console API activation","url":"https://console.developers.google.com/apis/api/cloudfunctions.googleapis.com/overview?project=***"***]***]***,"response":***"statusCode":403***,"exit":1,"message":"Request to https://cloudfunctions.googleapis.com/v1/projects/***/locations/-/functions had HTTP Error: 403, Cloud Functions API has not been used in project *** before or it is disabled. Enable it by visiting https://console.developers.google.com/apis/api/cloudfunctions.googleapis.com/overview?project=*** then retry. If you enabled this API recently, wait a few minutes for the action to propagate to our systems and retry.","status":403***,"status":403***
2025-11-23T15:33:59.7645645Z [2025-11-23T15:33:58.962Z] No OAuth tokens found
2025-11-23T15:33:59.7646577Z [2025-11-23T15:33:58.962Z] >>> [apiv2][query] PATCH https://firebasehosting.googleapis.com/v1beta1/projects/-/sites/***/versions/21549fbcc7099369 updateMask=status%2Cconfig
2025-11-23T15:33:59.7649873Z [2025-11-23T15:33:58.962Z] >>> [apiv2][body] PATCH https://firebasehosting.googleapis.com/v1beta1/projects/-/sites/***/versions/21549fbcc7099369 ***"status":"FINALIZED","config":***"rewrites":[***"glob":"/api/**","run":***"serviceId":"neuropilot-api","region":"australia-southeast1"***,***"glob":"**","path":"/index.html"***],"headers":[***"glob":"/index.html","headers":***"Cache-Control":"no-cache"***,***"glob":"**/*.js","headers":***"Cache-Control":"public, max-age=31536000, immutable"***,***"glob":"**/*.css","headers":***"Cache-Control":"public, max-age=31536000, immutable"***,***"glob":"**/*.png","headers":***"Cache-Control":"public, max-age=31536000, immutable"***,***"glob":"**/*.jpg","headers":***"Cache-Control":"public, max-age=31536000, immutable"***,***"glob":"**/*.svg","headers":***"Cache-Control":"public, max-age=31536000, immutable"***,***"glob":"**/*.webp","headers":***"Cache-Control":"public, max-age=31536000, immutable"***,***"glob":"**/*.woff2","headers":***"Cache-Control":"public, max-age=31536000, immutable"***]***
2025-11-23T15:33:59.7653188Z [2025-11-23T15:33:59.459Z] <<< [apiv2][status] PATCH https://firebasehosting.googleapis.com/v1beta1/projects/-/sites/***/versions/21549fbcc7099369 400
2025-11-23T15:33:59.7654674Z [2025-11-23T15:33:59.459Z] <<< [apiv2][body] PATCH https://firebasehosting.googleapis.com/v1beta1/projects/-/sites/***/versions/21549fbcc7099369 ***"error":***"code":400,"message":"Cloud Run service `neuropilot-api` does not exist in region `australia-southeast1` in this project.","status":"INVALID_ARGUMENT"***
2025-11-23T15:33:59.7655652Z 
2025-11-23T15:33:59.7656626Z Error: Request to https://firebasehosting.googleapis.com/v1beta1/projects/-/sites/***/versions/21549fbcc7099369?updateMask=status%2Cconfig had HTTP Error: 400, Cloud Run service `neuropilot-api` does not exist in region `australia-southeast1` in this project.
2025-11-23T15:33:59.7658031Z [2025-11-23T15:33:59.460Z] Error Context: ***
2025-11-23T15:33:59.7658355Z   "body": ***
2025-11-23T15:33:59.7658599Z     "error": ***
2025-11-23T15:33:59.7658854Z       "code": 400,
2025-11-23T15:33:59.7659465Z       "message": "Cloud Run service `neuropilot-api` does not exist in region `australia-southeast1` in this project.",
2025-11-23T15:33:59.7660009Z       "status": "INVALID_ARGUMENT"
2025-11-23T15:33:59.7660302Z     ***
2025-11-23T15:33:59.7660539Z   ***,
2025-11-23T15:33:59.7660769Z   "response": ***
2025-11-23T15:33:59.7661030Z     "statusCode": 400
2025-11-23T15:33:59.7661295Z   ***
2025-11-23T15:33:59.7661521Z ***
2025-11-23T15:33:59.7661645Z 
2025-11-23T15:33:59.7661816Z The process '/usr/local/bin/npx' failed with exit code 1
2025-11-23T15:33:59.7678690Z ##[error]The process '/usr/local/bin/npx' failed with exit code 1
2025-11-23T15:33:59.7684960Z ***
2025-11-23T15:33:59.7685238Z   conclusion: 'failure',
2025-11-23T15:33:59.7685542Z   output: ***
2025-11-23T15:33:59.7685823Z     title: 'Deploy preview failed',
2025-11-23T15:33:59.7686436Z     summary: "Error: The process '/usr/local/bin/npx' failed with exit code 1"
2025-11-23T15:33:59.7686858Z   ***
2025-11-23T15:33:59.7687083Z ***
2025-11-23T15:33:59.7804811Z Post job cleanup.
2025-11-23T15:33:59.7869067Z Post job cleanup.
2025-11-23T15:33:59.8807057Z [command]/usr/bin/git version
2025-11-23T15:33:59.8842757Z git version 2.51.2
2025-11-23T15:33:59.8884650Z Temporarily overriding HOME='/home/runner/work/_temp/acf880ee-ad68-423a-9141-a88acac63041' before making global git config changes
2025-11-23T15:33:59.8885889Z Adding repository directory to the temporary git global config as a safe directory
2025-11-23T15:33:59.8897183Z [command]/usr/bin/git config --global --add safe.directory /home/runner/work/alterred/alterred
2025-11-23T15:33:59.8930434Z [command]/usr/bin/git config --local --name-only --get-regexp core\.sshCommand
2025-11-23T15:33:59.8961631Z [command]/usr/bin/git submodule foreach --recursive sh -c "git config --local --name-only --get-regexp 'core\.sshCommand' && git config --local --unset-all 'core.sshCommand' || :"
2025-11-23T15:33:59.9187310Z [command]/usr/bin/git config --local --name-only --get-regexp http\.https\:\/\/github\.com\/\.extraheader
2025-11-23T15:33:59.9207638Z http.https://github.com/.extraheader
2025-11-23T15:33:59.9220273Z [command]/usr/bin/git config --local --unset-all http.https://github.com/.extraheader
2025-11-23T15:33:59.9250338Z [command]/usr/bin/git submodule foreach --recursive sh -c "git config --local --name-only --get-regexp 'http\.https\:\/\/github\.com\/\.extraheader' && git config --local --unset-all 'http.https://github.com/.extraheader' || :"
2025-11-23T15:33:59.9469159Z [command]/usr/bin/git config --local --name-only --get-regexp ^includeIf\.gitdir:
2025-11-23T15:33:59.9500188Z [command]/usr/bin/git submodule foreach --recursive git config --local --show-origin --name-only --get-regexp remote.origin.url
2025-11-23T15:33:59.9843440Z Cleaning up orphan processes
