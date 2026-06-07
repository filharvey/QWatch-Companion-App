enum ClockMode { digital, analogue }

class WatchSettings {
  final ClockMode clockMode;
  final int digitalFaceIndex;
  final int analogueFaceIndex;
  final bool stepsActive;
  final String wifiSsid;
  final List<String> digitalFaces;
  final List<String> analogueFaces;

  const WatchSettings({
    required this.clockMode,
    required this.digitalFaceIndex,
    required this.analogueFaceIndex,
    required this.stepsActive,
    this.wifiSsid = '',
    this.digitalFaces = const [],
    this.analogueFaces = const [],
  });

  factory WatchSettings.defaults() => const WatchSettings(
        clockMode: ClockMode.digital,
        digitalFaceIndex: 0,
        analogueFaceIndex: 0,
        stepsActive: true,
      );

  factory WatchSettings.fromJson(Map<String, dynamic> json) => WatchSettings(
        clockMode: json['clock_mode'] == 'analogue'
            ? ClockMode.analogue
            : ClockMode.digital,
        digitalFaceIndex: (json['digital_face'] as int?) ?? 0,
        analogueFaceIndex: (json['analogue_face'] as int?) ?? 0,
        stepsActive: (json['steps_active'] as bool?) ?? true,
        wifiSsid: (json['wifi_ssid'] as String?) ?? '',
        digitalFaces: (json['digital_faces'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        analogueFaces: (json['analogue_faces'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
      );

  Map<String, dynamic> toJson() => {
        'clock_mode': clockMode == ClockMode.analogue ? 'analogue' : 'digital',
        'digital_face': digitalFaceIndex,
        'analogue_face': analogueFaceIndex,
        'steps_active': stepsActive,
      };

  WatchSettings copyWith({
    ClockMode? clockMode,
    int? digitalFaceIndex,
    int? analogueFaceIndex,
    bool? stepsActive,
  }) =>
      WatchSettings(
        clockMode: clockMode ?? this.clockMode,
        digitalFaceIndex: digitalFaceIndex ?? this.digitalFaceIndex,
        analogueFaceIndex: analogueFaceIndex ?? this.analogueFaceIndex,
        stepsActive: stepsActive ?? this.stepsActive,
        wifiSsid: wifiSsid,
        digitalFaces: digitalFaces,
        analogueFaces: analogueFaces,
      );
}
