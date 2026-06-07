/// Maps watch face names (as sent by the watch via BLE) to local asset paths.
/// Names must match exactly what watch_faces.cpp reports.
const Map<String, String> kFaceAssets = {
  // Digital faces
  'Neon Digital':     'assets/watch_faces/neon.png',
  'Chronos Digital':  'assets/watch_faces/chronos_digital_face.png',
  'Brix Digital':     'assets/watch_faces/brix.png',
  'Orbit Digital':    'assets/watch_faces/orbit_digital.png',
  'Circuit Digital':  'assets/watch_faces/circuit.png',
  'Stone Digital':    'assets/watch_faces/stone.png',
  'Feather Digital':  'assets/watch_faces/feather_digital.png',
  'Puppy':            'assets/watch_faces/paws.png',

  // Analogue faces
  'Feather':          'assets/watch_faces/feather.png',
  'Neon Analogue':    'assets/watch_faces/neon.png',
  'Orbit':            'assets/watch_faces/orbit.png',
  'Circuit':          'assets/watch_faces/circuit.png',
  'Brix':             'assets/watch_faces/brix.png',
  'Stone':            'assets/watch_faces/stone.png',
  'Chronos':          'assets/watch_faces/chronos.png',
};

String? faceAsset(String faceName) => kFaceAssets[faceName];
