<div style="text-align: center">
<picture>
  <!-- <source media="(prefers-color-scheme: dark)" srcset="https://static.openfoodfacts.org/images/logos/off-logo-horizontal-dark.png?refresh_github_cache=1"> -->
  <!-- <source media="(prefers-color-scheme: light)" srcset="https://static.openfoodfacts.org/images/logos/off-logo-horizontal-light.png?refresh_github_cache=1"> -->
  <img height="150" src="./assets/wisebite-0-cropped-circle.png">
</picture>
</div>
<br>

# Wisebite: mobile app for Android and iPhone

<!-- [![SmoothApp Post-Submit Tests](https://github.com/openfoodfacts/smooth-app/actions/workflows/postsubmit.yml/badge.svg)](https://github.com/openfoodfacts/smooth-app/actions/workflows/postsubmit.yml) -->
<!-- [![Create internal releases](https://github.com/openfoodfacts/smooth-app/actions/workflows/internal-release.yml/badge.svg)](https://github.com/openfoodfacts/smooth-app/actions/workflows/internal-release.yml) -->

<!-- ## Code documentation -->

<!-- [Code documentation on GitHub pages](https://openfoodfacts.github.io/smooth-app/). -->

<!-- <br> -->

<!-- <details><summary><h2>Features of the app</h2></summary> -->

<!-- ## Features -->

<!-- - a scan that truly matches who you are (Green: the product matches your criteria, Red: there is a problem, Gray: Help us answer you by photographing the products) -->
<!-- - a product page that's knowledgeable, building on the vast amount of food facts we collect collaboratively, and other sources of knowledge, to help you make better food decisions -->

<!-- ## You can -->

<!-- - scan and compare in 15 seconds the 3 brands of tomato sauces left on the shelf, on your terms. -->
<!-- - get a tailored comparison of any food category -->
<!-- - set your preferences without ruining your privacy -->

<!-- ## Criteria you can pick -->

<!-- - Environment: Eco-Score -->
<!-- - Health: Additives & Ultra processed foods, Salt, Allergens, Nutri-Score -->

<!-- </details> -->

<!-- <br> -->
<!--   -->
<!-- ## About this Repository -->

<!-- ![GitHub language count](https://img.shields.io/github/languages/count/openfoodfacts/smooth-app) -->
<!-- ![GitHub top language](https://img.shields.io/github/languages/top/openfoodfacts/smooth-app) -->
<!-- ![GitHub last commit](https://img.shields.io/github/last-commit/openfoodfacts/smooth-app) -->
<!-- ![Github Repo Size](https://img.shields.io/github/repo-size/openfoodfacts/smooth-app) -->

<!-- <br> -->

## How to run the project

- Make sure you have installed flutter and all the requirements
  - [Official flutter installation guide](https://docs.flutter.dev/get-started/install)
- Currently, the app uses the latest stable version of Flutter (3.13).


We have predefined run configurations for Android Studio and Visual Studio Code

In order to run the application, make sure you are in the `packages/smooth_app` directory and run these commands:

- `flutter pub get .`

- On Android 🤖: `flutter run -t lib/entrypoints/android/main_google_play.dart`

- On iOS/macOS 🍎: `flutter run -t lib/entrypoints/ios/main_ios.dart`

- Troubleshooting🚀: If you get an error like `App depends on scanner shared from path which depends on camera_platform_interface from git, version solving failed.`  then run
  - `flutter pub cache clean` or manually delete  the  
  - `C:\Users\~\AppData\Local\Pub\Cache`  file.
 Then redo the above procedure to run the app.

<!-- - [Contributing Guidelines](https://github.com/openfoodfacts/smooth-app/blob/develop/CONTRIBUTING.md) -->

<!-- <br> -->

<!-- <details><summary><h3>Thanks</h3></summary> -->
<!-- The app was initially created by Primael. The new Open Food Facts app (smooth_app) was then made possible thanks to an initial grant by the Mozilla Foundation in February 2020, after Pierre pitched them the idea at FOSDEM. A HUGE THANKS 🧡 -->
<!-- In addition to the core role of the community, we also had the support from several Google.org fellows and a ShareIt fellow that helped us eventually release the app in June 2022. -->
<!-- </details> -->
<!-- <br> -->

<!-- ## Contributors -->

<!-- <a href="https://github.com/openfoodfacts/smooth-app/graphs/contributors"> -->
<!--   <img alt="List of contributors to this repository" src="https://contrib.rocks/image?repo=openfoodfacts/smooth-app" /> -->
<!-- </a> -->
