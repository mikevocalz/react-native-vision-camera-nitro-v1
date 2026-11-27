const config = {
  preset: 'react-native-harness',
  testMatch: ['<rootDir>/__tests__/**/*.harness.{js,jsx,ts,tsx}'],
  // react-native-vision-camera-skia and react-native-vision-camera-barcode-scanner
  // are not on Nitro V1 yet, so this app does not install them.
  testPathIgnorePatterns: [
    '<rootDir>/__tests__/visioncamera.skia-camera.harness.tsx',
    '<rootDir>/__tests__/visioncamera.barcode-scanner.harness.ts',
  ],
}

export default config
