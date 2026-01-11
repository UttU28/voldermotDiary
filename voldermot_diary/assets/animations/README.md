# Loading Animation

## How to Add Your Lottie Animation

1. **Download your Lottie animation** from [LottieFiles.com](https://lottiefiles.com/)
   - Make sure to download the **JSON format** (not .lottie)
   - The file should have a `.json` extension

2. **Rename the file** to `loading.json`

3. **Place it in this folder**: `voldermot_diary/assets/animations/loading.json`

4. **Run** `flutter pub get` to refresh assets

5. The loading page will automatically use your animation!

## File Format

- ✅ **Use `.json` format** (recommended)
- ❌ Don't use `.lottie` format (not supported by Flutter's lottie package)

## Current Setup

The loading page currently shows a fallback circular progress indicator if the Lottie file is not found. Once you add `loading.json`, it will automatically use your animation.
