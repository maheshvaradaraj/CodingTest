# ios-paycasso-document-cropper

```sh
cd DocumentCapture
mkdir build

xcodebuild clean build \
  -project DocumentCapture.xcodeproj \
  -scheme DocumentCapture \
  -configuration Debug \
  -sdk iphoneos \
  -derivedDataPath derived_data \
  BUILD_LIBRARY_FOR_DISTRIBUTION=YES

mkdir build/devices
cp -r derived_data/Build/Products/Debug-iphoneos/DocumentCapture.framework build/devices

xcodebuild clean build \
  -project DocumentCapture.xcodeproj \
  -scheme DocumentCapture \
  -configuration Debug \
  -sdk iphonesimulator \
  -derivedDataPath derived_data \
  BUILD_LIBRARY_FOR_DISTRIBUTION=YES

mkdir build/simulator
cp -r derived_data/Build/Products/Debug-iphonesimulator/ build/simulator/

mkdir build/universal
cp -r build/devices/DocumentCapture.framework build/universal/

lipo -create \
  build/simulator/DocumentCapture.framework/DocumentCapture \
  build/devices/DocumentCapture.framework/DocumentCapture \
  -output build/universal/DocumentCapture.framework/DocumentCapture
```
