#!/bin/bash

# 1. Install Flutter
if [ ! -d "flutter" ]; then
  echo "Downloading Flutter SDK..."
  git clone https://github.com/flutter/flutter.git -b stable
fi

export PATH="$PATH:`pwd`/flutter/bin"

# 2. Run Flutter Doctor to ensure everything is fine
flutter doctor

# 3. Build for web with the dynamic URL
echo "Building Flutter Web..."
flutter build web --release --dart-define=BASE_URL=https://proctorai-ctfi.onrender.com/api

echo "Build complete!"
