# How to get your APK in 5 minutes (free, no installs needed)

## What happens:
You push this code to GitHub → GitHub builds the APK for free → you download it.

---

## Step 1 — Create a GitHub account (if you don't have one)
Go to https://github.com and sign up. It's free.

---

## Step 2 — Create a new repository
1. Go to https://github.com/new
2. Name it: `kfit` (or anything)
3. Make it **Private** (your personal app)
4. Click **"Create repository"**
5. Copy the repo URL — it looks like:
   `https://github.com/YOUR_USERNAME/kfit.git`

---

## Step 3 — Install Git (if you don't have it)
Download from: https://git-scm.com/download/win
(As a .NET dev you probably already have this)

---

## Step 4 — Push the code

Open terminal/Command Prompt, navigate to the `karthik_fitness_app` folder, then run:

```bash
git init
git add .
git commit -m "Initial commit - Karthik Fitness App"
git branch -M main
git remote add origin https://github.com/YOUR_USERNAME/kfit.git
git push -u origin main
```

Replace `YOUR_USERNAME` with your actual GitHub username.

---

## Step 5 — Watch it build (takes ~5 minutes)

1. Go to your repo on GitHub
2. Click the **"Actions"** tab at the top
3. You'll see "Build Android APK" running with a yellow dot ⏳
4. Wait for it to turn green ✅ (about 4–6 minutes)

---

## Step 6 — Download your APK

1. Click on the completed build (green checkmark)
2. Scroll down to **"Artifacts"**
3. Click **"kfit-app"** to download the zip
4. Unzip it — inside is `app-release.apk`

---

## Step 7 — Install on your Android phone

1. Transfer the APK to your phone (WhatsApp yourself, Google Drive, USB cable, etc.)
2. Open the APK file on your phone
3. If it says "Install blocked" → go to **Settings → Security → Install unknown apps** → allow your browser/file manager
4. Tap Install ✅

---

## Every time you update the app:

Just run:
```bash
git add .
git commit -m "update: describe what you changed"
git push
```

GitHub will automatically rebuild the APK. Download the new one from Actions.

---

## Troubleshooting

**Build failed?** → Click the failed build → click the "build" job → read the error logs.
Most common fix: pubspec.yaml version mismatch. Let Karthik know (me) and I'll fix it!

**APK won't install?** → Make sure "Install from unknown sources" is enabled in phone settings.
