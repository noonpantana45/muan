#!/usr/bin/env bash
# สคริปต์นี้สร้างแอป Android ของ "ม้วน" จาก index.html แล้วออกมาเป็นไฟล์ dist/muan.apk
# ใช้บน GitHub Actions (ubuntu-latest) ได้ทันที หรือรันบนเครื่องที่มี JDK 17+ และ Android SDK ก็ได้
set -euo pipefail

ROOT="$(pwd)"
GRADLE_VERSION="8.11.1"
AGP_VERSION="8.7.3"
RUN_NO="${GITHUB_RUN_NUMBER:-1}"

# ---------- Java 17 ----------
if [ -n "${JAVA_HOME_17_X64:-}" ]; then export JAVA_HOME="$JAVA_HOME_17_X64"; export PATH="$JAVA_HOME/bin:$PATH"; fi
java -version

# ---------- Android SDK ----------
SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
if [ -z "$SDK" ]; then echo "ไม่พบ Android SDK (ตั้งค่า ANDROID_HOME ก่อน)"; exit 1; fi
yes | "$SDK/cmdline-tools/latest/bin/sdkmanager" --licenses >/dev/null 2>&1 || true

# ---------- Gradle ----------
if [ ! -x "$ROOT/.gradle-dist/gradle-$GRADLE_VERSION/bin/gradle" ]; then
  mkdir -p "$ROOT/.gradle-dist"
  curl -sSL -o "$ROOT/.gradle-dist/gradle.zip" "https://services.gradle.org/distributions/gradle-$GRADLE_VERSION-bin.zip"
  unzip -q -o "$ROOT/.gradle-dist/gradle.zip" -d "$ROOT/.gradle-dist"
fi
GRADLE="$ROOT/.gradle-dist/gradle-$GRADLE_VERSION/bin/gradle"

# ---------- project files ----------
P="$ROOT/android"
rm -rf "$P"
mkdir -p "$P/app/src/main/java/th/muan/camera" "$P/app/src/main/assets" \
         "$P/app/src/main/res/values" "$P/app/src/main/res/values-night" \
         "$P/app/src/main/res/drawable" "$P/app/src/main/res/mipmap-anydpi-v26"

if [ ! -f "$ROOT/index.html" ]; then echo "ไม่พบ index.html ในโฟลเดอร์เดียวกับสคริปต์"; exit 1; fi
cp "$ROOT/index.html" "$P/app/src/main/assets/index.html"
echo "sdk.dir=$SDK" > "$P/local.properties"

cat > "$P/settings.gradle" <<'EOF'
pluginManagement {
    repositories { google(); mavenCentral(); gradlePluginPortal() }
}
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories { google(); mavenCentral() }
}
rootProject.name = "Muan"
include ':app'
EOF

cat > "$P/build.gradle" <<EOF
plugins { id 'com.android.application' version '$AGP_VERSION' apply false }
EOF

cat > "$P/gradle.properties" <<'EOF'
org.gradle.jvmargs=-Xmx2g -Dfile.encoding=UTF-8
android.useAndroidX=false
android.nonTransitiveRClass=true
EOF

cat > "$P/app/build.gradle" <<EOF
plugins { id 'com.android.application' }

android {
    namespace 'th.muan.camera'
    compileSdk 35

    defaultConfig {
        applicationId 'th.muan.camera'
        minSdk 29
        targetSdk 35
        versionCode $RUN_NO
        versionName '0.1.$RUN_NO'
    }

    signingConfigs {
        muan {
            storeFile file('muan-test.p12')
            storePassword 'muantest'
            keyAlias 'muan'
            keyPassword 'muantest'
            storeType 'pkcs12'
        }
    }

    buildTypes {
        release {
            minifyEnabled false
            signingConfig signingConfigs.muan
        }
    }

    compileOptions {
        sourceCompatibility JavaVersion.VERSION_17
        targetCompatibility JavaVersion.VERSION_17
    }

    lint {
        checkReleaseBuilds false
        abortOnError false
    }
}
EOF

# กุญแจเซ็นแอปสำหรับรุ่นทดสอบเท่านั้น (ใช้ซ้ำทุกครั้ง เพื่อให้ลงทับเวอร์ชันเก่าได้)
# ห้ามใช้กุญแจนี้กับ Play Store ตอนขายจริง ให้สร้างกุญแจใหม่
echo "MIIKQAIBAzCCCeoGCSqGSIb3DQEHAaCCCdsEggnXMIIJ0zCCBaoGCSqGSIb3DQEHAaCCBZsEggWXMIIFkzCCBY8GCyqGSIb3DQEMCgECoIIFQDCCBTwwZgYJKoZIhvcNAQUNMFkwOAYJKoZIhvcNAQUMMCsEFI8RnzGDb4WAGve9HVrfXXhvMFbIAgInEAIBIDAMBggqhkiG9w0CCQUAMB0GCWCGSAFlAwQBKgQQwUKZd+aKm/LBFGaELbm66gSCBNCnlqPH+rTovx80xUAQO6eX6++dvzReE7dJnzfNkyuNXhFtbMaL4deo8GlZsowDZEpgxXwsIKXo9VkLVTyeScKN6SeZAxiQKllR7qJc6h5gTugubsafIntuHgP+64yUcUpbC27Bbn7hiVgLwCM9/oTRYuwNVErlROkCTgtnw2dJ64tMMF48x8gC7537iKwoSmHtdmoJHUrH17Md6nzWNbHYhorJagwGXO5eYu7TpOThLIHG6tNJnai2pcR4Few7gORAMDgaR1Wb+CKi6EmfN/90A5wmjCw9IeNd6vfwyKZwyr2we+Y5yUT6vPqCAEodMvKZp7QeLrW/Y08kUQCMbFjN3Qr4aJHbLbvtJ2dBOGupADGd8d4tn9IBBbzmlTT9+o8zyy8OAip1zss46uaTdJ6DzBqIE7xiflYuB0QxAAGYA5JEKyVspHEkv/bHK+uIDsDGEx2kmk93S1hD8SV662rxCPF/3hryr0zogVgYqXON/Ppjs7zwVlR47hThLGlcSD+Or4nv04uA6wS875b/vI0pw3gK5eCfkKZ99JyNS0FmgA4L4sSGUQH/0dQLpinHiuLzUbJVdNGPwfdPMVOrO7RC23Eq1L+8wtHFPa+F15zOLEIELn+VvEYxGua4MoZCDcs2R9dpnC7QCa6QrqoyDThOTFMdXILtpxqva3fqCp4crBf8E0W+schzLXPNQRDlow16sdrUhzJ18XtZwpTrnTmzMSnjweqq5EB/8WWIQDGp8TzE7e7AeMKXnoZ0OJVTYAm3/2jgLs69ckSL1u5F9soDCm/njTnA4cL2zVGBTUFJWWHef3MaIZtmcNna4bJs1+/yPTtvugDys7iAMgFT9HUzXym77IMf2Ue6vM9sbGgA868qRpSjfhwzs12CL849m9IfniPS5fWg4A26Eo0SibUaCqHeHjNQjZ/QGlSIyIHcG75EO8UZD4Y1MnoYdxBSdb7DNIAmxscgsP60JU9nzpneljSaw2qgkIocCtzOjCRTYDcfIvwiq4znXoJXaj4j2SkJJ8a9XmrMhKPIS4hP8xuBXvLNlbW4+ws2K4bJZnKFiuCtphOvJjpCQRCX1ctV2aDUsYbsI7A068TdnNYlZ9a3SprbGrHYDK8Ff6rVyzRrppco7T78vODANGsTy0O3jRUNrpRwg29asquDt3OcNfZDuc5adEYWjA3px2A/uwMjkEpgtBYO6ZBwb9RdPHluLZWTdtlwaygAFzjeKzk+sZzYlkOmOgtWNORq5bRND9z2V65+tQ3GQxBKoQiLIWju3/DoHnBb5ke4/j+ulz/hHFyCpLMnEaphAatxsUbBenYJ2fXK1dRpX1NJfNlsR16/48e51JsF5W6oHbEOWR/TYiEo2CHFWoy6HxXW5bLKFlmDSTuyWlA5tINySHGhakFNgYhz2MU2cU2lm3GXZmvFIPaqpKyVndTpztwr6pIrVXemxw2bftf6vbiSRCLvwGgm180bm6GMj8nNrdDs0xdNu/37C8J9KkbA7HDRBsOZJrVI8YM51jiKOhxcXx2VTehsSNfO8hxbDtO1uEFKjG1zZgGFk5t7NPXKIZxV2p8FpIJEsJc1GVEIjKnoq8ov61Ybzn4Pzlp6EGYZo24hOF2xcQibsssReXHQVy+PcVks029dHDE8MBcGCSqGSIb3DQEJFDEKHggAbQB1AGEAbjAhBgkqhkiG9w0BCRUxFAQSVGltZSAxNzkyOTkwNzE0MDEzMIIEIQYJKoZIhvcNAQcGoIIEEjCCBA4CAQAwggQHBgkqhkiG9w0BBwEwZgYJKoZIhvcNAQUNMFkwOAYJKoZIhvcNAQUMMCsEFP5Nv6CGT0xdBhfiGigp0nnL0dUtAgInEAIBIDAMBggqhkiG9w0CCQUAMB0GCWCGSAFlAwQBKgQQN0Ko3B2LvIRgeTTUlk3uN4CCA5DHAfAeS0sKHcHv/6Nn5zMxE932RkeSZOTE5fvm4M79Q2vBOfhemglCPnJQPvX/lrAflg3WaDlLgmKJvfEjD6QFBzaqPnCOaSB7TNoKvWgzvsSRhyWaJprbaVteEG2ceQf3wIawisSYeSNhcXmIJljycg5Q1fhyjRb/lM1xSJtbhz7tr4vmOkJCNX52wriFUF5f9tAQFd5H0kVKGFOQ+JSC7ru2YtbaoNYpr1By3aVwAp5j09qsqTHgGm/oTOEbxOE1ZFPqsOgY2mSDu8g+S2fmEhtyd5Nj3Tt6FiBobtSUVhghBUNRWweQoP74/1GKLP97cdNZ8hJsMkRiwgZvpemVpxNG8VIOb4FdGAN2UHd4hmEVZjEMhkuyGF62YIQrgcQvnG2ijJzkQMYCDRUGslAMqmFaBYP0/YO4n2YJmJLfxIl2eXEJtkvsosJkv5yo4nJ3r/rmpj+CCTzcI34RVsbf7NXPD+qZb8WJJVu1p8YjeJp5l5F2qWc+HE8/ectIkzBTxH9a/PflHviDCxqceQXQqq6n/4yYEdjU3N0YTkNPCxmOq30suy0UquByCbFPiTgAiixXsfWtmgbUCVzcGbaUgJnDh/3LcEpPPuXOcO1UTHrRvxpAI7bKB+r5ngKPfAlKx5CXF8eq+p8Nk+pD/CivgNOMeXBkpvionp0ejYqDXwReKxXbV+eQDWgPD4OEEaqw8Go5kFAbc3AvzUkTFqbdHPCJNlb1by3U167ROehpyN61jfNN9LbX0zr61hVLy/68fYeA5FNJ6KWuF0GmdIZ4PG+vTke5R/HcaKG148Dxf1wN4KRyFAiRT/EjC2ibJEW8ulpb71vV9nNiMf52hdMODBefq7s6Al18RRlFwA+IhZuRUdbvcw0zuqZWFb5Jg8DL+tPTo/skoM5TkVYAzhk0Gse03fy8wcH1BDTz0AzfVjdKjeiuozsiBRHdDmKWTZYrGzOMBnWRwGICtYm07l15NQaBZYnYdeoAln8iO86bO8u2+lWy2hfiMYkckaKiZo+1alR+v1CWQ7Ua7BD1lsSQXiyNUwyUSg3DUreliW62Uv5cLex661PDhCIKTRv0FMhbt1+lq5PgjuVsTKtIkAR0WwTJOgW2NUcqXCTp7FHOBVHd+CQjY14dpdtxMml5ndr7/d8F4dCxInERqNpzTmla4t2X+Ar/No5ie9lefn5J9vJup+zyPoKju48LU3ONO40wTTAxMA0GCWCGSAFlAwQCAQUABCAiM6weoROrT6l9RF40fHuU2q4LhVGo2Debm2RYNSScsQQU8DsNYifS5VXwsZqLVqmX8afQBbMCAicQ" | base64 -d > "$P/app/muan-test.p12"

cat > "$P/app/src/main/AndroidManifest.xml" <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <uses-feature android:name="android.hardware.camera.any" android:required="false" />
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.CAMERA" />
    <uses-permission android:name="android.permission.VIBRATE" />

    <application
        android:allowBackup="true"
        android:icon="@mipmap/ic_launcher"
        android:roundIcon="@mipmap/ic_launcher"
        android:label="ม้วน"
        android:theme="@style/AppTheme">
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:screenOrientation="portrait"
            android:configChanges="orientation|screenSize|screenLayout|smallestScreenSize|keyboardHidden"
            android:windowSoftInputMode="adjustResize">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
    </application>
</manifest>
EOF

cat > "$P/app/src/main/res/values/colors.xml" <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="paper">#E3E6E0</color>
    <color name="ic_bg">#21342D</color>
</resources>
EOF

cat > "$P/app/src/main/res/values-night/colors.xml" <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="paper">#120B0A</color>
</resources>
EOF

cat > "$P/app/src/main/res/values/styles.xml" <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <style name="AppTheme" parent="@android:style/Theme.Material.Light.NoActionBar">
        <item name="android:windowBackground">@color/paper</item>
        <item name="android:statusBarColor">@color/paper</item>
        <item name="android:navigationBarColor">@color/paper</item>
        <item name="android:windowLightStatusBar">true</item>
        <item name="android:windowLightNavigationBar">true</item>
    </style>
</resources>
EOF

cat > "$P/app/src/main/res/values-night/styles.xml" <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <style name="AppTheme" parent="@android:style/Theme.Material.NoActionBar">
        <item name="android:windowBackground">@color/paper</item>
        <item name="android:statusBarColor">@color/paper</item>
        <item name="android:navigationBarColor">@color/paper</item>
        <item name="android:windowLightStatusBar">false</item>
        <item name="android:windowLightNavigationBar">false</item>
    </style>
</resources>
EOF

# ไอคอน: ปุ่มชัตเตอร์โครเมียมบนหนังสีเขียวเข้ม (เป็นเวกเตอร์ ไม่ต้องใช้ไฟล์รูป)
cat > "$P/app/src/main/res/drawable/ic_fg.xml" <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp" android:height="108dp"
    android:viewportWidth="108" android:viewportHeight="108">
    <path android:fillColor="#D9DDDB" android:pathData="M28,54a26,26 0 1,0 52,0a26,26 0 1,0 -52,0z" />
    <path android:fillColor="#9EA3A0" android:pathData="M31,54a23,23 0 1,0 46,0a23,23 0 1,0 -46,0z" />
    <path android:fillColor="#1A211E" android:pathData="M34,54a20,20 0 1,0 40,0a20,20 0 1,0 -40,0z" />
    <path android:fillColor="#B0261C" android:pathData="M40,54a14,14 0 1,0 28,0a14,14 0 1,0 -28,0z" />
    <path android:fillColor="#E0695C" android:pathData="M45,49a4,4 0 1,0 8,0a4,4 0 1,0 -8,0z" />
    <path android:fillColor="#FF7A1A" android:pathData="M72,34a3,3 0 1,0 6,0a3,3 0 1,0 -6,0z" />
</vector>
EOF

cat > "$P/app/src/main/res/drawable/ic_mono.xml" <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp" android:height="108dp"
    android:viewportWidth="108" android:viewportHeight="108">
    <path android:fillColor="#FFFFFF" android:fillType="evenOdd"
        android:pathData="M28,54a26,26 0 1,0 52,0a26,26 0 1,0 -52,0z M34,54a20,20 0 1,0 40,0a20,20 0 1,0 -40,0z M40,54a14,14 0 1,0 28,0a14,14 0 1,0 -28,0z" />
</vector>
EOF

cat > "$P/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml" <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_bg" />
    <foreground android:drawable="@drawable/ic_fg" />
    <monochrome android:drawable="@drawable/ic_mono" />
</adaptive-icon>
EOF

cat > "$P/app/src/main/java/th/muan/camera/MainActivity.java" <<'EOF'
package th.muan.camera;

import android.Manifest;
import android.app.Activity;
import android.content.ContentResolver;
import android.content.ContentValues;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.os.Environment;
import android.provider.MediaStore;
import android.util.Base64;
import android.view.View;
import android.view.ViewGroup;
import android.view.WindowInsets;
import android.webkit.JavascriptInterface;
import android.webkit.PermissionRequest;
import android.webkit.ValueCallback;
import android.webkit.WebChromeClient;
import android.webkit.WebResourceRequest;
import android.webkit.WebResourceResponse;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.FrameLayout;

import java.io.ByteArrayInputStream;
import java.io.InputStream;
import java.io.OutputStream;

public class MainActivity extends Activity {

    // หน้าเว็บในแอปถูกเสิร์ฟจากโดเมนนี้ เพื่อให้เป็น https (กล้องและ IndexedDB ต้องใช้)
    private static final String HOST = "appassets.androidplatform.net";
    private static final String START_URL = "https://" + HOST + "/index.html";
    private static final int REQ_CAMERA = 7;
    private static final int REQ_FILE = 8;

    private WebView web;
    private PermissionRequest pendingPermission;
    private ValueCallback<Uri[]> fileCallback;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        FrameLayout root = new FrameLayout(this);
        root.setBackgroundColor(getColor(R.color.paper));
        web = new WebView(this);
        root.addView(web, new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));
        setContentView(root);

        // Android 15 วาดแอปเต็มจอใต้แถบสถานะ จึงต้องเว้นขอบเอง
        root.setOnApplyWindowInsetsListener((v, insets) -> {
            int top, bottom, left, right;
            if (Build.VERSION.SDK_INT >= 30) {
                android.graphics.Insets i = insets.getInsets(
                        WindowInsets.Type.systemBars() | WindowInsets.Type.displayCutout());
                top = i.top; bottom = i.bottom; left = i.left; right = i.right;
            } else {
                top = insets.getSystemWindowInsetTop();
                bottom = insets.getSystemWindowInsetBottom();
                left = insets.getSystemWindowInsetLeft();
                right = insets.getSystemWindowInsetRight();
            }
            v.setPadding(left, top, right, bottom);
            return insets;
        });

        WebSettings s = web.getSettings();
        s.setJavaScriptEnabled(true);
        s.setDomStorageEnabled(true);
        s.setMediaPlaybackRequiresUserGesture(false);
        s.setAllowFileAccess(false);
        s.setAllowContentAccess(false);
        s.setTextZoom(100);
        web.setOverScrollMode(View.OVER_SCROLL_NEVER);
        web.setBackgroundColor(getColor(R.color.paper));
        web.addJavascriptInterface(new Bridge(), "MuanAndroid");

        web.setWebViewClient(new WebViewClient() {
            @Override
            public WebResourceResponse shouldInterceptRequest(WebView view, WebResourceRequest req) {
                Uri u = req.getUrl();
                if (!HOST.equals(u.getHost())) return null;
                String path = u.getPath();
                if (path == null || path.isEmpty() || path.equals("/")) path = "/index.html";
                try {
                    InputStream in = getAssets().open(path.substring(1));
                    return new WebResourceResponse(mime(path), "utf-8", in);
                } catch (Exception e) {
                    return new WebResourceResponse("text/plain", "utf-8", 404, "Not Found", null,
                            new ByteArrayInputStream(new byte[0]));
                }
            }

            @Override
            public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest req) {
                Uri u = req.getUrl();
                if (HOST.equals(u.getHost())) return false;
                try { startActivity(new Intent(Intent.ACTION_VIEW, u)); } catch (Exception ignored) { }
                return true;
            }
        });

        web.setWebChromeClient(new WebChromeClient() {
            @Override
            public void onPermissionRequest(final PermissionRequest request) {
                runOnUiThread(() -> {
                    boolean wantsVideo = false;
                    for (String r : request.getResources()) {
                        if (PermissionRequest.RESOURCE_VIDEO_CAPTURE.equals(r)) wantsVideo = true;
                    }
                    if (!wantsVideo) { request.deny(); return; }
                    if (checkSelfPermission(Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED) {
                        request.grant(new String[]{ PermissionRequest.RESOURCE_VIDEO_CAPTURE });
                    } else {
                        pendingPermission = request;
                        requestPermissions(new String[]{ Manifest.permission.CAMERA }, REQ_CAMERA);
                    }
                });
            }

            @Override
            public boolean onShowFileChooser(WebView view, ValueCallback<Uri[]> callback, FileChooserParams params) {
                if (fileCallback != null) fileCallback.onReceiveValue(null);
                fileCallback = callback;
                try {
                    startActivityForResult(params.createIntent(), REQ_FILE);
                } catch (Exception e) {
                    fileCallback = null;
                    return false;
                }
                return true;
            }
        });

        web.loadUrl(START_URL);
    }

    @Override
    public void onRequestPermissionsResult(int code, String[] perms, int[] results) {
        super.onRequestPermissionsResult(code, perms, results);
        if (code == REQ_CAMERA && pendingPermission != null) {
            if (results.length > 0 && results[0] == PackageManager.PERMISSION_GRANTED) {
                pendingPermission.grant(new String[]{ PermissionRequest.RESOURCE_VIDEO_CAPTURE });
            } else {
                pendingPermission.deny();
            }
            pendingPermission = null;
        }
    }

    @Override
    protected void onActivityResult(int code, int result, Intent data) {
        super.onActivityResult(code, result, data);
        if (code == REQ_FILE && fileCallback != null) {
            fileCallback.onReceiveValue(WebChromeClient.FileChooserParams.parseResult(result, data));
            fileCallback = null;
        }
    }

    @Override
    @SuppressWarnings("deprecation")
    public void onBackPressed() {
        // ให้หน้าเว็บปิดหน้าดูรูปหรือย้อนหน้าเองก่อน ถ้าไม่มีอะไรให้ย้อนค่อยออกจากแอป
        web.evaluateJavascript("(window.__muanBack && window.__muanBack()) ? '1' : '0'", value -> {
            if (!"\"1\"".equals(value)) super.onBackPressed();
        });
    }

    @Override
    protected void onPause() { super.onPause(); if (web != null) web.onPause(); }

    @Override
    protected void onResume() { super.onResume(); if (web != null) web.onResume(); }

    @Override
    protected void onDestroy() { if (web != null) web.destroy(); super.onDestroy(); }

    private static String mime(String p) {
        p = p.toLowerCase();
        if (p.endsWith(".html")) return "text/html";
        if (p.endsWith(".js")) return "application/javascript";
        if (p.endsWith(".css")) return "text/css";
        if (p.endsWith(".png")) return "image/png";
        if (p.endsWith(".jpg") || p.endsWith(".jpeg")) return "image/jpeg";
        if (p.endsWith(".svg")) return "image/svg+xml";
        if (p.endsWith(".woff2")) return "font/woff2";
        return "application/octet-stream";
    }

    // หน้าเว็บเรียกใช้เพื่อบันทึกรูปลงอัลบั้ม หรือบันทึก .zip ลงโฟลเดอร์ Download
    private class Bridge {
        @JavascriptInterface
        public String saveFile(String name, String mime, String base64) {
            try {
                byte[] bytes = Base64.decode(base64, Base64.DEFAULT);
                ContentValues v = new ContentValues();
                v.put(MediaStore.MediaColumns.DISPLAY_NAME, name);
                v.put(MediaStore.MediaColumns.MIME_TYPE, mime);
                v.put(MediaStore.MediaColumns.IS_PENDING, 1);
                Uri collection;
                if (mime.startsWith("image/")) {
                    v.put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_PICTURES + "/Muan");
                    collection = MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY);
                } else {
                    v.put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS + "/Muan");
                    collection = MediaStore.Downloads.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY);
                }
                ContentResolver cr = getContentResolver();
                Uri item = cr.insert(collection, v);
                if (item == null) return "error";
                try (OutputStream out = cr.openOutputStream(item)) {
                    out.write(bytes);
                }
                ContentValues done = new ContentValues();
                done.put(MediaStore.MediaColumns.IS_PENDING, 0);
                cr.update(item, done, null, null);
                return "saved";
            } catch (Exception e) {
                return "error";
            }
        }
    }
}
EOF

# ---------- build ----------
"$GRADLE" -p "$P" assembleRelease --no-daemon --stacktrace

mkdir -p "$ROOT/dist"
cp "$P/app/build/outputs/apk/release/app-release.apk" "$ROOT/dist/muan.apk"
echo "เสร็จแล้ว: dist/muan.apk"
ls -la "$ROOT/dist"
