# Lottie Animations Setup Guide

This app uses Lottie animations to make the UI more lively and engaging. Follow these steps to add your own animations:

## Step 1: Get Free Lottie Animations

1. Visit [LottieFiles.com](https://lottiefiles.com/)
2. Search for free animations:
   - **Back Arrow**: Search "arrow left" or "back arrow"
   - **Trash/Delete**: Search "delete" or "trash can"
   - **Pen/Pencil**: Search "pen" or "pencil"
   - **Eraser**: Search "eraser" or "delete tool"
   - **Arrow Down**: Search "arrow down" or "chevron down"
   - **Arrow Up**: Search "arrow up" or "chevron up"

## Step 2: Get the Animation URL

### Option A: Use LottieFiles CDN (Recommended)
1. Click on an animation you like
2. Click "Share" or "Embed"
3. Copy the JSON URL (looks like: `https://lottie.host/embed/...` or `https://assets5.lottiefiles.com/...`)
4. Replace the placeholder URLs in `drawing_page.dart`

### Option B: Download and Use Local Files
1. Download the JSON file
2. Create `assets/animations/` folder in your project
3. Add the JSON files there
4. Update `pubspec.yaml`:
   ```yaml
   flutter:
     assets:
       - assets/animations/
   ```
5. Replace `Lottie.network()` with `Lottie.asset('assets/animations/filename.json')`

## Step 3: Update the URLs

In `lib/pages/drawing_page.dart`, find these constants and replace with your URLs:

```dart
static const String _backArrowLottie = 'YOUR_URL_HERE';
static const String _trashLottie = 'YOUR_URL_HERE';
static const String _penLottie = 'YOUR_URL_HERE';
static const String _eraserLottie = 'YOUR_URL_HERE';
static const String _arrowDownLottie = 'YOUR_URL_HERE';
static const String _arrowUpLottie = 'YOUR_URL_HERE';
```

## Recommended Free Animations

Here are some popular free animations you can use:

- **Back Arrow**: https://lottiefiles.com/animations/arrow-left
- **Trash**: https://lottiefiles.com/animations/delete
- **Pen**: https://lottiefiles.com/animations/pencil
- **Eraser**: https://lottiefiles.com/animations/eraser
- **Arrows**: https://lottiefiles.com/animations/chevron-down

## Note

The app includes fallback icons, so if a Lottie animation fails to load, it will automatically show the Material icon instead.
